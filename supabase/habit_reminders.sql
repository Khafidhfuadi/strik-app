-- 1. Enable pg_cron extension
create extension if not exists pg_cron;

-- 2. Create function to process reminders
create or replace function process_habit_reminders()
returns void
language plpgsql
security definer
as $$
begin
  insert into notifications (recipient_id, sender_id, type, title, body)
  select
    h.user_id,
    h.user_id, -- Sender is self (system)
    'reminder',
    'Saatnya ' || h.title || '! ⏰',
    'Jangan lupa kerjain habitmu sekarang!'
  from
    habits h
    join profiles p on h.user_id = p.id
  where
    h.reminder_enabled = true
    and h.reminder_time is not null
    -- Match time in user's local timezone (HH:MM)
    and to_char(now() at time zone p.timezone, 'HH24:MI') = h.reminder_time
    -- Prevent duplicate notifications created within the last minute
    and not exists (
      select 1 from notifications n
      where n.recipient_id = h.user_id
        and n.type = 'reminder'
        and n.title = 'Saatnya ' || h.title || '! ⏰'
        and n.created_at > now() - interval '1 minute'
    );
end;
$$;

-- 3. Schedule the cron job to run every minute
select cron.schedule('process-habit-reminders', '* * * * *', 'select process_habit_reminders()');
