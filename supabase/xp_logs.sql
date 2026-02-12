-- Create XP Logs table
CREATE TABLE IF NOT EXISTS public.xp_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    amount INTEGER NOT NULL,
    reason TEXT,
    reference_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.xp_logs ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can insert their own XP logs"
ON public.xp_logs
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own XP logs"
ON public.xp_logs
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS xp_logs_user_id_idx ON public.xp_logs(user_id);

-- Unique index to prevent duplicate XP awards for the same reference (e.g. same feed reaction)
CREATE UNIQUE INDEX IF NOT EXISTS xp_logs_user_reference_idx ON public.xp_logs(user_id, reference_id) WHERE reference_id IS NOT NULL;
