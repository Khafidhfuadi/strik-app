-- =============================================================================
-- PROCESS MISSED HABITS - Server-side cron for -3 XP penalty
-- =============================================================================
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- Prerequisites: pg_cron extension must be enabled
-- =============================================================================

-- 1. Enable pg_cron if not already enabled
-- (Supabase Pro plan required for pg_cron)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Create the function
CREATE OR REPLACE FUNCTION process_missed_habits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Bypass RLS so we can read/write all users' data
SET search_path = public
AS $$
DECLARE
    yesterday DATE := (NOW() AT TIME ZONE 'Asia/Jakarta')::date - INTERVAL '1 day';
    yesterday_dow INT; -- 0-6 (Monday=0, Sunday=6) to match Flutter weekday-1
    yesterday_day_of_month INT; -- 1-31
    is_yesterday_sunday BOOLEAN;
    week_start DATE; -- Monday of yesterday's week
    week_end DATE;   -- Sunday of yesterday's week
    penalty_amount INT := -3;
    rec RECORD;
    ref_id TEXT;
BEGIN
    -- Calculate day of week: Monday=0 ... Sunday=6 (matching Flutter's weekday-1)
    yesterday_dow := CASE EXTRACT(DOW FROM yesterday)
        WHEN 0 THEN 6  -- Sunday -> 6
        ELSE EXTRACT(DOW FROM yesterday)::int - 1
    END;
    yesterday_day_of_month := EXTRACT(DAY FROM yesterday)::int;
    is_yesterday_sunday := (yesterday_dow = 6);

    -- Calculate week boundaries (Mon-Sun) for weekly check
    week_start := yesterday - (yesterday_dow || ' days')::interval;
    week_end := week_start + INTERVAL '6 days';

    -- =========================================================================
    -- 1. DAILY HABITS: penalty if no log on yesterday (matching days_of_week)
    -- =========================================================================
    FOR rec IN
        SELECT h.id AS habit_id, h.user_id, h.title
        FROM public.habits h
        WHERE h.frequency = 'daily'
          AND (h.created_at AT TIME ZONE 'Asia/Jakarta')::date <= yesterday
          AND (h.end_date IS NULL OR h.end_date::date >= yesterday)
          AND (
              h.days_of_week IS NULL
              OR array_length(h.days_of_week, 1) IS NULL
              OR yesterday_dow = ANY(h.days_of_week)
          )
          AND NOT EXISTS (
              SELECT 1 FROM public.habit_logs hl
              WHERE hl.habit_id = h.id AND hl.target_date = yesterday
          )
    LOOP
        ref_id := 'missed_' || rec.habit_id || '_' || yesterday::text;
        PERFORM _apply_missed_penalty(rec.user_id, penalty_amount, ref_id);
    END LOOP;

    -- =========================================================================
    -- 2. WEEKLY HABITS: penalty on Sunday if ZERO logs the entire week (Mon-Sun)
    --    Weekly habits appear every day, user can complete any day in the week.
    -- =========================================================================
    IF is_yesterday_sunday THEN
        FOR rec IN
            SELECT h.id AS habit_id, h.user_id, h.title
            FROM public.habits h
            WHERE h.frequency = 'weekly'
              AND (h.created_at AT TIME ZONE 'Asia/Jakarta')::date <= week_end
              AND (h.end_date IS NULL OR h.end_date::date >= week_start)
              AND NOT EXISTS (
                  SELECT 1 FROM public.habit_logs hl
                  WHERE hl.habit_id = h.id
                    AND hl.target_date >= week_start
                    AND hl.target_date <= week_end
              )
        LOOP
            ref_id := 'missed_weekly_' || rec.habit_id || '_' || week_start::text;
            PERFORM _apply_missed_penalty(rec.user_id, penalty_amount, ref_id);
        END LOOP;
    END IF;

    -- =========================================================================
    -- 3. MONTHLY HABITS: penalty if yesterday is in days_of_week (day of month)
    --    and no log exists for yesterday
    -- =========================================================================
    FOR rec IN
        SELECT h.id AS habit_id, h.user_id, h.title
        FROM public.habits h
        WHERE h.frequency = 'monthly'
          AND (h.created_at AT TIME ZONE 'Asia/Jakarta')::date <= yesterday
          AND (h.end_date IS NULL OR h.end_date::date >= yesterday)
          AND h.days_of_week IS NOT NULL
          AND array_length(h.days_of_week, 1) > 0
          AND yesterday_day_of_month = ANY(h.days_of_week)
          AND NOT EXISTS (
              SELECT 1 FROM public.habit_logs hl
              WHERE hl.habit_id = h.id AND hl.target_date = yesterday
          )
    LOOP
        ref_id := 'missed_' || rec.habit_id || '_' || yesterday::text;
        PERFORM _apply_missed_penalty(rec.user_id, penalty_amount, ref_id);
    END LOOP;
END;
$$;

-- =============================================================================
-- Helper: Apply penalty (idempotent) + recalculate level
-- =============================================================================
CREATE OR REPLACE FUNCTION _apply_missed_penalty(
    p_user_id UUID,
    p_amount INT,
    p_ref_id TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_xp DOUBLE PRECISION;
    new_level INT;
BEGIN
    -- Idempotency: skip if already penalized
    IF EXISTS (
        SELECT 1 FROM public.xp_logs
        WHERE user_id = p_user_id AND reference_id = p_ref_id
    ) THEN
        RETURN;
    END IF;

    -- Insert penalty log
    INSERT INTO public.xp_logs (user_id, amount, reason, reference_id)
    VALUES (p_user_id, p_amount, 'Missed Habit', p_ref_id);

    -- Update XP (floor at 0)
    UPDATE public.profiles
    SET xp = GREATEST(xp + p_amount, 0)
    WHERE id = p_user_id;

    -- Read new XP
    SELECT xp INTO new_xp FROM public.profiles WHERE id = p_user_id;

    -- Recalculate level (cumulative thresholds matching Flutter)
    new_level := CASE
        WHEN new_xp >= 2500 THEN 10
        WHEN new_xp >= 2100 THEN 9
        WHEN new_xp >= 1700 THEN 8
        WHEN new_xp >= 1300 THEN 7
        WHEN new_xp >= 950  THEN 6
        WHEN new_xp >= 700  THEN 5
        WHEN new_xp >= 500  THEN 4
        WHEN new_xp >= 350  THEN 3
        WHEN new_xp >= 250  THEN 2
        WHEN new_xp >= 100  THEN 1
        ELSE 1
    END;

    UPDATE public.profiles SET level = new_level WHERE id = p_user_id;
END;
$$;

-- 3. Schedule the cron job to run daily at 00:00 WIB (17:00 UTC)
-- Remove existing schedule if any
SELECT cron.unschedule('process-missed-habits')
WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'process-missed-habits'
);

-- Schedule: every day at 17:00 UTC = 00:00 WIB
SELECT cron.schedule(
    'process-missed-habits',           -- job name
    '0 17 * * *',                      -- cron expression: 17:00 UTC daily
    'SELECT process_missed_habits()'   -- SQL to execute
);

-- =============================================================================
-- MANUAL TEST: Run this to test the function immediately
-- SELECT process_missed_habits();
--
-- VERIFY: Check xp_logs for missed habit penalties
-- SELECT * FROM xp_logs WHERE reason = 'Missed Habit' ORDER BY created_at DESC;
--
-- VERIFY: Check cron job schedule
-- SELECT * FROM cron.job WHERE jobname = 'process-missed-habits';
--
-- VERIFY: Check cron job run history
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
-- =============================================================================
