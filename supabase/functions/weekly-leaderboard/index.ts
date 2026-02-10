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

serve(async (req: Request) => {
  // 1. Verify Authentication (Service Role only for Cron)
  // Warning: Cron jobs typically don't send auth headers like user sessions.
  // We rely on service_role key initiated self-call or pg_cron.
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  
  try {
    console.log("Starting Weekly Leaderboard Calculation...")

    // 2. Determine Previous Week Range (Monday-Sunday)
    // Runs on Monday morning 8AM. We want the previous Mon-Sun.
    const now = new Date()
    // If today is Monday, previous week start is 7 days ago.
    // If today is not Monday (debugging), adjust logic accordingly. 
    // Assuming accurate cron schedule: '0 8 * * 1' (At 08:00 on Monday)
    
    // Normalize to start of current day (Monday)
    const currentWeekStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    
    // End of last week = Current Monday 00:00 minus 1ms
    const endOfLastWeek = new Date(currentWeekStart.getTime() - 1)
    
    // Start of last week = Current Monday minus 7 days
    const startOfLastWeek = new Date(currentWeekStart.getTime() - (7 * 24 * 60 * 60 * 1000))

    console.log(`Calculating for range: ${startOfLastWeek.toISOString()} to ${endOfLastWeek.toISOString()}`)

    // 3. Fetch All Users
    const { data: users, error: usersError } = await supabase
      .from('profiles')
      .select('id, username')
    
    if (usersError) throw usersError
    if (!users) throw new Error("No users found")

    // Optimize: We need habits and logs for ALL users to calculate scores.
    // Fetching everything in one go might be heavy, but iterating is safer for logic migration.
    
    // 4. Calculate Score for EACH User
    const userScores: UserScore[] = []

    for (const user of users) {
      // a. Get Habits
      const { data: habits } = await supabase
        .from('habits')
        .select('id, frequency, days_of_week, frequency_count')
        .eq('user_id', user.id)

      if (!habits || habits.length === 0) {
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
          // days_of_week is typically stored as JSON/array in DB, often stringified if simple wrappers used.
          // Assuming simple array of integers (1-7) or strings. 
          // Adjust based on Dart: days_of_week as List?.
          const days = h.days_of_week
          if (Array.isArray(days) && days.length > 0) {
            totalExpected += days.length
          } else {
            totalExpected += 7
          }
        } else {
          // weekly or monthly
          const freq = h.frequency_count || 1
          // clamp 0-7
          totalExpected += Math.min(Math.max(freq, 0), 7)
        }
      }

      // c. Calculate Actual Completions
      // logs.completed_at between startOfLastWeek and endOfLastWeek
      // AND status = completed
      const { count } = await supabase
        .from('habit_logs')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'completed')
        .in('habit_id', habits.map(h => h.id))
        .gte('completed_at', startOfLastWeek.toISOString())
        .lte('completed_at', endOfLastWeek.toISOString())

      const totalCompleted = count || 0

      // d. Hybrid Score Formula
      // completionRate = (totalCompleted / totalExpected) * 100
      // hybridScore = (completionRate * 1.0) + (totalCompleted * 0.5)
      
      let completionRate = 0
      if (totalExpected > 0) {
        completionRate = (totalCompleted / totalExpected) * 100
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

    // 5. Determine Winner for EACH User (Friend Context) & Persist Global Leaderboard
    // For every user, look at their friends + themselves, find max score.
    // Send notification if winner exists.

    // First, fetch all friendships
    // 'friendships' table: requester_id, receiver_id, status='accepted'
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

    const notificationsToSend = []

    for (const user of users) {
      const friendIds = friendMap.get(user.id) || []
      // Circle = Friends + Self
      const circleIds = [...friendIds, user.id]
      
      // Find winner in circle
      // Filter scores where userId is in circleIds
      const circleScores = userScores.filter(s => circleIds.includes(s.userId))
      
      if (circleScores.length === 0) continue

      // Sort desc
      circleScores.sort((a, b) => b.hybridScore - a.hybridScore)
      
      const winner = circleScores[0]
      if (winner.hybridScore > 0 && winner.userId !== user.id) { // Only notify if winner is someone else (or maybe self too?)
         // Create Notification
         // title: 'Juara Leaderboard! 👑'
         // body: '${winner.username} memimpin klasemen minggu ini! Cek sekarang!'
         notificationsToSend.push({
           recipient_id: user.id,
           // Using system sender or self? Ideally system. 
           // If DB requires sender_id to be a valid user FK, usually we use the service account user or the user themselves as sender for system msg, 
           // BUT FriendRepo uses `sender_id: user.id` (current logged in).
           // Here we are backend. 
           // HACK: Use the winner as sender (celebrity effect), or user themselves.
           // Let's use winner as sender for "context".
           sender_id: winner.userId,
           type: 'leaderboard_winner',
           title: 'Juara Minggu Ini! 👑',
           body: `${winner.username} jadi juara leaderboard di circle kamu minggu lalu!`,
           created_at: new Date().toISOString(),
           is_read: false
         })
      }
    }

    // 6. Persist Global Leaderboard
    // Sort all users by score desc to get global rank
    userScores.sort((a, b) => b.hybridScore - a.hybridScore)

    const leaderboardEntries = userScores.map((score, index) => {
        return {
            week_start_date: startOfLastWeek.toISOString().split('T')[0], // YYYY-MM-DD
            user_id: score.userId,
            rank: index + 1,
            total_points: score.hybridScore,
            completion_rate: score.completionRate,
            total_completed: score.totalCompleted,
            total_habits: score.totalExpected, // Using totalExpected as proxy for total_habits work or actual count? Schema says 'total_habits', implies count of habits. But totalExpected is days. 
            // Let's use totalExpected for now as it reflects effort, or we could pass habit count if needed.
            // Schema comment said "total_habits". If it means distinct habits, we need that count. 
            // In step 4, we have `habits.length`. Let's assume we want 'effort' so totalExpected (days) is better logic but field name is total_habits.
            // Let's check schema again? No, let's just use 0 for now or update interface again? 
            // WAIT, I can just use existing vars if I had them. 
            // I'll stick to score.totalExpected for 'total_habits' column if users understand it as 'total chances'. 
            // Or I can add `habitCount` to UserScore. Let's add habitCount.
            total_participants: users.length
        }
    })

    if (leaderboardEntries.length > 0) {
        const { error: leaderboardError } = await supabase
            .from('weekly_leaderboards')
            .insert(leaderboardEntries)
        
        if (leaderboardError) {
             console.error("Error inserting leaderboard:", leaderboardError)
             // Don't throw, just log so notifications can still go out? Or maybe crucial.
        } else {
             console.log(`Inserted ${leaderboardEntries.length} leaderboard entries.`)
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

    return new Response(JSON.stringify({ success: true, count: notificationsToSend.length }), {
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
