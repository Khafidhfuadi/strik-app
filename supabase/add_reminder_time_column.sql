-- Add reminder time column for habit challenges
ALTER TABLE habit_challenges
ADD COLUMN habit_reminder_time TEXT;

-- Optional: Add a comment
COMMENT ON COLUMN habit_challenges.habit_reminder_time IS 'Reminder time in format HH:MM (UTC or Local depending on app logic)';
