-- DROP existing function first to ensure clean update
drop function if exists process_habit_reminders();

create or replace function process_habit_reminders()
returns void
language plpgsql
security definer
as $$
declare
  now_timestamp timestamptz;
  day_of_week int; -- 1 (Mon) to 7 (Sun)
  day_of_month int; -- 1 to 31
  current_time_str text;
begin
  -- Loop through all users/timezones could be expensive if naive. 
  -- Instead, we process per timezone or just rely on the connection time?
  -- Wait, pg_cron runs on the server. 'now()' is UTC.
  -- We need to check EACH user's local time.
  
  -- Iterate through appropriate habits
  -- We can't use a single variable for all. We do it in the query.
  
  insert into notifications (recipient_id, sender_id, type, title, body)
  select
    h.user_id,
    h.user_id,
    'reminder',
    'Saatnya ' || h.title || '! ⏰',
    'Jangan lupa kerjain habitmu sekarang!'
  from
    habits h
    join profiles p on h.user_id = p.id
  where
    h.reminder_enabled = true
    and h.reminder_time is not null
    
    -- 1. TIME CHECK (User's Local Time)
    and to_char(now() at time zone p.timezone, 'HH24:MI') = h.reminder_time
    
    -- 2. FREQUENCY CHECK
    and (
      -- CASE: Daily (Always runs)
      h.frequency = 'daily'
      
      OR
      
      -- CASE: Weekly (Check Day of Week)
      (
        h.frequency = 'weekly'
        and h.days_of_week is not null
        -- App sends 0=Mon, 6=Sun. Postgres ISODOW is 1=Mon, 7=Sun.
        -- So we define AppDay = PostgresDay - 1.
        and (
            select count(*)
            from jsonb_array_elements_text(to_jsonb(h.days_of_week)) as day_elem
            where (day_elem::int) = (extract(isodow from (now() at time zone p.timezone))::int - 1)
        ) > 0
      )
      
      OR
      
      -- CASE: Monthly (Check Day of Month)
      (
        h.frequency = 'monthly'
        and h.days_of_week is not null
        -- 'days_of_week' is reused for dates (1-31) in App Controller
        and (
            select count(*)
            from jsonb_array_elements_text(to_jsonb(h.days_of_week)) as date_elem
            where (date_elem::int) = (extract(day from (now() at time zone p.timezone))::int)
        ) > 0
      )
    )

    -- 3. DUPLICATE CHECK (Prevent double send in same minute)
    and not exists (
      select 1 from notifications n
      where n.recipient_id = h.user_id
        and n.type = 'reminder'
        and n.title = 'Saatnya ' || h.title || '! ⏰'
        and n.created_at > now() - interval '1 minute'
    );
end;
$$;
