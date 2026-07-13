// src/services/pushService.ts — APNs push notification sender
// AUDIT Block 3.3: OS-level push notifications via Apple Push Notification service.
import { prisma } from '../config/db.js';

// APNs configuration — uses .p8 key file (recommended over certificates)
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APNS_TEAM_ID = process.env.APNS_TEAM_ID;
// start.sh writes the key from APNS_KEY_CONTENT env var to /app/AuthKey.p8
const APNS_KEY_PATH = process.env.APNS_KEY_PATH || '/app/AuthKey.p8';
const APNS_KEY_CONTENT = process.env.APNS_KEY_CONTENT;  // raw .p8 content as env var
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID || 'com.syncwatch.plink';
const APNS_PRODUCTION = process.env.APNS_PRODUCTION !== 'false';

interface PushPayload {
  alert: { title: string; body: string };
  badge?: number;
  sound?: string;
  'mutable-content'?: number;
  data?: Record<string, any>;
}

/**
 * Send push notification to a specific user via APNs.
 * Fetches user's deviceToken from DB, sends via Apple's APNs HTTP/2 API.
 */
export async function sendPushToUser(userId: string, payload: PushPayload): Promise<boolean> {
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { deviceToken: true, devicePlatform: true }
    });

    if (!user?.deviceToken) {
      return false;  // No device token registered
    }

    if (user.devicePlatform === 'ios') {
      return await sendViaAPNs(user.deviceToken, payload);
    } else if (user.devicePlatform === 'android' && user.deviceToken) {
      // FCM for Android (future) — TODO when Android ships
      return false;
    }

    return false;
  } catch (e) {
    console.error('[pushService] sendPushToUser error:', e);
    return false;
  }
}

/**
 * Send push to multiple users (e.g., all room participants).
 */
export async function sendPushToUsers(userIds: string[], payload: PushPayload): Promise<void> {
  const tasks = userIds.map(id => sendPushToUser(id, payload));
  await Promise.allSettled(tasks);
}

/**
 * Send via APNs HTTP/2 API using native fetch (Node 18+).
 * Uses JWT authentication with .p8 key.
 */
async function sendViaAPNs(deviceToken: string, payload: PushPayload): Promise<boolean> {
  if (!APNS_KEY_ID || !APNS_TEAM_ID) {
    console.warn('[pushService] APNs not configured. Need APNS_KEY_ID + APNS_TEAM_ID + APNS_KEY_CONTENT.');
    return false;
  }

  try {
    // Get key data — either from env var (APNS_KEY_CONTENT) or from file (APNS_KEY_PATH)
    let keyData: string;
    if (APNS_KEY_CONTENT) {
      // Key content stored directly in env var (Railway-friendly)
      keyData = APNS_KEY_CONTENT.includes('-----BEGIN PRIVATE KEY-----')
        ? APNS_KEY_CONTENT
        : `-----BEGIN PRIVATE KEY-----\n${APNS_KEY_CONTENT}\n-----END PRIVATE KEY-----`;
    } else {
      // Try reading from file (written by start.sh)
      const fs = await import('fs');
      try {
        keyData = fs.readFileSync(APNS_KEY_PATH, 'utf8');
      } catch {
        console.warn(`[pushService] APNs key file not found at ${APNS_KEY_PATH} and APNS_KEY_CONTENT not set.`);
        return false;
      }
    }

    const { SignJWT, importPKCS8 } = await import('jose');
    const privateKey = await importPKCS8(keyData, 'ES256');

    // Generate JWT for APNs auth
    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: APNS_KEY_ID, typ: 'JWT' })
      .setIssuer(APNS_TEAM_ID)
      .setIssuedAt()
      .sign(privateKey);

    // Build APNs payload
    const apnsPayload = {
      aps: {
        alert: payload.alert,
        badge: payload.badge ?? 1,
        sound: payload.sound ?? 'default',
        'mutable-content': payload['mutable-content'] ?? 0,
      },
      ...(payload.data || {})
    };

    const host = APNS_PRODUCTION ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com';
    const url = `${host}/3/device/${deviceToken}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': APNS_BUNDLE_ID,
        'apns-priority': '10',  // high priority for room invites
        'content-type': 'application/json',
      },
      body: JSON.stringify(apnsPayload),
    });

    if (response.ok) {
      return true;
    } else {
      const errText = await response.text();
      console.error('[pushService] APNs error:', response.status, errText);
      // If token is invalid, clear it
      if (response.status === 410 || response.status === 403) {
        await prisma.user.updateMany({
          where: { deviceToken },
          data: { deviceToken: null }
        }).catch(() => {});
      }
      return false;
    }
  } catch (e) {
    console.error('[pushService] APNs send failed:', e);
    return false;
  }
}

/**
 * Push notification templates for common events.
 */
export const PushTemplates = {
  roomInvite: (inviterName: string, roomName: string, roomCode: string) => ({
    alert: { title: `${inviterName} зовёт смотреть`, body: `${roomName} · присоединиться?` },
    data: { type: 'room_invite', roomCode, deepLink: `plink://room/${roomCode}` }
  }),

  friendRequest: (senderName: string) => ({
    alert: { title: 'Новая заявка в друзья', body: `${senderName} хочет добавить вас` },
    data: { type: 'friend_request', deepLink: 'plink://friends/requests' }
  }),

  friendAccepted: (accepterName: string) => ({
    alert: { title: 'Заявка принята', body: `${accepterName} теперь ваш друг` },
    data: { type: 'friend_accepted', deepLink: 'plink://profile' }
  }),

  roomStarting: (roomName: string, roomCode: string) => ({
    alert: { title: '🎬 Комната начинается', body: `${roomName} стартует через 5 минут` },
    data: { type: 'room_starting', roomCode, deepLink: `plink://room/${roomCode}` }
  }),
};
