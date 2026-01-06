import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')

// --- Helper Functions for JWT & Crypto ---

function arrayBufferToBase64Url(buffer: ArrayBuffer | Uint8Array): string {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer)
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function stringToUint8Array(str: string): Uint8Array {
  const chars = []
  for (let i = 0; i < str.length; i++) {
    chars.push(str.charCodeAt(i))
  }
  return new Uint8Array(chars)
}

function str2ab(str: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length);
  const bufView = new Uint8Array(buf);
  for (let i = 0, strLen = str.length; i < strLen; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Remove PEM header/footer and newlines
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const binaryDerString = atob(pemContents)
  const binaryDer = str2ab(binaryDerString)

  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )
}

async function createSignedJwt(email: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  }
  const claimSet = {
    iss: email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  const encodedHeader = arrayBufferToBase64Url(stringToUint8Array(JSON.stringify(header)))
  const encodedClaimSet = arrayBufferToBase64Url(stringToUint8Array(JSON.stringify(claimSet)))
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`

  const privateKey = await importPrivateKey(privateKeyPem)
  const dataToSign = stringToUint8Array(unsignedToken)
  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    dataToSign as unknown as BufferSource
  )
  const encodedSignature = arrayBufferToBase64Url(signatureBuffer)

  return `${unsignedToken}.${encodedSignature}`
}

// --- Main Handler ---

// --- Main Handler ---

serve(async (req: Request) => {
  try {
    const payload = await req.json()
    console.log('Webhook Payload:', JSON.stringify(payload))

    const { table, record, type } = payload
    
    // Only handle INSERT events for now
    if (type !== 'INSERT') {
      return new Response(JSON.stringify({ message: 'Ignored: Not an INSERT event' }), { status: 200 })
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    // -- 2. Generate Google OAuth2 Access Token (Do this once) --
    const jwt = await createSignedJwt(
      FIREBASE_SERVICE_ACCOUNT.client_email,
      FIREBASE_SERVICE_ACCOUNT.private_key
    )

    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    })

    const tokenData = await tokenResponse.json()
    if (!tokenData.access_token) {
      throw new Error('Failed to get Google access token: ' + JSON.stringify(tokenData))
    }
    const accessToken = tokenData.access_token
    const projectId = FIREBASE_SERVICE_ACCOUNT.project_id


    // Helper to send FCM
    const sendFCM = async (token: string, title: string, body: string, data: any = {}) => {
      // Construct message payload
      const payload: any = {
        token: token,
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...data
        },
      }

      // Only add "notification" block if NOT a 'new_story' type
      // For 'new_story', we want SILENT DATA so Flutter Background Handler wakes up
      // and updates the Widget + Shows Local Notification manually.
      if (data.type !== 'new_story') {
        payload.notification = { title, body }
      } else {
        // Embed title/body in data for manual display
        payload.data.title = title
        payload.data.body = body
      }

      const resp = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ message: payload }),
        }
      )
      return resp.json()
    }


    // --- LOGIC DISTRIBUTOR ---

    // CASE A: NEW STORY (Table: stories)
    // Notify all accepted friends
    if (table === 'stories') {
      const creatorId = record.user_id
      
      // 1. Get Creator Profile (for username)
      const { data: creator } = await supabaseAdmin
        .from('profiles')
        .select('username')
        .eq('id', creatorId)
        .single()
      
      const creatorName = creator?.username || 'Someone'

      // 2. Find Friends
      // Friends are in 'friendships' where status='accepted' AND (requester_id=creator OR receiver_id=creator)
      const { data: friendships } = await supabaseAdmin
        .from('friendships')
        .select('requester_id, receiver_id')
        .eq('status', 'accepted')
        .or(`requester_id.eq.${creatorId},receiver_id.eq.${creatorId}`)
      
      if (!friendships || friendships.length === 0) {
        return new Response(JSON.stringify({ message: 'No friends to notify' }), { status: 200 })
      }

      // Extract Friend IDs and Deduplicate
      const rawFriendIds = friendships.map((f: any) => 
        f.requester_id === creatorId ? f.receiver_id : f.requester_id
      )
      const friendIds = [...new Set(rawFriendIds)] // Remove duplicates

      console.log(`Found ${friendIds.length} unique friends (from ${rawFriendIds.length} rows) for user ${creatorId}`)

      // 3. Get FCM Tokens for Friends
      const { data: profiles } = await supabaseAdmin
        .from('profiles')
        .select('id, fcm_token')
        .in('id', friendIds)
        .not('fcm_token', 'is', null) // Only those with tokens

      if (!profiles || profiles.length === 0) {
        return new Response(JSON.stringify({ message: 'No friends have FCM tokens' }), { status: 200 })
      }

      // 4. Send Notifications in Loop (or Promise.all)
      const promises = profiles.map((p: any) => {
        if (!p.fcm_token) return Promise.resolve(null);
        return sendFCM(
          p.fcm_token, 
          `${creatorName} bikin momentz baru!`, 
          'gas liat sekarang!',
          { 
            story_id: record.id, 
            type: 'new_story',
            username: creatorName,
            media_url: record.media_url,
            created_at: record.created_at
          }
        )
      })

      await Promise.all(promises)
      
      return new Response(JSON.stringify({ message: `Sent ${promises.length} notifications` }), { status: 200 })

    } 

    // CASE C: NEW FEED POST (Table: posts)
    // Notify all accepted friends
    else if (table === 'posts') {
      const creatorId = record.user_id
        
      // 1. Get Creator Profile (for username)
      const { data: creator } = await supabaseAdmin
        .from('profiles')
        .select('username')
        .eq('id', creatorId)
        .single()
      
      const creatorName = creator?.username || 'Someone'

      // 2. Find Friends
      const { data: friendships } = await supabaseAdmin
        .from('friendships')
        .select('requester_id, receiver_id')
        .eq('status', 'accepted')
        .or(`requester_id.eq.${creatorId},receiver_id.eq.${creatorId}`)
      
      if (!friendships || friendships.length === 0) {
        return new Response(JSON.stringify({ message: 'No friends to notify' }), { status: 200 })
      }

      // Extract Friend IDs and Deduplicate
      const rawFriendIds = friendships.map((f: any) => 
        f.requester_id === creatorId ? f.receiver_id : f.requester_id
      )
      const friendIds = [...new Set(rawFriendIds)]

      // 3. Get FCM Tokens
      const { data: profiles } = await supabaseAdmin
        .from('profiles')
        .select('id, fcm_token')
        .in('id', friendIds)
        .not('fcm_token', 'is', null)

      if (!profiles || profiles.length === 0) {
        return new Response(JSON.stringify({ message: 'No friends have FCM tokens' }), { status: 200 })
      }

      // 4. Send Notifications
      const promises = profiles.map((p: any) => {
        if (!p.fcm_token) return Promise.resolve(null);
        return sendFCM(
          p.fcm_token, 
          `Feed Baru!`, 
          `${creatorName} baru aja nge-feed, klik notif biar ga FOMO!`,
          { post_id: record.id, type: 'new_post' }
        )
      })

      await Promise.all(promises)
      
      return new Response(JSON.stringify({ message: `Sent ${promises.length} notifications (post)` }), { status: 200 })
    }
    // Notify Story/Post Owner
    else if (table === 'reactions') {
      const reactorId = record.user_id
      const storyId = record.story_id
      const postId = record.post_id // Added capture
      const reactionType = record.type // e.g., '❤️'
      
      console.log(`Processing Reaction: reactor=${reactorId}, story=${storyId}, post=${postId}, type=${reactionType}`)

      // CASE B.1: STORY REACTION
      if (storyId) {
        // 1. Fetch Story to find Owner
        const { data: story, error: storyError } = await supabaseAdmin
        .from('stories')
        .select('user_id')
        .eq('id', storyId)
        .single()
      
      if (storyError || !story) {
        console.error('Error fetching story:', storyError)
        console.error('Payload Story ID:', storyId)
        // Try to list recent stories to see available IDs? (optional, maybe too noisy)
        throw new Error(`Story not found for ID: ${storyId}. Error: ${JSON.stringify(storyError)}`)
      }

      const ownerId = story.user_id

      // Don't notify if reacting to own story (though UI hinders this)
      if (ownerId === reactorId) {
        console.log('Skipping self-reaction notification')
        return new Response(JSON.stringify({ message: 'Self-reaction ignored' }), { status: 200 })
      }

      // 2. Fetch Reactor Name
      const { data: reactor } = await supabaseAdmin
        .from('profiles')
        .select('username')
        .eq('id', reactorId)
        .single()
      
      const reactorName = reactor?.username || 'Someone'

      // 3. Fetch Owner Token
      const { data: owner } = await supabaseAdmin
        .from('profiles')
        .select('fcm_token')
        .eq('id', ownerId)
        .single()
      
      if (!owner?.fcm_token) {
        console.log(`Owner ${ownerId} has no FCM token`)
        return new Response(JSON.stringify({ message: 'Owner has no FCM token' }), { status: 200 })
      }

      // 4. Send Notification
      const result = await sendFCM(
        owner.fcm_token,
        'Strik!',
        `${reactorName} nge-react momentz lo: ${reactionType}`,
        { story_id: storyId, type: 'story_reaction' }
      )

      return new Response(JSON.stringify(result), { status: 200 })
      } 
      
      // CASE B.2: POST REACTION or OTHER
      else if (postId) {
        console.log('Skipping Post Reaction notification (not implemented yet)')
        return new Response(JSON.stringify({ message: 'Post reaction skipped' }), { status: 200 })
      } 
      
      else {
        console.log('Unknown reaction target')
         return new Response(JSON.stringify({ message: 'Unknown reaction target' }), { status: 200 })
      }
    }

    // DEFAULT / LEGACY HANDLER (Direct Call with recipient_id)
    // If payload has 'recipient_id', fall back to old logic? 
    // Or just assume this function is now exclusively for Webhooks?
    // Let's keep a small fallback for direct calls if 'record' has 'recipient_id' 
    // AND 'table' is undefined (Direct invocation)
    if (!table && record?.recipient_id) {
       // ... (Old Logic - condensed for brevity) ...
       // For now, let's just return to avoid complex fallback unless requested. 
       // The prompt specifically asked for Story notifications.
       // But wait, the friend request logic uses this too!
       // FriendRepository lines 23 and 51 call `sendNotification`.
       // Those calls likely do NOT send `table`. They send specific body.
       // So we MUST PRESERVE the `recipient_id` direct call logic.
       
       const userId = record.recipient_id
       console.log(`Direct Call for user ${userId}`)
       
       const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('fcm_token')
        .eq('id', userId)
        .single()

       if (profile?.fcm_token) {
          const result = await sendFCM(
            profile.fcm_token,
            record.title || "Strik!",
            record.body || "Notification",
            { ...record.data }
          )
          return new Response(JSON.stringify(result), { status: 200 })
       }
       return new Response(JSON.stringify({message: 'User no token'}), {status:200})
    }

    return new Response(JSON.stringify({ message: 'Unhandled event/payload' }), { status: 200 })

  } catch (error: any) {
    console.error('Edge Function Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})