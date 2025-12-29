package session

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Message represents a chat message in the session
type Message struct {
	Role      string    `json:"role"`      // "user", "assistant", "system"
	Content   string    `json:"content"`
	Timestamp time.Time `json:"timestamp"`
	MessageID string    `json:"message_id,omitempty"`
}

// SessionMetadata holds metadata about a conversation session
type SessionMetadata struct {
	IntimacyTier  string    `json:"intimacy_tier"`
	PersonaMood   string    `json:"persona_mood"`
	LastActivity  time.Time `json:"last_activity"`
	MessageCount  int       `json:"message_count"`
	UserID        string    `json:"user_id"`
	PersonaID     string    `json:"persona_id"`
}

// RedisSession manages conversation sessions in Redis
type RedisSession struct {
	client *redis.Client
	ttl    time.Duration
}

// RedisConfig holds Redis connection configuration
type RedisConfig struct {
	Addr     string
	Password string
	DB       int
	TTL      time.Duration
}

// NewRedisSession creates a new Redis session manager
func NewRedisSession(cfg RedisConfig) *RedisSession {
	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr,
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	ttl := cfg.TTL
	if ttl == 0 {
		ttl = 24 * time.Hour // Default: 24 hour TTL
	}

	return &RedisSession{
		client: client,
		ttl:    ttl,
	}
}

// Key patterns
func messagesKey(conversationID string) string {
	return fmt.Sprintf("session:%s:messages", conversationID)
}

func metadataKey(conversationID string) string {
	return fmt.Sprintf("session:%s:metadata", conversationID)
}

func moodKey(personaID string) string {
	return fmt.Sprintf("persona:%s:mood", personaID)
}

func userActiveSessionsKey(userID string) string {
	return fmt.Sprintf("user:%s:active_sessions", userID)
}

// Ping checks Redis connectivity
func (r *RedisSession) Ping(ctx context.Context) error {
	return r.client.Ping(ctx).Err()
}

// Close closes the Redis connection
func (r *RedisSession) Close() error {
	return r.client.Close()
}

// AddMessage appends a message to conversation history
func (r *RedisSession) AddMessage(ctx context.Context, conversationID string, msg Message) error {
	if msg.Timestamp.IsZero() {
		msg.Timestamp = time.Now()
	}

	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal message: %w", err)
	}

	key := messagesKey(conversationID)

	pipe := r.client.Pipeline()
	pipe.RPush(ctx, key, data)
	pipe.LTrim(ctx, key, -100, -1) // Keep last 100 messages
	pipe.Expire(ctx, key, r.ttl)
	_, err = pipe.Exec(ctx)

	if err != nil {
		return fmt.Errorf("failed to add message: %w", err)
	}

	return nil
}

// GetMessages retrieves conversation history for LLM context
func (r *RedisSession) GetMessages(ctx context.Context, conversationID string, limit int) ([]Message, error) {
	key := messagesKey(conversationID)

	// Get last N messages
	data, err := r.client.LRange(ctx, key, int64(-limit), -1).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to get messages: %w", err)
	}

	messages := make([]Message, 0, len(data))
	for _, d := range data {
		var msg Message
		if err := json.Unmarshal([]byte(d), &msg); err != nil {
			return nil, fmt.Errorf("failed to unmarshal message: %w", err)
		}
		messages = append(messages, msg)
	}

	return messages, nil
}

// GetMessageCount returns the number of messages in a conversation
func (r *RedisSession) GetMessageCount(ctx context.Context, conversationID string) (int64, error) {
	return r.client.LLen(ctx, messagesKey(conversationID)).Result()
}

// ClearMessages removes all messages from a conversation
func (r *RedisSession) ClearMessages(ctx context.Context, conversationID string) error {
	return r.client.Del(ctx, messagesKey(conversationID)).Err()
}

// SetMetadata stores session metadata
func (r *RedisSession) SetMetadata(ctx context.Context, conversationID string, meta SessionMetadata) error {
	data, err := json.Marshal(meta)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	key := metadataKey(conversationID)
	return r.client.Set(ctx, key, data, r.ttl).Err()
}

// GetMetadata retrieves session metadata
func (r *RedisSession) GetMetadata(ctx context.Context, conversationID string) (*SessionMetadata, error) {
	key := metadataKey(conversationID)
	data, err := r.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, nil // No metadata found
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get metadata: %w", err)
	}

	var meta SessionMetadata
	if err := json.Unmarshal([]byte(data), &meta); err != nil {
		return nil, fmt.Errorf("failed to unmarshal metadata: %w", err)
	}

	return &meta, nil
}

// GetMood retrieves current mood for a persona
func (r *RedisSession) GetMood(ctx context.Context, personaID string) string {
	mood, err := r.client.Get(ctx, moodKey(personaID)).Result()
	if err == redis.Nil || err != nil {
		return "neutral"
	}
	return mood
}

// SetMood sets persona mood (changes periodically or based on events)
func (r *RedisSession) SetMood(ctx context.Context, personaID, mood string) error {
	// Mood expires after 4 hours
	return r.client.Set(ctx, moodKey(personaID), mood, 4*time.Hour).Err()
}

// AddActiveSession tracks that a user has an active session
func (r *RedisSession) AddActiveSession(ctx context.Context, userID, conversationID string) error {
	key := userActiveSessionsKey(userID)
	pipe := r.client.Pipeline()
	pipe.SAdd(ctx, key, conversationID)
	pipe.Expire(ctx, key, r.ttl)
	_, err := pipe.Exec(ctx)
	return err
}

// GetActiveSessions returns all active conversation IDs for a user
func (r *RedisSession) GetActiveSessions(ctx context.Context, userID string) ([]string, error) {
	return r.client.SMembers(ctx, userActiveSessionsKey(userID)).Result()
}

// RemoveActiveSession removes a conversation from active sessions
func (r *RedisSession) RemoveActiveSession(ctx context.Context, userID, conversationID string) error {
	return r.client.SRem(ctx, userActiveSessionsKey(userID), conversationID).Err()
}

// FormatMessagesForLLM converts session messages to LLM-compatible format
func FormatMessagesForLLM(messages []Message) []map[string]string {
	formatted := make([]map[string]string, len(messages))
	for i, msg := range messages {
		formatted[i] = map[string]string{
			"role":    msg.Role,
			"content": msg.Content,
		}
	}
	return formatted
}

// BuildContextWindow creates a context window from recent messages
// It ensures the context doesn't exceed maxTokens (rough estimate)
func BuildContextWindow(messages []Message, maxTokens int) []Message {
	// Rough estimate: 1 token ≈ 4 characters
	const charsPerToken = 4
	maxChars := maxTokens * charsPerToken

	totalChars := 0
	startIdx := len(messages)

	// Work backwards to find how many messages fit
	for i := len(messages) - 1; i >= 0; i-- {
		msgChars := len(messages[i].Content) + len(messages[i].Role)
		if totalChars+msgChars > maxChars {
			break
		}
		totalChars += msgChars
		startIdx = i
	}

	return messages[startIdx:]
}

// ============================================
// Rate Limiting
// ============================================

func rateLimitKey(userID string, window string) string {
	return fmt.Sprintf("ratelimit:%s:%s", userID, window)
}

// CheckRateLimit checks if a user has exceeded the rate limit
// Returns (allowed, remaining, resetTime, error)
func (r *RedisSession) CheckRateLimit(ctx context.Context, userID string, limit int, windowSeconds int) (bool, int, time.Time, error) {
	window := time.Now().Unix() / int64(windowSeconds)
	key := rateLimitKey(userID, fmt.Sprintf("%d", window))

	pipe := r.client.Pipeline()
	incrCmd := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, time.Duration(windowSeconds)*time.Second)
	_, err := pipe.Exec(ctx)
	if err != nil {
		return false, 0, time.Time{}, fmt.Errorf("rate limit check failed: %w", err)
	}

	count := int(incrCmd.Val())
	remaining := limit - count
	if remaining < 0 {
		remaining = 0
	}

	resetTime := time.Unix((window+1)*int64(windowSeconds), 0)

	return count <= limit, remaining, resetTime, nil
}

// GetRateLimitInfo returns current rate limit info without incrementing
func (r *RedisSession) GetRateLimitInfo(ctx context.Context, userID string, limit int, windowSeconds int) (int, int, error) {
	window := time.Now().Unix() / int64(windowSeconds)
	key := rateLimitKey(userID, fmt.Sprintf("%d", window))

	count, err := r.client.Get(ctx, key).Int()
	if err == redis.Nil {
		return 0, limit, nil
	}
	if err != nil {
		return 0, 0, err
	}

	remaining := limit - count
	if remaining < 0 {
		remaining = 0
	}

	return count, remaining, nil
}

// Client returns the underlying Redis client for use in middleware
func (r *RedisSession) Client() *redis.Client {
	return r.client
}
