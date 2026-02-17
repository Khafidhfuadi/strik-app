-- =============================================================================
-- SCHEDULE WEEKLY LEADERBOARD
-- =============================================================================
-- Run this in Supabase SQL Editor to automate the leaderboard generation.
--
-- Prerequisite:
-- 1. Enable `pg_cron` and `pg_net` extensions in Dashboard > Database > Extensions.
-- 2. Replace 'YOUR_SERVICE_ROLE_KEY_HERE' with your actual Service Role Key.
--    Find it in Dashboard > Settings > API > Service Role Key (secret).
-- =============================================================================

-- 1. Enable Extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Schedule Cron Job
-- Runs every Monday at 01:00 UTC (08:00 WIB)
-- This ensures the previous week (Mon-Sun) is fully complete.
SELECT cron.schedule(
    'invoke-weekly-leaderboard', -- Job name
    '0 1 * * 1',                 -- Cron expression: Monday at 01:00 UTC (08:00 WIB)
    $$
    SELECT
        net.http_post(
            url:='https://mzeadddkvahdzhyffghy.supabase.co/functions/v1/weekly-leaderboard',
            headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY_HERE"}'::jsonb,
            body:='{}'::jsonb
        ) as request_id;
    $$
);

-- =============================================================================
-- VERIFICATION
-- =============================================================================
-- Check if job is scheduled:
-- SELECT * FROM cron.job;
--
-- Check run history:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC;
-- =============================================================================
