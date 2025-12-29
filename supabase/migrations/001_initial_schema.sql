-- ============================================
-- WINK (微刻) - Initial Database Schema
-- ============================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- USERS & AUTHENTICATION
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    avatar_url TEXT,
    bio TEXT,
    gender VARCHAR(20),
    birthday DATE,
    locale VARCHAR(10) DEFAULT 'en',
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- VIRTUAL PERSONAS (AI Characters - 10-20)
-- ============================================
CREATE TABLE virtual_personas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    name_zh VARCHAR(100),
    avatar_url TEXT,

    -- Persona configuration (used by openai-agents-go)
    base_system_prompt TEXT NOT NULL,
    base_system_prompt_zh TEXT,

    -- Intimacy-tier prompts (unlocked progressively)
    stranger_prompt TEXT,
    stranger_prompt_zh TEXT,
    acquaintance_prompt TEXT,
    acquaintance_prompt_zh TEXT,
    friend_prompt TEXT,
    friend_prompt_zh TEXT,
    close_prompt TEXT,
    close_prompt_zh TEXT,
    intimate_prompt TEXT,
    intimate_prompt_zh TEXT,

    backstory JSONB DEFAULT '{}',
    archetype VARCHAR(50),
    voice_style VARCHAR(50),

    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- CONVERSATIONS (Both user↔user and user↔AI)
-- ============================================
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Participants
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Either another user OR an AI persona (mutually exclusive)
    other_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    persona_id UUID REFERENCES virtual_personas(id) ON DELETE CASCADE,

    conversation_type VARCHAR(20) NOT NULL,

    -- Redis session reference
    redis_session_key VARCHAR(255),

    -- Metadata
    last_message_at TIMESTAMPTZ,
    last_message_preview TEXT,
    unread_count INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_conversation CHECK (
        (conversation_type = 'user_to_user' AND other_user_id IS NOT NULL AND persona_id IS NULL) OR
        (conversation_type = 'user_to_ai' AND persona_id IS NOT NULL AND other_user_id IS NULL)
    )
);

-- ============================================
-- MESSAGES (Full chat history - humans & LLM)
-- ============================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,

    -- Who sent this message
    sender_type VARCHAR(20) NOT NULL,
    sender_user_id UUID REFERENCES users(id),
    sender_persona_id UUID REFERENCES virtual_personas(id),

    -- Message content
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,

    -- Media
    has_media BOOLEAN DEFAULT false,

    -- AI-specific metadata
    model_used VARCHAR(100),
    tokens_used INTEGER,
    intimacy_tier_at_send VARCHAR(20),

    -- Status
    is_read BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_sender CHECK (
        (sender_type = 'user' AND sender_user_id IS NOT NULL) OR
        (sender_type = 'ai' AND sender_persona_id IS NOT NULL) OR
        (sender_type = 'system')
    )
);

-- ============================================
-- MEDIA ATTACHMENTS (references Supabase Storage)
-- ============================================
CREATE TABLE media_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Owner reference (polymorphic)
    owner_type VARCHAR(20) NOT NULL,
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    post_id UUID,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,

    -- Storage paths
    bucket_name VARCHAR(50) NOT NULL,
    storage_path TEXT NOT NULL,
    thumbnail_path TEXT,

    -- File metadata
    file_name VARCHAR(255),
    mime_type VARCHAR(100) NOT NULL,
    file_size_bytes BIGINT,

    -- Media-specific metadata
    media_type VARCHAR(20) NOT NULL,
    width INTEGER,
    height INTEGER,
    duration_seconds FLOAT,

    -- Processing status
    status VARCHAR(20) DEFAULT 'uploaded',

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INTIMACY SYSTEM
-- ============================================
CREATE TABLE intimacy_levels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    persona_id UUID NOT NULL REFERENCES virtual_personas(id) ON DELETE CASCADE,

    score INTEGER DEFAULT 0,
    tier VARCHAR(20) DEFAULT 'stranger',

    -- Interaction stats
    total_messages INTEGER DEFAULT 0,
    total_user_messages INTEGER DEFAULT 0,
    total_ai_messages INTEGER DEFAULT 0,
    average_message_length FLOAT DEFAULT 0,

    -- Engagement signals
    last_interaction_at TIMESTAMPTZ,
    streak_days INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,

    -- Unlocked content
    unlocked_traits JSONB DEFAULT '[]',
    unlocked_topics JSONB DEFAULT '[]',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, persona_id)
);

-- Tier thresholds comment
COMMENT ON COLUMN intimacy_levels.tier IS
'stranger: 0-100, acquaintance: 101-300, friend: 301-500, close: 501-750, intimate: 751-1000';

-- ============================================
-- SQUARE (Timeline/Feed)
-- ============================================
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Author (user OR AI persona)
    author_type VARCHAR(20) NOT NULL,
    author_user_id UUID REFERENCES users(id),
    author_persona_id UUID REFERENCES virtual_personas(id),

    content TEXT,
    content_zh TEXT,
    media_urls JSONB DEFAULT '[]',

    locale VARCHAR(10) DEFAULT 'en',
    visibility VARCHAR(20) DEFAULT 'public',

    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_author CHECK (
        (author_type = 'user' AND author_user_id IS NOT NULL) OR
        (author_type = 'ai' AND author_persona_id IS NOT NULL)
    )
);

-- Add foreign key for media_attachments.post_id
ALTER TABLE media_attachments
ADD CONSTRAINT fk_media_post
FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_user_id) WHERE sender_user_id IS NOT NULL;
CREATE INDEX idx_conversations_user ON conversations(user_id, last_message_at DESC);
CREATE INDEX idx_intimacy_user_persona ON intimacy_levels(user_id, persona_id);
CREATE INDEX idx_posts_author ON posts(author_user_id) WHERE author_user_id IS NOT NULL;
CREATE INDEX idx_posts_persona ON posts(author_persona_id) WHERE author_persona_id IS NOT NULL;
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_media_message ON media_attachments(message_id) WHERE message_id IS NOT NULL;
CREATE INDEX idx_media_post ON media_attachments(post_id) WHERE post_id IS NOT NULL;

-- ============================================
-- ENABLE REALTIME (for Supabase)
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all profiles" ON users
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = auth_id);

-- Conversations table
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own conversations" ON conversations
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

CREATE POLICY "Users can create conversations" ON conversations
    FOR INSERT WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Messages table
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their conversations" ON messages
    FOR SELECT USING (
        conversation_id IN (
            SELECT id FROM conversations
            WHERE user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
        )
    );

CREATE POLICY "Users can insert messages in their conversations" ON messages
    FOR INSERT WITH CHECK (
        conversation_id IN (
            SELECT id FROM conversations
            WHERE user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
        )
    );

-- Posts table
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public posts are visible to all" ON posts
    FOR SELECT USING (visibility = 'public');

CREATE POLICY "Users can create posts" ON posts
    FOR INSERT WITH CHECK (
        author_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- Intimacy levels table
ALTER TABLE intimacy_levels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own intimacy levels" ON intimacy_levels
    FOR SELECT USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Virtual personas are public
ALTER TABLE virtual_personas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Virtual personas are public" ON virtual_personas
    FOR SELECT USING (is_active = true);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_intimacy_levels_updated_at
    BEFORE UPDATE ON intimacy_levels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
