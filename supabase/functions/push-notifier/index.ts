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

serve(async (req: Request) => {
  try {
    const payload = await req.json()
    const record = payload.record
    const userId = record.recipient_id // Column name in DB is recipient_id, not user_id

    console.log(`Processing notification for user ${userId}`)

    // 1. Get User's FCM Token from Supabase
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('fcm_token')
      .eq('id', userId)
      .single()

    console.log(`Found token for user ${userId}: ${profile.fcm_token.substring(0, 10)}...`)

    if (!profile?.fcm_token) {
      console.log(`Skipping: User ${userId} has no FCM token.`)
      return new Response(JSON.stringify({ message: 'No FCM token' }), { status: 200 })
    }

    console.log(`Found token for user ${userId}: ${profile.fcm_token.substring(0, 10)}...`)

    // 2. Generate Google OAuth2 Access Token
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

    // 3. Send Notification via FCM V1 API
    const projectId = FIREBASE_SERVICE_ACCOUNT.project_id
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: profile.fcm_token,
            notification: {
              title: record.title || "Strik!",
              body: record.body || "Ada sesuatu nih buat kamu!",
            },
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              post_id: record.post_id || "",
              habit_log_id: record.habit_log_id || "",
            },
          },
        }),
      }
    )

    const fcmResult = await fcmResponse.json()
    console.log('FCM Send Result:', fcmResult)

    return new Response(JSON.stringify(fcmResult), {
      headers: { "Content-Type": "application/json" },
      status: 200 
    })

  } catch (error: any) {
    console.error('Edge Function Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})