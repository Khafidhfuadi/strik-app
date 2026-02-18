-- Function to update all participant habits (instances) when the challenge (template) is updated by the creator
create or replace function update_challenge_participant_habits(
  p_challenge_id uuid,
  p_title text,
  p_description text,
  p_color text,
  p_frequency text,
  p_days_of_week int[],
  p_frequency_count int,
  p_end_date timestamptz
)
returns void
language plpgsql
security definer -- Bypass RLS
as $$
begin
  -- 1. Check if the executing user is the creator of the challenge
  -- This ensures only the creator can trigger this mass update
  if not exists (
    select 1 from habit_challenges
    where id = p_challenge_id
    and creator_id = auth.uid()
  ) then
    raise exception 'Not authorized: You are not the creator of this challenge';
  end if;

  -- 2. Update all habits linked to this challenge
  update habits
  set
    title = p_title,
    description = p_description,
    color = p_color,
    frequency = p_frequency,
    days_of_week = p_days_of_week,
    frequency_count = p_frequency_count,
    end_date = p_end_date,
    updated_at = now()
  where challenge_id = p_challenge_id;
end;
$$;
