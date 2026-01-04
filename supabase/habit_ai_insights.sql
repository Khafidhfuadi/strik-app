-- Create table for storing Habit AI Insights
create table if not exists public.habit_ai_insights (
  id uuid default gen_random_uuid() primary key,
  habit_id uuid references public.habits(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  period text not null, -- Format: 'YYYY-MM', used for quota tracking
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.habit_ai_insights enable row level security;

-- Policies
create policy "Users can view their own insights"
  on public.habit_ai_insights for select
  using (auth.uid() = user_id);

create policy "Users can insert their own insights"
  on public.habit_ai_insights for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own insights"
  on public.habit_ai_insights for delete
  using (auth.uid() = user_id);

-- Create index for faster quota lookups
create index if not exists habit_ai_insights_quota_idx 
  on public.habit_ai_insights (habit_id, period);
