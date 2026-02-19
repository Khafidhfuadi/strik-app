-- Function to securely award XP to a user, bypassing RLS
-- This function checks if an XP log with the given reference_id already exists for the user.
-- If not, it inserts the log and updates the user's profile with the new XP and Level.

create or replace function award_xp_securely(
  p_user_id uuid,
  p_amount double precision,
  p_reason text,
  p_reference_id text,
  p_new_xp double precision,
  p_new_level int
)
returns void
language plpgsql
security definer -- Runs with privileges of the creator (admin), bypassing RLS
as $$
begin
  -- 1. Idempotency Check
  if exists (
    select 1 from public.xp_logs
    where user_id = p_user_id
    and reference_id = p_reference_id
  ) then
    -- Already awarded, do nothing
    return;
  end if;

  -- 2. Insert XP Log
  insert into public.xp_logs (user_id, amount, reason, reference_id)
  values (p_user_id, p_amount, p_reason, p_reference_id);

  -- 3. Update Profile
  update public.profiles
  set 
    xp = p_new_xp,
    level = p_new_level,
    updated_at = now()
  where id = p_user_id;

end;
$$;
