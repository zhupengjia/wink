package handler

import (
	"context"
	"net/http"
	"strings"
	"time"
	"unicode"

	"github.com/gin-gonic/gin"
	"github.com/nlpodyssey/openai-agents-go/agents"
	"github.com/wink/backend/internal/persona"
	"github.com/wink/backend/internal/session"
)

// ChatHandler handles chat-related HTTP requests
type ChatHandler struct {
	personaService *persona.PersonaService
	sessionManager *session.RedisSession
	repo           ChatRepository
}

// ChatRepository interface for data persistence
type ChatRepository interface {
	GetConversation(ctx context.Context, conversationID string) (*Conversation, error)
	GetUser(ctx context.Context, userID string) (*User, error)
	SaveMessage(ctx context.Context, msg *Message) error
	UpdateConversation(ctx context.Context, conv *Conversation) error
}

// Conversation represents a chat conversation
type Conversation struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	OtherUserID      *string   `json:"other_user_id,omitempty"`
	PersonaID        *string   `json:"persona_id,omitempty"`
	ConversationType string    `json:"conversation_type"`
	LastMessageAt    time.Time `json:"last_message_at"`
	LastPreview      string    `json:"last_message_preview"`
	UnreadCount      int       `json:"unread_count"`
}

// User represents a user
type User struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	Locale      string `json:"locale"`
}

// Message represents a chat message
type Message struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	SenderType     string    `json:"sender_type"`
	SenderUserID   *string   `json:"sender_user_id,omitempty"`
	SenderPersonaID *string  `json:"sender_persona_id,omitempty"`
	Role           string    `json:"role"`
	Content        string    `json:"content"`
	CreatedAt      time.Time `json:"created_at"`
}

// SendMessageRequest is the request body for sending a message
type SendMessageRequest struct {
	ConversationID string `json:"conversation_id" binding:"required"`
	Content        string `json:"content" binding:"required"`
	Locale         string `json:"locale"`
}

// SendMessageResponse is the response for sending a message
type SendMessageResponse struct {
	MessageID    string `json:"message_id"`
	Content      string `json:"content"`
	IntimacyGain int    `json:"intimacy_gain,omitempty"`
	NewTier      string `json:"new_tier,omitempty"`
	Timestamp    string `json:"timestamp"`
}

// NewChatHandler creates a new chat handler
func NewChatHandler(
	personaService *persona.PersonaService,
	sessionManager *session.RedisSession,
	repo ChatRepository,
) *ChatHandler {
	return &ChatHandler{
		personaService: personaService,
		sessionManager: sessionManager,
		repo:           repo,
	}
}

// SendMessage handles sending a message (POST /api/chat/send)
func (h *ChatHandler) SendMessage(c *gin.Context) {
	ctx := c.Request.Context()
	userID := c.GetString("user_id") // From auth middleware

	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 1. Get conversation and validate ownership
	conv, err := h.repo.GetConversation(ctx, req.ConversationID)
	if err != nil || conv.UserID != userID {
		c.JSON(http.StatusNotFound, gin.H{"error": "conversation not found"})
		return
	}

	// 2. Route based on conversation type
	if conv.ConversationType == "user_to_ai" && conv.PersonaID != nil {
		h.handleAIMessage(c, ctx, userID, conv, &req)
	} else {
		h.handleUserMessage(c, ctx, userID, conv, &req)
	}
}

// handleAIMessage processes a message to an AI persona
func (h *ChatHandler) handleAIMessage(
	c *gin.Context,
	ctx context.Context,
	userID string,
	conv *Conversation,
	req *SendMessageRequest,
) {
	// 1. Get persona and intimacy level
	personaData, intimacy, err := h.personaService.GetPersonaWithIntimacy(ctx, *conv.PersonaID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get persona"})
		return
	}

	// 2. Get user for locale
	user, err := h.repo.GetUser(ctx, userID)
	locale := req.Locale
	if locale == "" && user != nil {
		locale = user.Locale
	}
	if locale == "" {
		locale = "en"
	}

	// 3. Store user message in Redis session
	err = h.sessionManager.AddMessage(ctx, req.ConversationID, session.Message{
		Role:    "user",
		Content: req.Content,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to store message"})
		return
	}

	// 4. Get conversation history for context
	history, _ := h.sessionManager.GetMessages(ctx, req.ConversationID, 20)

	// 5. Create agent with dynamic instructions based on intimacy
	userName := ""
	if user != nil {
		userName = user.DisplayName
	}
	agent := h.personaService.CreatePersonaAgent(ctx, personaData, intimacy, locale, userName)

	// 6. Build input (the agent framework handles history internally)
	input := req.Content

	// 7. Run agent
	result, err := agents.Run(ctx, agent, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AI response failed"})
		return
	}

	aiResponse := ""
	if output, ok := result.FinalOutput.(string); ok {
		aiResponse = output
	}

	// 8. Store AI response in Redis
	h.sessionManager.AddMessage(ctx, req.ConversationID, session.Message{
		Role:    "assistant",
		Content: aiResponse,
	})

	// 9. Calculate and update intimacy
	oldTier := intimacy.Tier
	delta := persona.IntimacyDelta{
		MessageLength:   len(req.Content),
		IsQuestion:      containsQuestion(req.Content),
		IsEmotional:     analyzeEmotion(req.Content),
		IsFirstToday:    persona.IsFirstInteractionToday(intimacy.LastInteractionAt),
		ContinuesStreak: persona.ContinuesStreak(intimacy.LastInteractionAt),
	}

	increase, tierChanged, err := h.personaService.UpdateIntimacy(ctx, intimacy, delta)
	if err != nil {
		// Log error but don't fail the request
	}

	// 10. Build response
	resp := SendMessageResponse{
		MessageID:    generateMessageID(),
		Content:      aiResponse,
		IntimacyGain: increase,
		Timestamp:    time.Now().Format(time.RFC3339),
	}

	if tierChanged {
		resp.NewTier = string(intimacy.Tier)
	}

	// 11. Update conversation metadata (async)
	go func() {
		conv.LastMessageAt = time.Now()
		conv.LastPreview = truncateString(aiResponse, 50)
		h.repo.UpdateConversation(context.Background(), conv)
	}()

	c.JSON(http.StatusOK, resp)
}

// handleUserMessage processes a message to another user
func (h *ChatHandler) handleUserMessage(
	c *gin.Context,
	ctx context.Context,
	userID string,
	conv *Conversation,
	req *SendMessageRequest,
) {
	// For user-to-user chat, messages go through Supabase Realtime
	// This handler just persists and returns success

	msg := &Message{
		ID:             generateMessageID(),
		ConversationID: req.ConversationID,
		SenderType:     "user",
		SenderUserID:   &userID,
		Role:           "user",
		Content:        req.Content,
		CreatedAt:      time.Now(),
	}

	if err := h.repo.SaveMessage(ctx, msg); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save message"})
		return
	}

	// Update conversation metadata
	go func() {
		conv.LastMessageAt = time.Now()
		conv.LastPreview = truncateString(req.Content, 50)
		h.repo.UpdateConversation(context.Background(), conv)
	}()

	c.JSON(http.StatusOK, SendMessageResponse{
		MessageID: msg.ID,
		Content:   req.Content,
		Timestamp: msg.CreatedAt.Format(time.RFC3339),
	})
}

// Helper functions

func containsQuestion(text string) bool {
	return strings.Contains(text, "?") ||
		strings.Contains(text, "？") ||
		strings.HasPrefix(strings.ToLower(strings.TrimSpace(text)), "what") ||
		strings.HasPrefix(strings.ToLower(strings.TrimSpace(text)), "how") ||
		strings.HasPrefix(strings.ToLower(strings.TrimSpace(text)), "why") ||
		strings.HasPrefix(strings.ToLower(strings.TrimSpace(text)), "when") ||
		strings.HasPrefix(strings.ToLower(strings.TrimSpace(text)), "where") ||
		strings.HasPrefix(strings.ToLower(strings.TrimSpace(text)), "who")
}

func analyzeEmotion(text string) bool {
	emotionalWords := []string{
		"love", "hate", "happy", "sad", "angry", "scared", "excited",
		"worried", "grateful", "sorry", "miss", "feel", "heart",
		"爱", "恨", "开心", "难过", "生气", "害怕", "兴奋",
		"担心", "感激", "抱歉", "想念", "感觉", "心",
	}

	textLower := strings.ToLower(text)
	for _, word := range emotionalWords {
		if strings.Contains(textLower, word) {
			return true
		}
	}

	// Check for emotional punctuation
	exclamationCount := strings.Count(text, "!") + strings.Count(text, "！")
	return exclamationCount >= 2
}

func generateMessageID() string {
	return "msg_" + randomString(16)
}

func randomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[time.Now().UnixNano()%int64(len(letters))]
		time.Sleep(1) // Simple way to get different values
	}
	return string(b)
}

func truncateString(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen]) + "..."
}

// DetectLanguage determines if text is primarily Chinese or English
func DetectLanguage(text string) string {
	chineseCount := 0
	totalCount := 0

	for _, r := range text {
		if unicode.Is(unicode.Han, r) {
			chineseCount++
		}
		if unicode.IsLetter(r) {
			totalCount++
		}
	}

	if totalCount == 0 {
		return "en"
	}

	if float64(chineseCount)/float64(totalCount) > 0.3 {
		return "zh"
	}
	return "en"
}
