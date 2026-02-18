-- =============================================================================
-- HABIT CHALLENGES MIGRATION
-- =============================================================================
-- Run this in Supabase SQL Editor to create all tables for the Habit Challenge feature.
-- =============================================================================

-- 1. Tabel induk challenge
CREATE TABLE IF NOT EXISTS habit_challenges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    creator_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    habit_title text NOT NULL,
    habit_description text,
    habit_color text NOT NULL DEFAULT '0xFF4CAF50',
    habit_frequency text NOT NULL DEFAULT 'daily',
    habit_days_of_week int[],
    habit_frequency_count int,
    end_date timestamptz NOT NULL,
    show_in_feed boolean NOT NULL DEFAULT true,
    invite_code text UNIQUE NOT NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
    created_at timestamptz DEFAULT now()
);

-- 2. Tabel peserta challenge
CREATE TABLE IF NOT EXISTS habit_challenge_participants (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_id uuid NOT NULL REFERENCES habit_challenges(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    habit_id uuid NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    joined_at timestamptz DEFAULT now(),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'left')),
    UNIQUE(challenge_id, user_id)
);

-- 3. Tabel leaderboard challenge
CREATE TABLE IF NOT EXISTS habit_challenge_leaderboard (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_id uuid NOT NULL REFERENCES habit_challenges(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    total_completed int NOT NULL DEFAULT 0,
    total_expected int NOT NULL DEFAULT 0,
    completion_rate double precision NOT NULL DEFAULT 0.0,
    current_streak int NOT NULL DEFAULT 0,
    score double precision NOT NULL DEFAULT 0.0,
    rank int NOT NULL DEFAULT 0,
    updated_at timestamptz DEFAULT now(),
    UNIQUE(challenge_id, user_id)
);

-- 4. Tambah kolom challenge_id ke tabel habits (nullable)
ALTER TABLE habits ADD COLUMN IF NOT EXISTS challenge_id uuid REFERENCES habit_challenges(id) ON DELETE SET NULL;

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- habit_challenges: semua authenticated user bisa baca, hanya creator bisa insert/update
ALTER TABLE habit_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read challenges"
    ON habit_challenges FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Creator can insert challenges"
    ON habit_challenges FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creator can update own challenges"
    ON habit_challenges FOR UPDATE
    TO authenticated
    USING (auth.uid() = creator_id);

-- habit_challenge_participants: participant bisa baca semua, insert sendiri
ALTER TABLE habit_challenge_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read participants"
    ON habit_challenge_participants FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can join challenge"
    ON habit_challenge_participants FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own participation"
    ON habit_challenge_participants FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- habit_challenge_leaderboard: semua bisa baca, system update via service role
ALTER TABLE habit_challenge_leaderboard ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read challenge leaderboard"
    ON habit_challenge_leaderboard FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Participants can insert leaderboard entries"
    ON habit_challenge_leaderboard FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM habit_challenge_participants
            WHERE challenge_id = habit_challenge_leaderboard.challenge_id
            AND user_id = auth.uid()
            AND status = 'active'
        )
    );

CREATE POLICY "Participants can update leaderboard entries"
    ON habit_challenge_leaderboard FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM habit_challenge_participants
            WHERE challenge_id = habit_challenge_leaderboard.challenge_id
            AND user_id = auth.uid()
            AND status = 'active'
        )
    );

-- =============================================================================
-- INDEXES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_habit_challenges_creator ON habit_challenges(creator_id);
CREATE INDEX IF NOT EXISTS idx_habit_challenges_invite_code ON habit_challenges(invite_code);
CREATE INDEX IF NOT EXISTS idx_habit_challenges_status ON habit_challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenge_participants_challenge ON habit_challenge_participants(challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_participants_user ON habit_challenge_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_challenge_leaderboard_challenge ON habit_challenge_leaderboard(challenge_id);
CREATE INDEX IF NOT EXISTS idx_habits_challenge_id ON habits(challenge_id);
