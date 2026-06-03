-- =============================================================================
-- CLEANUP DUPLICATE WEEKLY LEADERBOARD ENTRIES
-- =============================================================================
-- Run this ONCE in Supabase SQL Editor to clean up existing duplicate data
-- caused by the edge function bug that wrote multiple entries per user per week.
--
-- This script will:
-- 1. Remove duplicate entries, keeping only the one with the BEST rank per user per week
-- 2. Add a UNIQUE constraint to prevent future duplicates
-- =============================================================================

-- Step 1: Delete duplicate entries, keeping only the one with the best (lowest) rank
-- For each (week_start_date, user_id) pair, keep only the row with the minimum rank.
-- If ranks are also duplicated, keep the one with the lowest id (oldest).
DELETE FROM weekly_leaderboards
WHERE id NOT IN (
    SELECT DISTINCT ON (week_start_date, user_id) id
    FROM weekly_leaderboards
    ORDER BY week_start_date, user_id, rank ASC, id ASC
);

-- Step 2: Add a UNIQUE constraint to prevent future duplicates
-- This ensures only ONE entry per user per week can exist
ALTER TABLE weekly_leaderboards
    ADD CONSTRAINT unique_weekly_leaderboard_entry
    UNIQUE (week_start_date, user_id);

-- =============================================================================
-- VERIFICATION
-- =============================================================================
-- Check that no duplicates remain:
-- SELECT week_start_date, user_id, COUNT(*) as cnt
-- FROM weekly_leaderboards
-- GROUP BY week_start_date, user_id
-- HAVING COUNT(*) > 1;
--
-- Should return 0 rows.
-- =============================================================================
