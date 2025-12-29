package persona

import (
	"context"
	"fmt"

	"github.com/nlpodyssey/openai-agents-go/agents"
)

// Persona represents an AI character
type Persona struct {
	ID                   string                  `json:"id"`
	Slug                 string                  `json:"slug"`
	Name                 string                  `json:"name"`
	NameZh               string                  `json:"name_zh"`
	AvatarURL            string                  `json:"avatar_url"`
	BaseSystemPrompt     string                  `json:"base_system_prompt"`
	BaseSystemPromptZh   string                  `json:"base_system_prompt_zh"`
	TierPrompts          map[IntimacyTier]string `json:"tier_prompts"`
	TierPromptsZh        map[IntimacyTier]string `json:"tier_prompts_zh"`
	Archetype            string                  `json:"archetype"`
	VoiceStyle           string                  `json:"voice_style"`
	Backstory            map[string]interface{}  `json:"backstory"`
	IsActive             bool                    `json:"is_active"`
}

// GetName returns the name in the specified locale
func (p *Persona) GetName(locale string) string {
	if locale == "zh" && p.NameZh != "" {
		return p.NameZh
	}
	return p.Name
}

// DynamicPersonaInstructions implements agents.InstructionsGetter
// This allows the persona's instructions to change based on intimacy level
type DynamicPersonaInstructions struct {
	Persona       *Persona
	IntimacyLevel *IntimacyLevel
	Locale        string // "en" or "zh"
	Mood          string // Current mood state
	UserName      string // Optional: user's display name
}

// GetInstructions builds the full system prompt based on intimacy tier and locale
func (d DynamicPersonaInstructions) GetInstructions(ctx context.Context, agent *agents.Agent) (string, error) {
	// Select base prompt by locale
	basePrompt := d.Persona.BaseSystemPrompt
	tierPrompts := d.Persona.TierPrompts

	if d.Locale == "zh" {
		if d.Persona.BaseSystemPromptZh != "" {
			basePrompt = d.Persona.BaseSystemPromptZh
		}
		if d.Persona.TierPromptsZh != nil {
			tierPrompts = d.Persona.TierPromptsZh
		}
	}

	// Get tier-specific prompt overlay
	tierPrompt := ""
	if tierPrompts != nil {
		tierPrompt = tierPrompts[d.IntimacyLevel.Tier]
	}

	// Build relationship context
	relationshipContext := d.buildRelationshipContext()

	// Build mood modifier
	moodModifier := d.getMoodModifier()

	// Language instruction
	langInstruction := d.getLanguageInstruction()

	// Combine all prompts
	fullPrompt := fmt.Sprintf(`%s

%s

%s

%s

## Behavior Guidelines for "%s" tier:
%s`,
		basePrompt,
		relationshipContext,
		moodModifier,
		langInstruction,
		TierToLabel(d.IntimacyLevel.Tier, d.Locale),
		tierPrompt,
	)

	return fullPrompt, nil
}

func (d DynamicPersonaInstructions) buildRelationshipContext() string {
	userRef := "the user"
	if d.UserName != "" {
		userRef = d.UserName
	}

	return fmt.Sprintf(`## Current Relationship State
- Talking to: %s
- Intimacy Level: %s (Score: %d/1000)
- Messages exchanged: %d
- Current streak: %d days
- Current mood: %s`,
		userRef,
		TierToLabel(d.IntimacyLevel.Tier, d.Locale),
		d.IntimacyLevel.Score,
		d.IntimacyLevel.TotalMessages,
		d.IntimacyLevel.StreakDays,
		d.Mood,
	)
}

func (d DynamicPersonaInstructions) getMoodModifier() string {
	moodModifiers := map[string]map[string]string{
		"happy": {
			"en": "You're in a great mood today. Be extra cheerful and playful.",
			"zh": "你今天心情很好。格外开朗和俏皮。",
		},
		"tired": {
			"en": "You're a bit tired. Responses are shorter, maybe a bit dreamy.",
			"zh": "你有点累了。回复简短一些，可能有点梦幻。",
		},
		"curious": {
			"en": "You're feeling curious. Ask more questions about the user.",
			"zh": "你感到好奇。多问一些关于用户的问题。",
		},
		"flirty": {
			"en": "You're feeling flirtatious. Be more teasing and suggestive.",
			"zh": "你感觉有点调皮。更多地调侃和暗示。",
		},
		"thoughtful": {
			"en": "You're in a reflective mood. Share deeper thoughts and ask meaningful questions.",
			"zh": "你处于沉思的心情。分享更深层的想法，问有意义的问题。",
		},
		"neutral": {
			"en": "",
			"zh": "",
		},
	}

	if moods, ok := moodModifiers[d.Mood]; ok {
		if modifier, ok := moods[d.Locale]; ok && modifier != "" {
			return fmt.Sprintf("## Current Mood\n%s", modifier)
		}
		if modifier, ok := moods["en"]; ok && modifier != "" {
			return fmt.Sprintf("## Current Mood\n%s", modifier)
		}
	}
	return ""
}

func (d DynamicPersonaInstructions) getLanguageInstruction() string {
	if d.Locale == "zh" {
		return `## Language
Always respond in Chinese (简体中文). Match the user's communication style and tone.
Use natural, conversational Chinese that feels authentic.`
	}
	return `## Language
Always respond in English. Match the user's communication style and tone.
Use natural, conversational English that feels authentic.`
}

// PersonaService handles persona-related operations
type PersonaService struct {
	repo          PersonaRepository
	sessionStore  SessionStore
	intimacySvc   *IntimacyService
	config        *Config
}

// PersonaRepository interface for persona data
type PersonaRepository interface {
	GetPersona(ctx context.Context, personaID string) (*Persona, error)
	GetPersonaBySlug(ctx context.Context, slug string) (*Persona, error)
	ListActivePersonas(ctx context.Context) ([]*Persona, error)
}

// SessionStore interface for session management
type SessionStore interface {
	GetMood(ctx context.Context, personaID string) string
	SetMood(ctx context.Context, personaID, mood string) error
}

// Config holds service configuration
type Config struct {
	LLMModel    string // e.g., "grok-beta" or custom model
	LLMEndpoint string // API endpoint
	LLMAPIKey   string // API key
}

// NewPersonaService creates a new persona service
func NewPersonaService(repo PersonaRepository, session SessionStore, intimacy *IntimacyService, config *Config) *PersonaService {
	return &PersonaService{
		repo:         repo,
		sessionStore: session,
		intimacySvc:  intimacy,
		config:       config,
	}
}

// CreatePersonaAgent creates an agent for a specific persona + user relationship
func (s *PersonaService) CreatePersonaAgent(
	ctx context.Context,
	persona *Persona,
	intimacy *IntimacyLevel,
	locale string,
	userName string,
) *agents.Agent {
	// Get current mood from session store (or default)
	mood := s.sessionStore.GetMood(ctx, persona.ID)
	if mood == "" {
		mood = "neutral"
	}

	agent := agents.New(persona.GetName(locale)).
		WithInstructionsGetter(DynamicPersonaInstructions{
			Persona:       persona,
			IntimacyLevel: intimacy,
			Locale:        locale,
			Mood:          mood,
			UserName:      userName,
		}).
		WithModel(s.config.LLMModel)

	return agent
}

// GetPersonaWithIntimacy retrieves a persona along with the user's intimacy level
func (s *PersonaService) GetPersonaWithIntimacy(
	ctx context.Context,
	personaID string,
	userID string,
) (*Persona, *IntimacyLevel, error) {
	persona, err := s.repo.GetPersona(ctx, personaID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get persona: %w", err)
	}

	intimacy, err := s.intimacySvc.GetOrCreateIntimacy(ctx, userID, personaID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get intimacy: %w", err)
	}

	return persona, intimacy, nil
}
