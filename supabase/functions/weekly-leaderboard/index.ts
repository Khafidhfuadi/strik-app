import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

// Score Calculation Types
interface Habit {
  id: string
  user_id: string
  frequency: string
  days_of_week?: number[]
  frequency_count?: number
}

interface UserScore {
  userId: string
  username: string
  hybridScore: number
  totalExpected: number
  totalCompleted: number
  completionRate: number
}

function roundToSingleDecimal(value: number): number {
  return Math.round(value * 10) / 10
}

serve(async (req: Request) => {
  // 1. Verify Authentication (Service Role only for Cron)
  // Warning: Cron jobs typically don't send auth headers like user sessions.
  // We rely on service_role key initiated self-call or pg_cron.
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  
  try {
    console.log("Starting Weekly Leaderboard Calculation...")

    // 2. Determine Previous Week Range
    // Runs on Monday morning 1AM UTC (8AM WIB). We want the previous cycle.
    // Cycle boundary: Monday 01:00 UTC = Monday 08:00 WIB (consistent with client-side)
    const now = new Date()
    
    // Find the Monday of the current calendar week
    const day = now.getUTCDay() // 0=Sun, 1=Mon, ..., 6=Sat
    const diffToMon = (day + 6) % 7 // Distance from Mon (0 if Mon)
    const currentMonday = new Date(now)
    currentMonday.setUTCDate(now.getUTCDate() - diffToMon)
    // Set to Monday 01:00 UTC (= 08:00 WIB), the cycle boundary
    currentMonday.setUTCHours(1, 0, 0, 0)

    // Start of Last Week cycle = This Monday 01:00 UTC - 7 days
    const startOfLastWeek = new Date(currentMonday)
    startOfLastWeek.setUTCDate(currentMonday.getUTCDate() - 7)

    // End of Last Week cycle = This Monday 01:00 UTC (exclusive upper bound)
    // Using < endOfLastWeek for queries (strict upper bound, consistent with client)
    const endOfLastWeek = new Date(currentMonday)

    console.log(`Calculating for range: ${startOfLastWeek.toISOString()} to ${endOfLastWeek.toISOString()} (exclusive)`)

    // 3. Fetch All Users
    const { data: users, error: usersError } = await supabase
      .from('profiles')
      .select('id, username')
    
    if (usersError) throw usersError
    if (!users) throw new Error("No users found")

    // 4. Calculate Score for EACH User
    const userScores: UserScore[] = []

    for (const user of users) {
      // a. Get Habits (Active during the last week)
      // Only select habits created BEFORE the end of the cycle
      const { data: habits } = await supabase
        .from('habits')
        .select('id, frequency, days_of_week, frequency_count, created_at')
        .eq('user_id', user.id)
        .lt('created_at', endOfLastWeek.toISOString())

      if (!habits || habits.length === 0) {
        userScores.push({ 
            userId: user.id, 
            username: user.username, 
            hybridScore: 0,
            totalExpected: 0,
            totalCompleted: 0,
            completionRate: 0
        })
        continue
      }

      // b. Calculate Total Expected
      let totalExpected = 0
      for (const h of habits) {
        if (h.frequency === 'daily') {
          // days_of_week is typically stored as JSON/array in DB
          const days = h.days_of_week
          if (Array.isArray(days) && days.length > 0) {
            totalExpected += days.length // Specific days selected
          } else {
            totalExpected += 7 // Everyday
          }
        } else {
          // weekly or monthly
          const freq = h.frequency_count || 1
          // clamp 0-7
          totalExpected += Math.min(Math.max(freq, 0), 7)
        }
      }

      // c. Calculate Actual Completions
      // logs.completed_at in [startOfLastWeek, endOfLastWeek) — strict upper bound
      // Consistent with client-side: gte(start) AND lt(end)
      const { count } = await supabase
        .from('habit_logs')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'completed')
        .in('habit_id', habits.map(h => h.id))
        .gte('completed_at', startOfLastWeek.toISOString())
        .lt('completed_at', endOfLastWeek.toISOString())

      const totalCompleted = count || 0

      // d. Hybrid Score Formula
      // completionRate = (totalCompleted / totalExpected) * 100
      // hybridScore = (completionRate * 1.0) + (totalCompleted * 0.5)
      
      let completionRate = 0
      if (totalExpected > 0) {
        completionRate = (totalCompleted / totalExpected) * 100
        if (completionRate > 100) completionRate = 100
      }
      
      const hybridScore = (completionRate * 1.0) + (totalCompleted * 0.5)
      
      userScores.push({
        userId: user.id,
        username: user.username || 'User',
        hybridScore: hybridScore,
        totalExpected,
        totalCompleted,
        completionRate
      })
    }

    console.log(`Calculated scores for ${userScores.length} users`)

    // 5. Build friend map and determine rankings per user's own circle
    const { data: friendships } = await supabase
      .from('friendships')
      .select('requester_id, receiver_id')
      .eq('status', 'accepted')

    const friendMap = new Map<string, string[]>() // userId -> list of friendIds

    // Initialize map
    for (const u of users) {
      friendMap.set(u.id, [])
    }

    // Populate friends
    if (friendships) {
      for (const f of friendships) {
        // Bi-directional
        if (friendMap.has(f.requester_id)) friendMap.get(f.requester_id)?.push(f.receiver_id)
        if (friendMap.has(f.receiver_id)) friendMap.get(f.receiver_id)?.push(f.requester_id)
      }
    }

    const notificationsToSend: any[] = []
    const leaderboardEntries: any[] = []
    // Track which users already have a leaderboard entry to prevent duplicates
    const processedUserIds = new Set<string>()
    // Track which recipients already received a notification to prevent duplicates
    const notifiedRecipients = new Set<string>()

    const weekStartDate = startOfLastWeek.toISOString().split('T')[0]

    for (const user of users) {
      const friendIds = friendMap.get(user.id) || []
      // Circle = Friends + Self
      const circleIds = [...friendIds, user.id]
      
      // Get scores for this user's circle
      const circleScores = userScores
        .filter(s => circleIds.includes(s.userId))
        .sort((a, b) => b.hybridScore - a.hybridScore)
      
      if (circleScores.length === 0) continue

      // Find current user's rank in THEIR OWN circle
      const userRankIndex = circleScores.findIndex(score => score.userId === user.id)
      const currentUserScore = circleScores[userRankIndex]

      // Only write ONE leaderboard entry per user (from their own circle perspective)
      if (userRankIndex >= 0 && currentUserScore && !processedUserIds.has(user.id)) {
        processedUserIds.add(user.id)
        leaderboardEntries.push({
          week_start_date: weekStartDate,
          user_id: currentUserScore.userId,
          rank: userRankIndex + 1,
          total_points: roundToSingleDecimal(currentUserScore.hybridScore),
          completion_rate: roundToSingleDecimal(currentUserScore.completionRate),
          total_completed: currentUserScore.totalCompleted,
          total_habits: currentUserScore.totalExpected,
          total_participants: circleScores.length
        })
      }
      
      // Send notification about the winner — only ONCE per recipient
      const winner = circleScores[0]
      if (winner.hybridScore > 0 && winner.userId !== user.id && !notifiedRecipients.has(user.id)) {
        notifiedRecipients.add(user.id)
        notificationsToSend.push({
          recipient_id: user.id,
          sender_id: winner.userId,
          type: 'leaderboard_winner',
          title: 'Juara Minggu Ini! 👑',
          body: `${winner.username} jadi juara leaderboard di circle kamu minggu lalu!`,
          created_at: new Date().toISOString(),
          is_read: false
        })
      }
    }

    if (leaderboardEntries.length > 0) {
        // Use upsert to prevent duplicate entries if function is called multiple times
        const { error: leaderboardError } = await supabase
            .from('weekly_leaderboards')
            .upsert(leaderboardEntries, { 
              onConflict: 'week_start_date,user_id',
              ignoreDuplicates: false 
            })
        
        if (leaderboardError) {
             console.error("Error upserting leaderboard:", leaderboardError)
             // Fallback: try regular insert if upsert fails (no unique constraint yet)
             const { error: insertError } = await supabase
                 .from('weekly_leaderboards')
                 .insert(leaderboardEntries)
             if (insertError) {
                 console.error("Error inserting leaderboard (fallback):", insertError)
             } else {
                 console.log(`Inserted ${leaderboardEntries.length} leaderboard entries (fallback).`)
             }
        } else {
             console.log(`Upserted ${leaderboardEntries.length} leaderboard entries.`)
        }
    }
    
    // 6. Batch Insert Notifications
    if (notificationsToSend.length > 0) {
      // Chunking if necessary, but for now insert all
      const { error: insertError } = await supabase
        .from('notifications')
        .insert(notificationsToSend)
      
      if (insertError) throw insertError
      console.log(`Sent ${notificationsToSend.length} notifications.`)
    } else {
      console.log("No notifications to send.")
    }

    return new Response(JSON.stringify({ 
      success: true, 
      leaderboard_entries: leaderboardEntries.length,
      notifications: notificationsToSend.length 
    }), {
      headers: { "Content-Type": "application/json" },
      status: 200
    })

  } catch (err: any) {
    console.error("Critical Error in Weekly Leaderboard:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500
    })
  }
})
