package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/wink/backend/internal/handler"
	"github.com/wink/backend/internal/persona"
	"github.com/wink/backend/pkg/supabase"
)

// SupabaseRepository implements all repository interfaces using Supabase
type SupabaseRepository struct {
	client *supabase.Client
}

// NewSupabaseRepository creates a new Supabase repository
func NewSupabaseRepository(client *supabase.Client) *SupabaseRepository {
	return &SupabaseRepository{client: client}
}

// ============================================
// Persona Repository Implementation
// ============================================

func (r *SupabaseRepository) GetPersona(ctx context.Context, personaID string) (*persona.Persona, error) {
	data, err := r.client.From("virtual_personas").
		Select("*").
		Eq("id", personaID).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get persona: %w", err)
	}

	var dbPersona dbVirtualPersona
	if err := json.Unmarshal(data, &dbPersona); err != nil {
		return nil, fmt.Errorf("failed to unmarshal persona: %w", err)
	}

	return dbPersona.toPersona(), nil
}

func (r *SupabaseRepository) GetPersonaBySlug(ctx context.Context, slug string) (*persona.Persona, error) {
	data, err := r.client.From("virtual_personas").
		Select("*").
		Eq("slug", slug).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get persona by slug: %w", err)
	}

	var dbPersona dbVirtualPersona
	if err := json.Unmarshal(data, &dbPersona); err != nil {
		return nil, fmt.Errorf("failed to unmarshal persona: %w", err)
	}

	return dbPersona.toPersona(), nil
}

func (r *SupabaseRepository) ListActivePersonas(ctx context.Context) ([]*persona.Persona, error) {
	data, err := r.client.From("virtual_personas").
		Select("*").
		Eq("is_active", true).
		Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to list personas: %w", err)
	}

	var dbPersonas []dbVirtualPersona
	if err := json.Unmarshal(data, &dbPersonas); err != nil {
		return nil, fmt.Errorf("failed to unmarshal personas: %w", err)
	}

	personas := make([]*persona.Persona, len(dbPersonas))
	for i, dbp := range dbPersonas {
		personas[i] = dbp.toPersona()
	}

	return personas, nil
}

// ============================================
// Intimacy Repository Implementation
// ============================================

func (r *SupabaseRepository) GetIntimacyLevel(ctx context.Context, userID, personaID string) (*persona.IntimacyLevel, error) {
	data, err := r.client.From("intimacy_levels").
		Select("*").
		Eq("user_id", userID).
		Eq("persona_id", personaID).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("intimacy level not found: %w", err)
	}

	var dbIntimacy dbIntimacyLevel
	if err := json.Unmarshal(data, &dbIntimacy); err != nil {
		return nil, fmt.Errorf("failed to unmarshal intimacy: %w", err)
	}

	return dbIntimacy.toIntimacyLevel(), nil
}

func (r *SupabaseRepository) SaveIntimacyLevel(ctx context.Context, level *persona.IntimacyLevel) error {
	dbLevel := toDBIntimacyLevel(level)

	_, err := r.client.From("intimacy_levels").
		Update(dbLevel).
		Eq("id", level.ID).
		Execute()
	if err != nil {
		return fmt.Errorf("failed to save intimacy level: %w", err)
	}

	return nil
}

func (r *SupabaseRepository) CreateIntimacyLevel(ctx context.Context, userID, personaID string) (*persona.IntimacyLevel, error) {
	level := &persona.IntimacyLevel{
		UserID:            userID,
		PersonaID:         personaID,
		Score:             0,
		Tier:              persona.TierStranger,
		TotalMessages:     0,
		StreakDays:        0,
		LastInteractionAt: time.Time{},
	}

	dbLevel := toDBIntimacyLevel(level)

	data, err := r.client.From("intimacy_levels").
		Insert(dbLevel).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to create intimacy level: %w", err)
	}

	var created dbIntimacyLevel
	if err := json.Unmarshal(data, &created); err != nil {
		return nil, fmt.Errorf("failed to unmarshal created intimacy: %w", err)
	}

	return created.toIntimacyLevel(), nil
}

// ============================================
// Chat Repository Implementation
// ============================================

func (r *SupabaseRepository) GetConversation(ctx context.Context, conversationID string) (*handler.Conversation, error) {
	data, err := r.client.From("conversations").
		Select("*").
		Eq("id", conversationID).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("conversation not found: %w", err)
	}

	var dbConv dbConversation
	if err := json.Unmarshal(data, &dbConv); err != nil {
		return nil, fmt.Errorf("failed to unmarshal conversation: %w", err)
	}

	return dbConv.toConversation(), nil
}

func (r *SupabaseRepository) GetUser(ctx context.Context, userID string) (*handler.User, error) {
	data, err := r.client.From("users").
		Select("id, display_name, locale").
		Eq("id", userID).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	var user handler.User
	if err := json.Unmarshal(data, &user); err != nil {
		return nil, fmt.Errorf("failed to unmarshal user: %w", err)
	}

	return &user, nil
}

func (r *SupabaseRepository) SaveMessage(ctx context.Context, msg *handler.Message) error {
	dbMsg := toDBMessage(msg)

	_, err := r.client.From("messages").
		Insert(dbMsg).
		Execute()
	if err != nil {
		return fmt.Errorf("failed to save message: %w", err)
	}

	return nil
}

func (r *SupabaseRepository) UpdateConversation(ctx context.Context, conv *handler.Conversation) error {
	update := map[string]interface{}{
		"last_message_at":      conv.LastMessageAt,
		"last_message_preview": conv.LastPreview,
		"updated_at":           time.Now(),
	}

	_, err := r.client.From("conversations").
		Update(update).
		Eq("id", conv.ID).
		Execute()
	if err != nil {
		return fmt.Errorf("failed to update conversation: %w", err)
	}

	return nil
}

// CreateOrGetConversation finds existing or creates new conversation
func (r *SupabaseRepository) CreateOrGetConversation(ctx context.Context, userID string, personaID, otherUserID *string) (*handler.Conversation, error) {
	// Determine conversation type
	var convType string
	if personaID != nil && *personaID != "" {
		convType = "user_to_ai"
	} else if otherUserID != nil && *otherUserID != "" {
		convType = "user_to_user"
	} else {
		return nil, fmt.Errorf("either persona_id or other_user_id required")
	}

	// Try to find existing conversation
	query := r.client.From("conversations").
		Select("*").
		Eq("user_id", userID).
		Eq("conversation_type", convType)

	if personaID != nil && *personaID != "" {
		query = query.Eq("persona_id", *personaID)
	}
	if otherUserID != nil && *otherUserID != "" {
		query = query.Eq("other_user_id", *otherUserID)
	}

	data, err := query.Single().Execute()
	if err == nil {
		var dbConv dbConversation
		if err := json.Unmarshal(data, &dbConv); err != nil {
			return nil, fmt.Errorf("failed to unmarshal conversation: %w", err)
		}
		return dbConv.toConversation(), nil
	}

	// Create new conversation
	newConv := map[string]interface{}{
		"user_id":           userID,
		"conversation_type": convType,
		"created_at":        time.Now().Format(time.RFC3339),
		"updated_at":        time.Now().Format(time.RFC3339),
	}
	if personaID != nil && *personaID != "" {
		newConv["persona_id"] = *personaID
	}
	if otherUserID != nil && *otherUserID != "" {
		newConv["other_user_id"] = *otherUserID
	}

	data, err = r.client.From("conversations").
		Insert(newConv).
		Single().
		Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to create conversation: %w", err)
	}

	var created dbConversation
	if err := json.Unmarshal(data, &created); err != nil {
		return nil, fmt.Errorf("failed to unmarshal created conversation: %w", err)
	}

	return created.toConversation(), nil
}

// GetMessages retrieves messages for a conversation
func (r *SupabaseRepository) GetMessages(ctx context.Context, conversationID string, limit int, before *string) ([]*handler.Message, error) {
	query := r.client.From("messages").
		Select("*").
		Eq("conversation_id", conversationID)

	data, err := query.Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get messages: %w", err)
	}

	var dbMessages []dbMessage
	if err := json.Unmarshal(data, &dbMessages); err != nil {
		return nil, fmt.Errorf("failed to unmarshal messages: %w", err)
	}

	messages := make([]*handler.Message, len(dbMessages))
	for i, dbm := range dbMessages {
		messages[i] = dbm.toMessage()
	}

	return messages, nil
}

// ============================================
// Database Models
// ============================================

type dbVirtualPersona struct {
	ID                   string          `json:"id"`
	Slug                 string          `json:"slug"`
	Name                 string          `json:"name"`
	NameZh               *string         `json:"name_zh"`
	AvatarURL            *string         `json:"avatar_url"`
	BaseSystemPrompt     string          `json:"base_system_prompt"`
	BaseSystemPromptZh   *string         `json:"base_system_prompt_zh"`
	StrangerPrompt       *string         `json:"stranger_prompt"`
	StrangerPromptZh     *string         `json:"stranger_prompt_zh"`
	AcquaintancePrompt   *string         `json:"acquaintance_prompt"`
	AcquaintancePromptZh *string         `json:"acquaintance_prompt_zh"`
	FriendPrompt         *string         `json:"friend_prompt"`
	FriendPromptZh       *string         `json:"friend_prompt_zh"`
	ClosePrompt          *string         `json:"close_prompt"`
	ClosePromptZh        *string         `json:"close_prompt_zh"`
	IntimatePrompt       *string         `json:"intimate_prompt"`
	IntimatePromptZh     *string         `json:"intimate_prompt_zh"`
	Archetype            *string         `json:"archetype"`
	VoiceStyle           *string         `json:"voice_style"`
	Backstory            json.RawMessage `json:"backstory"`
	IsActive             bool            `json:"is_active"`
}

func (db *dbVirtualPersona) toPersona() *persona.Persona {
	p := &persona.Persona{
		ID:               db.ID,
		Slug:             db.Slug,
		Name:             db.Name,
		BaseSystemPrompt: db.BaseSystemPrompt,
		IsActive:         db.IsActive,
		TierPrompts:      make(map[persona.IntimacyTier]string),
		TierPromptsZh:    make(map[persona.IntimacyTier]string),
	}

	if db.NameZh != nil {
		p.NameZh = *db.NameZh
	}
	if db.AvatarURL != nil {
		p.AvatarURL = *db.AvatarURL
	}
	if db.BaseSystemPromptZh != nil {
		p.BaseSystemPromptZh = *db.BaseSystemPromptZh
	}
	if db.Archetype != nil {
		p.Archetype = *db.Archetype
	}
	if db.VoiceStyle != nil {
		p.VoiceStyle = *db.VoiceStyle
	}

	// Map tier prompts
	if db.StrangerPrompt != nil {
		p.TierPrompts[persona.TierStranger] = *db.StrangerPrompt
	}
	if db.AcquaintancePrompt != nil {
		p.TierPrompts[persona.TierAcquaintance] = *db.AcquaintancePrompt
	}
	if db.FriendPrompt != nil {
		p.TierPrompts[persona.TierFriend] = *db.FriendPrompt
	}
	if db.ClosePrompt != nil {
		p.TierPrompts[persona.TierClose] = *db.ClosePrompt
	}
	if db.IntimatePrompt != nil {
		p.TierPrompts[persona.TierIntimate] = *db.IntimatePrompt
	}

	// Map Chinese tier prompts
	if db.StrangerPromptZh != nil {
		p.TierPromptsZh[persona.TierStranger] = *db.StrangerPromptZh
	}
	if db.AcquaintancePromptZh != nil {
		p.TierPromptsZh[persona.TierAcquaintance] = *db.AcquaintancePromptZh
	}
	if db.FriendPromptZh != nil {
		p.TierPromptsZh[persona.TierFriend] = *db.FriendPromptZh
	}
	if db.ClosePromptZh != nil {
		p.TierPromptsZh[persona.TierClose] = *db.ClosePromptZh
	}
	if db.IntimatePromptZh != nil {
		p.TierPromptsZh[persona.TierIntimate] = *db.IntimatePromptZh
	}

	return p
}

type dbIntimacyLevel struct {
	ID                string    `json:"id"`
	UserID            string    `json:"user_id"`
	PersonaID         string    `json:"persona_id"`
	Score             int       `json:"score"`
	Tier              string    `json:"tier"`
	TotalMessages     int       `json:"total_messages"`
	TotalUserMessages int       `json:"total_user_messages"`
	TotalAIMessages   int       `json:"total_ai_messages"`
	StreakDays        int       `json:"streak_days"`
	LongestStreak     int       `json:"longest_streak"`
	LastInteractionAt *string   `json:"last_interaction_at"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

func (db *dbIntimacyLevel) toIntimacyLevel() *persona.IntimacyLevel {
	level := &persona.IntimacyLevel{
		ID:                db.ID,
		UserID:            db.UserID,
		PersonaID:         db.PersonaID,
		Score:             db.Score,
		Tier:              persona.IntimacyTier(db.Tier),
		TotalMessages:     db.TotalMessages,
		TotalUserMessages: db.TotalUserMessages,
		TotalAIMessages:   db.TotalAIMessages,
		StreakDays:        db.StreakDays,
		LongestStreak:     db.LongestStreak,
		CreatedAt:         db.CreatedAt,
		UpdatedAt:         db.UpdatedAt,
	}

	if db.LastInteractionAt != nil {
		t, _ := time.Parse(time.RFC3339, *db.LastInteractionAt)
		level.LastInteractionAt = t
	}

	return level
}

func toDBIntimacyLevel(level *persona.IntimacyLevel) map[string]interface{} {
	m := map[string]interface{}{
		"user_id":             level.UserID,
		"persona_id":          level.PersonaID,
		"score":               level.Score,
		"tier":                string(level.Tier),
		"total_messages":      level.TotalMessages,
		"total_user_messages": level.TotalUserMessages,
		"total_ai_messages":   level.TotalAIMessages,
		"streak_days":         level.StreakDays,
		"longest_streak":      level.LongestStreak,
		"updated_at":          time.Now(),
	}

	if !level.LastInteractionAt.IsZero() {
		m["last_interaction_at"] = level.LastInteractionAt.Format(time.RFC3339)
	}

	return m
}

type dbConversation struct {
	ID               string  `json:"id"`
	UserID           string  `json:"user_id"`
	OtherUserID      *string `json:"other_user_id"`
	PersonaID        *string `json:"persona_id"`
	ConversationType string  `json:"conversation_type"`
	LastMessageAt    *string `json:"last_message_at"`
	LastPreview      *string `json:"last_message_preview"`
	UnreadCount      int     `json:"unread_count"`
}

func (db *dbConversation) toConversation() *handler.Conversation {
	conv := &handler.Conversation{
		ID:               db.ID,
		UserID:           db.UserID,
		OtherUserID:      db.OtherUserID,
		PersonaID:        db.PersonaID,
		ConversationType: db.ConversationType,
		UnreadCount:      db.UnreadCount,
	}

	if db.LastMessageAt != nil {
		t, _ := time.Parse(time.RFC3339, *db.LastMessageAt)
		conv.LastMessageAt = t
	}
	if db.LastPreview != nil {
		conv.LastPreview = *db.LastPreview
	}

	return conv
}

type dbMessage struct {
	ID              string  `json:"id"`
	ConversationID  string  `json:"conversation_id"`
	SenderType      string  `json:"sender_type"`
	SenderUserID    *string `json:"sender_user_id"`
	SenderPersonaID *string `json:"sender_persona_id"`
	Role            string  `json:"role"`
	Content         string  `json:"content"`
	MediaURL        *string `json:"media_url"`
	MediaType       *string `json:"media_type"`
	CreatedAt       string  `json:"created_at"`
}

func (db *dbMessage) toMessage() *handler.Message {
	msg := &handler.Message{
		ID:              db.ID,
		ConversationID:  db.ConversationID,
		SenderType:      db.SenderType,
		SenderUserID:    db.SenderUserID,
		SenderPersonaID: db.SenderPersonaID,
		Role:            db.Role,
		Content:         db.Content,
	}

	if db.MediaURL != nil {
		msg.MediaURL = *db.MediaURL
	}
	if db.MediaType != nil {
		msg.MediaType = *db.MediaType
	}

	t, _ := time.Parse(time.RFC3339, db.CreatedAt)
	msg.CreatedAt = t

	return msg
}

func toDBMessage(msg *handler.Message) map[string]interface{} {
	m := map[string]interface{}{
		"id":              msg.ID,
		"conversation_id": msg.ConversationID,
		"sender_type":     msg.SenderType,
		"role":            msg.Role,
		"content":         msg.Content,
		"created_at":      msg.CreatedAt,
	}

	if msg.SenderUserID != nil {
		m["sender_user_id"] = *msg.SenderUserID
	}
	if msg.SenderPersonaID != nil {
		m["sender_persona_id"] = *msg.SenderPersonaID
	}

	return m
}
