// src/services/push.ts — P0 Push notifications sender (APNs + stub FCM)
// Supports iOS via APNs provider token auth (no certs needed).
// Requires env:
//   APNS_KEY         — contents of AuthKey_*.p8 (or base64)
//   APNS_KEY_ID
//   APNS_TEAM_ID
//   APNS_BUNDLE_ID   — com.syncwatch.plink
//   APNS_PRODUCTION  — "true" for prod, else sandbox
//
// If no creds configured, sendPush just logs (useful for dev/testing).

import * as https from 'https';
import { importPKCS8, SignJWT } from 'jose';

let cachedKey: any = null;
let cachedKid = '';
let tokenCache: { jwt: string; exp: number } | null = null;

const APNS_HOST = process.env.APNS_PRODUCTION === 'true'
  ? 'api.push.apple.com'
  : 'api.sandbox.push.apple.com';

const BUNDLE_ID = process.env.APNS_BUNDLE_ID || 'com.syncwatch.plink';

interface PushPayload {
  title?: string;
  body?: string;
  data?: Record<string, any>;
  sound?: string;
}

export async function sendPush(apnsToken: string, payload: PushPayload): Promise<boolean> {
  if (!apnsToken) return false;

  const keyPem = process.env.APNS_KEY;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;

  if (!keyPem || !keyId || !teamId) {
    console.log('[push] APNs not configured (missing APNS_* env). Logging instead:', {
      token: apnsToken.slice(0, 16) + '...',
      payload,
    });
    return true; // treat as "sent" for dev
  }

  try {
    const jwt = await getAPNsJWT(keyPem, keyId, teamId);

    const body = JSON.stringify({
      aps: {
        alert: payload.title ? { title: payload.title, body: payload.body } : (payload.body || 'Plink'),
        sound: payload.sound || 'default',
        'content-available': 1,
      },
      ... (payload.data || {}),
    });

    const options: https.RequestOptions = {
      hostname: APNS_HOST,
      port: 443,
      path: `/3/device/${apnsToken}`,
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0',
        'content-type': 'application/json',
      },
    };

    return await new Promise((resolve) => {
      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => {
          if (res.statusCode === 200) {
            console.log('[push] APNs sent OK to', apnsToken.slice(0, 12));
            resolve(true);
          } else {
            console.error('[push] APNs error', res.statusCode, data);
            resolve(false);
          }
        });
      });
      req.on('error', (e) => {
        console.error('[push] APNs request error', e.message);
        resolve(false);
      });
      req.write(body);
      req.end();
    });
  } catch (e: any) {
    console.error('[push] APNs send failed:', e?.message || e);
    return false;
  }
}

async function getAPNsJWT(keyPem: string, keyId: string, teamId: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (tokenCache && tokenCache.exp > now + 60) {
    return tokenCache.jwt;
  }

  if (!cachedKey || cachedKid !== keyId) {
    // p8 is PKCS8 EC
    const pem = keyPem.includes('BEGIN') ? keyPem : `-----BEGIN PRIVATE KEY-----\n${keyPem}\n-----END PRIVATE KEY-----`;
    cachedKey = await importPKCS8(pem, 'ES256');
    cachedKid = keyId;
  }

  const jwt = await new SignJWT({ })
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600) // 1h max
    .sign(cachedKey);

  tokenCache = { jwt, exp: now + 3600 };
  return jwt;
}

// Convenience for inviting / room events
export async function notifyRoomInvite(apnsToken: string, inviter: string, roomCode: string, roomName?: string) {
  return sendPush(apnsToken, {
    title: 'Приглашение в Plink',
    body: `${inviter} приглашает посмотреть вместе в комнате ${roomName || roomCode}`,
    data: {
      type: 'room_invite',
      roomCode,
      deepLink: `plink://room/${roomCode}`,
    },
  });
}

export async function notifyNewMessage(apnsToken: string, sender: string, text: string, roomCode?: string) {
  return sendPush(apnsToken, {
    title: sender,
    body: text.length > 80 ? text.slice(0, 77) + '...' : text,
    data: {
      type: 'chat',
      roomCode,
      deepLink: roomCode ? `plink://room/${roomCode}` : undefined,
    },
  });
}
