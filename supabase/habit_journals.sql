-- Create habit_journals table
create table if not exists public.habit_journals (
  id uuid default gen_random_uuid() primary key,
  habit_id uuid references public.habits(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  
  -- Ensure 1 journal per habit per day (based on created_at date)
  -- Note: This unique index relies on UTC date. If we want local time, it's harder in DB.
  -- For now, we will rely on application logic for "local day" uniqueness, 
  -- or just accept one per UTC day which is usually fine for simple apps.
  -- But to be safe, I won't enforce DB constraint on date yet to avoid timezone issues 
  -- blocking legitimate "next day" posts if timezones shift. 
  -- Application layer will handle "has journal for today" check.
  constraint habit_journals_content_check check (char_length(content) > 0)
);

-- Enable RLS
alter table public.habit_journals enable row level security;

-- Policies
create policy "Users can view their own habit journals"
  on public.habit_journals for select
  using (auth.uid() = user_id);

create policy "Users can insert their own habit journals"
  on public.habit_journals for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own habit journals"
  on public.habit_journals for update
  using (auth.uid() = user_id);

create policy "Users can delete their own habit journals"
  on public.habit_journals for delete
  using (auth.uid() = user_id);
