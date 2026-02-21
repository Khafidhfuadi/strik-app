-- Function to safely increment user XP and recalculate level directly on the server
-- Prevents race conditions from client-side XP calculation overwriting the database
-- Supports idempotency via reference_id

CREATE OR REPLACE FUNCTION increment_user_xp(
    p_user_id UUID,
    p_amount DOUBLE PRECISION,
    p_reason TEXT,
    p_reference_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_xp DOUBLE PRECISION;
    v_current_level INT;
    v_new_xp DOUBLE PRECISION;
    v_new_level INT;
    v_leveled_up BOOLEAN := false;
BEGIN
    -- 1. Idempotency Check
    IF p_reference_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.xp_logs
        WHERE user_id = p_user_id
        AND reference_id = p_reference_id
    ) THEN
        -- Already awarded, return current state without changes
        SELECT xp, level INTO v_current_xp, v_current_level 
        FROM public.profiles WHERE id = p_user_id;

        RETURN jsonb_build_object(
            'success', false,
            'message', 'XP already awarded for this reference',
            'xp', v_current_xp,
            'level', v_current_level,
            'leveled_up', false
        );
    END IF;

    -- 2. Lock the profile row to prevent race conditions during calculation
    SELECT xp, level INTO v_current_xp, v_current_level
    FROM public.profiles
    WHERE id = p_user_id
    FOR UPDATE;

    -- Handle case where profile doesn't exist (should not happen normally)
    IF v_current_xp IS NULL THEN
        RAISE EXCEPTION 'Profile not found for user_id: %', p_user_id;
    END IF;

    -- 3. Calculate new XP
    v_new_xp := GREATEST(v_current_xp + p_amount, 0);

    -- Calculate level (matching Flutter GamificationController logic)
    -- Max level is 10.
    v_new_level := CASE
        WHEN v_new_xp >= 5900 THEN 10
        WHEN v_new_xp >= 4800 THEN 9
        WHEN v_new_xp >= 3800 THEN 8
        WHEN v_new_xp >= 2900 THEN 7
        WHEN v_new_xp >= 2100 THEN 6
        WHEN v_new_xp >= 1400 THEN 5
        WHEN v_new_xp >= 800  THEN 4
        WHEN v_new_xp >= 300  THEN 3
        WHEN v_new_xp >= 100  THEN 2
        ELSE 1
    END;

    -- Check if level increased
    IF v_new_level > v_current_level AND p_amount > 0 THEN
        v_leveled_up := true;
    END IF;

    -- 4. Update Profile
    UPDATE public.profiles
    SET 
        xp = v_new_xp,
        level = v_new_level,
        updated_at = now()
    WHERE id = p_user_id;

    -- 5. Insert XP Log (we do this last after calculating everything successfully)
    -- We only insert if amount != 0 or if we specifically want to track 0 XP events (like initializing)
    IF p_amount <> 0 THEN
        INSERT INTO public.xp_logs (user_id, amount, reason, reference_id)
        VALUES (p_user_id, p_amount, p_reason, p_reference_id);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'xp', v_new_xp,
        'level', v_new_level,
        'leveled_up', v_leveled_up
    );
END;
$$;
