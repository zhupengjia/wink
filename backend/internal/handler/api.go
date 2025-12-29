package handler

import (
	"context"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/wink/backend/internal/middleware"
	"github.com/wink/backend/internal/persona"
)

// PersonaRepository interface for persona operations
type PersonaRepository interface {
	GetPersona(ctx context.Context, personaID string) (*persona.Persona, error)
	GetPersonaBySlug(ctx context.Context, slug string) (*persona.Persona, error)
	ListActivePersonas(ctx context.Context) ([]*persona.Persona, error)
}

// PersonaResponse is the API response for a persona
type PersonaResponse struct {
	ID        string `json:"id"`
	Slug      string `json:"slug"`
	Name      string `json:"name"`
	NameZh    string `json:"name_zh,omitempty"`
	AvatarURL string `json:"avatar_url"`
	Bio       string `json:"bio,omitempty"`
	Archetype string `json:"archetype"`
	IsActive  bool   `json:"is_active"`
}

// ListPersonas returns all active personas
func ListPersonas(repo PersonaRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()

		personas, err := repo.ListActivePersonas(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list personas"})
			return
		}

		response := make([]PersonaResponse, len(personas))
		for i, p := range personas {
			response[i] = PersonaResponse{
				ID:        p.ID,
				Slug:      p.Slug,
				Name:      p.Name,
				NameZh:    p.NameZh,
				AvatarURL: p.AvatarURL,
				Archetype: p.Archetype,
				IsActive:  p.IsActive,
			}
		}

		c.JSON(http.StatusOK, response)
	}
}

// GetPersona returns a specific persona
func GetPersona(repo PersonaRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		personaID := c.Param("id")

		p, err := repo.GetPersona(ctx, personaID)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Persona not found"})
			return
		}

		c.JSON(http.StatusOK, PersonaResponse{
			ID:        p.ID,
			Slug:      p.Slug,
			Name:      p.Name,
			NameZh:    p.NameZh,
			AvatarURL: p.AvatarURL,
			Archetype: p.Archetype,
			IsActive:  p.IsActive,
		})
	}
}

// IntimacyResponse is the API response for intimacy level
type IntimacyResponse struct {
	PersonaID     string `json:"persona_id"`
	Score         int    `json:"score"`
	Tier          string `json:"tier"`
	TotalMessages int    `json:"total_messages"`
	StreakDays    int    `json:"streak_days"`
}

// GetIntimacy returns the intimacy level for a user-persona pair
func GetIntimacy(service *persona.IntimacyService) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		userID := middleware.GetUserID(c)
		personaID := c.Param("personaId")

		level, err := service.GetOrCreateLevel(ctx, userID, personaID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get intimacy level"})
			return
		}

		c.JSON(http.StatusOK, IntimacyResponse{
			PersonaID:     level.PersonaID,
			Score:         level.Score,
			Tier:          string(level.Tier),
			TotalMessages: level.TotalMessages,
			StreakDays:    level.StreakDays,
		})
	}
}

// CreateConversationRequest is the request for creating a conversation
type CreateConversationRequest struct {
	PersonaID string `json:"persona_id,omitempty"`
	UserID    string `json:"user_id,omitempty"`
}

// ConversationResponse is the API response for a conversation
type ConversationResponse struct {
	ID               string  `json:"id"`
	PersonaID        *string `json:"persona_id,omitempty"`
	OtherUserID      *string `json:"other_user_id,omitempty"`
	ConversationType string  `json:"conversation_type"`
	LastMessageAt    *string `json:"last_message_at,omitempty"`
}

// ConversationRepository interface for conversation operations
type ConversationRepository interface {
	CreateOrGetConversation(ctx context.Context, userID string, personaID, otherUserID *string) (*Conversation, error)
	GetMessages(ctx context.Context, conversationID string, limit int, before *string) ([]*Message, error)
}

// CreateConversation creates or gets an existing conversation
func CreateConversation(repo ConversationRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		userID := middleware.GetUserID(c)

		var req CreateConversationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		if req.PersonaID == "" && req.UserID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Either persona_id or user_id required"})
			return
		}

		conv, err := repo.CreateOrGetConversation(ctx, userID, nilIfEmpty(req.PersonaID), nilIfEmpty(req.UserID))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create conversation"})
			return
		}

		var lastMessageAt *string
		if !conv.LastMessageAt.IsZero() {
			t := conv.LastMessageAt.Format("2006-01-02T15:04:05Z07:00")
			lastMessageAt = &t
		}

		c.JSON(http.StatusOK, ConversationResponse{
			ID:               conv.ID,
			PersonaID:        conv.PersonaID,
			OtherUserID:      conv.OtherUserID,
			ConversationType: conv.ConversationType,
			LastMessageAt:    lastMessageAt,
		})
	}
}

// MessageResponse is the API response for a message
type MessageResponse struct {
	ID             string `json:"id"`
	ConversationID string `json:"conversation_id"`
	SenderType     string `json:"sender_type"`
	Content        string `json:"content"`
	CreatedAt      string `json:"created_at"`
	MediaURL       string `json:"media_url,omitempty"`
	MediaType      string `json:"media_type,omitempty"`
}

// GetMessages returns messages for a conversation
func GetMessages(repo ConversationRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		conversationID := c.Param("id")

		limit := 50
		if l := c.Query("limit"); l != "" {
			if parsed, err := parseInt(l); err == nil && parsed > 0 && parsed <= 100 {
				limit = parsed
			}
		}

		var before *string
		if b := c.Query("before"); b != "" {
			before = &b
		}

		messages, err := repo.GetMessages(ctx, conversationID, limit, before)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get messages"})
			return
		}

		response := make([]MessageResponse, len(messages))
		for i, msg := range messages {
			response[i] = MessageResponse{
				ID:             msg.ID,
				ConversationID: msg.ConversationID,
				SenderType:     msg.SenderType,
				Content:        msg.Content,
				CreatedAt:      msg.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
				MediaURL:       msg.MediaURL,
				MediaType:      msg.MediaType,
			}
		}

		c.JSON(http.StatusOK, response)
	}
}

func parseInt(s string) (int, error) {
	var n int
	_, err := fmt.Sscanf(s, "%d", &n)
	return n, err
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
