package persona

import (
	"context"
	"time"
)

// IntimacyTier represents the relationship level
type IntimacyTier string

const (
	TierStranger     IntimacyTier = "stranger"     // 0-100
	TierAcquaintance IntimacyTier = "acquaintance" // 101-300
	TierFriend       IntimacyTier = "friend"       // 301-500
	TierClose        IntimacyTier = "close"        // 501-750
	TierIntimate     IntimacyTier = "intimate"     // 751-1000
)

// Tier thresholds
const (
	ThresholdAcquaintance = 101
	ThresholdFriend       = 301
	ThresholdClose        = 501
	ThresholdIntimate     = 751
	MaxScore              = 1000
)

// IntimacyLevel holds the relationship state between a user and persona
type IntimacyLevel struct {
	ID                  string       `json:"id"`
	UserID              string       `json:"user_id"`
	PersonaID           string       `json:"persona_id"`
	Score               int          `json:"score"`
	Tier                IntimacyTier `json:"tier"`
	TotalMessages       int          `json:"total_messages"`
	TotalUserMessages   int          `json:"total_user_messages"`
	TotalAIMessages     int          `json:"total_ai_messages"`
	AverageMessageLength float64     `json:"average_message_length"`
	StreakDays          int          `json:"streak_days"`
	LongestStreak       int          `json:"longest_streak"`
	LastInteractionAt   time.Time    `json:"last_interaction_at"`
	UnlockedTraits      []string     `json:"unlocked_traits"`
	UnlockedTopics      []string     `json:"unlocked_topics"`
	CreatedAt           time.Time    `json:"created_at"`
	UpdatedAt           time.Time    `json:"updated_at"`
}

// ScoreToTier converts numeric score to tier
func ScoreToTier(score int) IntimacyTier {
	switch {
	case score < ThresholdAcquaintance:
		return TierStranger
	case score < ThresholdFriend:
		return TierAcquaintance
	case score < ThresholdClose:
		return TierFriend
	case score < ThresholdIntimate:
		return TierClose
	default:
		return TierIntimate
	}
}

// TierToLabel returns a human-readable label for the tier
func TierToLabel(tier IntimacyTier, locale string) string {
	labels := map[IntimacyTier]map[string]string{
		TierStranger: {
			"en": "Stranger",
			"zh": "陌生人",
		},
		TierAcquaintance: {
			"en": "Acquaintance",
			"zh": "熟人",
		},
		TierFriend: {
			"en": "Friend",
			"zh": "朋友",
		},
		TierClose: {
			"en": "Close",
			"zh": "亲密",
		},
		TierIntimate: {
			"en": "Intimate",
			"zh": "知己",
		},
	}

	if tierLabels, ok := labels[tier]; ok {
		if label, ok := tierLabels[locale]; ok {
			return label
		}
		return tierLabels["en"]
	}
	return string(tier)
}

// IntimacyDelta represents score changes from an interaction
type IntimacyDelta struct {
	MessageLength   int  // Length of user's message
	IsQuestion      bool // User asked a question
	IsEmotional     bool // Message contains emotional content
	IsFirstToday    bool // First interaction of the day
	ContinuesStreak bool // Continues a daily streak
	ResponseQuality int  // AI-assessed engagement quality (0-10)
}

// CalculateScoreIncrease determines points earned from interaction
func CalculateScoreIncrease(delta IntimacyDelta) int {
	points := 0

	// Base points for message length (1-5 points)
	switch {
	case delta.MessageLength > 200:
		points += 5
	case delta.MessageLength > 100:
		points += 3
	case delta.MessageLength > 20:
		points += 2
	default:
		points += 1
	}

	// Bonus points for engagement signals
	if delta.IsQuestion {
		points += 2 // Questions show interest
	}
	if delta.IsEmotional {
		points += 3 // Emotional sharing deepens connection
	}
	if delta.IsFirstToday {
		points += 5 // Daily login/interaction bonus
	}
	if delta.ContinuesStreak {
		points += 2 // Streak continuation bonus
	}

	// Response quality multiplier (AI-determined, 0-10)
	points += delta.ResponseQuality / 2

	return points
}

// IntimacyService handles intimacy-related operations
type IntimacyService struct {
	repo Repository
}

// Repository interface for data persistence
type Repository interface {
	GetIntimacyLevel(ctx context.Context, userID, personaID string) (*IntimacyLevel, error)
	SaveIntimacyLevel(ctx context.Context, level *IntimacyLevel) error
	CreateIntimacyLevel(ctx context.Context, userID, personaID string) (*IntimacyLevel, error)
}

// NewIntimacyService creates a new intimacy service
func NewIntimacyService(repo Repository) *IntimacyService {
	return &IntimacyService{repo: repo}
}

// GetOrCreateIntimacy retrieves or creates an intimacy level
func (s *IntimacyService) GetOrCreateIntimacy(ctx context.Context, userID, personaID string) (*IntimacyLevel, error) {
	level, err := s.repo.GetIntimacyLevel(ctx, userID, personaID)
	if err != nil {
		// Create new intimacy record for first interaction
		return s.repo.CreateIntimacyLevel(ctx, userID, personaID)
	}
	return level, nil
}

// UpdateIntimacy updates the intimacy level after an interaction
func (s *IntimacyService) UpdateIntimacy(ctx context.Context, level *IntimacyLevel, delta IntimacyDelta) (int, bool, error) {
	oldTier := level.Tier
	increase := CalculateScoreIncrease(delta)

	// Update score (capped at MaxScore)
	level.Score = min(level.Score+increase, MaxScore)
	level.Tier = ScoreToTier(level.Score)

	// Update message counts
	level.TotalMessages++
	level.TotalUserMessages++

	// Update average message length
	totalLength := level.AverageMessageLength * float64(level.TotalUserMessages-1)
	level.AverageMessageLength = (totalLength + float64(delta.MessageLength)) / float64(level.TotalUserMessages)

	// Update streak
	level.LastInteractionAt = time.Now()
	if delta.IsFirstToday {
		if delta.ContinuesStreak {
			level.StreakDays++
			if level.StreakDays > level.LongestStreak {
				level.LongestStreak = level.StreakDays
			}
		} else {
			level.StreakDays = 1
		}
	}

	// Check for tier upgrade
	tierChanged := level.Tier != oldTier

	// Persist changes
	if err := s.repo.SaveIntimacyLevel(ctx, level); err != nil {
		return 0, false, err
	}

	return increase, tierChanged, nil
}

// IsFirstInteractionToday checks if this is the first interaction today
func IsFirstInteractionToday(lastInteraction time.Time) bool {
	if lastInteraction.IsZero() {
		return true
	}
	now := time.Now()
	return lastInteraction.Year() != now.Year() ||
		lastInteraction.YearDay() != now.YearDay()
}

// ContinuesStreak checks if interaction continues a streak
func ContinuesStreak(lastInteraction time.Time) bool {
	if lastInteraction.IsZero() {
		return false
	}
	now := time.Now()
	yesterday := now.AddDate(0, 0, -1)
	return lastInteraction.Year() == yesterday.Year() &&
		lastInteraction.YearDay() == yesterday.YearDay()
}

// min returns the smaller of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
