import { prisma } from '../config/db.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { logAudit, AuditActions } from '../utils/audit.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default async function profileRoutes(fastify) {
  // 🔧 NEW: POST /users/me/avatar — upload avatar as base64, save to disk,
  // return public URL. Stored in /uploads/avatars/USER_ID.jpg.
  fastify.post('/users/me/avatar', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { avatar } = request.body;

    if (!avatar || typeof avatar !== 'string') {
      return reply.status(400).send({ error: 'Avatar data required' });
    }

    // Remove data:image/jpeg;base64, prefix if present
    const base64Data = avatar.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    // Create uploads directory if it doesn't exist
    const uploadsDir = path.join(__dirname, '..', '..', 'uploads', 'avatars');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    // Save as USER_ID.jpg
    const filename = `${request.user.id}.jpg`;
    const filepath = path.join(uploadsDir, filename);
    fs.writeFileSync(filepath, buffer);

    // Public URL — served by Fastify static plugin or Railway
    const avatarURL = `https://plink-backend-production-ef31.up.railway.app/uploads/avatars/${filename}`;

    // Update user in DB
    await prisma.user.update({
      where: { id: request.user.id },
      data: { avatarURL }
    });

    reply.send({ avatarURL });
  });

  // Serve uploaded files
  fastify.get('/uploads/*', async (request, reply) => {
    const filePath = path.join(__dirname, '..', '..', request.url);
    if (fs.existsSync(filePath)) {
      reply.type('image/jpeg').send(fs.createReadStream(filePath));
    } else {
      reply.status(404).send({ error: 'File not found' });
    }
  });
  fastify.get('/users/me', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { id: true, username: true, email: true, avatarURL: true, isPremium: true, premiumUntil: true, role: true, createdAt: true }
    });
    reply.send(user);
  });

  // 🔧 Pack v3: PATCH /users/me — обновление username + avatarURL + displayName + coverURL
  // 🔧 v11 (July 2026): added displayName + coverURL (Telegram-style naming split).
  fastify.patch('/users/me', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { username, avatarURL, displayName, coverURL } = request.body;
    const data: any = {};
    if (username && username.trim().length >= 2) data.username = username.trim();
    if (avatarURL !== undefined) data.avatarURL = avatarURL;
    // 🔧 v11: displayName — optional Telegram-style display name (1-50 chars).
    // Empty string clears it (user wants to fall back to @username).
    if (displayName !== undefined) {
      const trimmed = String(displayName).trim();
      if (trimmed.length === 0) {
        data.displayName = null;  // clear → backend uses username as display
      } else if (trimmed.length <= 50) {
        data.displayName = trimmed;
      }
    }
    if (coverURL !== undefined) data.coverURL = coverURL;

    if (Object.keys(data).length === 0) {
      return reply.status(400).send({ error: 'No fields to update' });
    }

    // Проверка уникальности username
    if (data.username) {
      const existing = await prisma.user.findFirst({
        where: { username: data.username, NOT: { id: request.user.id } }
      });
      if (existing) return reply.status(409).send({ error: 'Username already taken' });
    }

    const updated = await prisma.user.update({
      where: { id: request.user.id },
      data,
      select: { id: true, username: true, email: true, avatarURL: true,
                displayName: true, coverURL: true,
                isPremium: true, premiumUntil: true, role: true, createdAt: true }
    });
    reply.send(updated);
  });

  // 🔧 Pack v3: DELETE /users/me — полное удаление аккаунта (cascade)
  fastify.delete('/users/me', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    try {
      // Cascade delete через Prisma — все связанные записи удалятся автоматически
      // (Room, RoomParticipant, ChatMessage, DirectMessage, FriendRequest, Friendship,
      //  WatchHistory, PlaybackState, Subscription, UserBlock, Report, RefreshToken, AuditLog)
      await prisma.user.delete({ where: { id: request.user.id } });
      reply.send({ deleted: true });
    } catch (e: any) {
      reply.status(500).send({ error: 'Failed to delete account: ' + (e?.message || String(e)) });
    }
  });

  // ─────────────────────────────────────────────────────────────────────
  // V5 endpoints (Phase 4 of PLINK_MASTER_PLAN_10_OF_10.md)
  // ─────────────────────────────────────────────────────────────────────

  // GET /api/profile/appearance
  // Phase 4: returns the user's saved appearance selection (cross-device restore).
  // Values are stored as JSON on the User row in `appearancePrefs`.
  fastify.get('/profile/appearance', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { appearancePrefs: true }
    });

    // Defaults if user has never selected anything.
    const defaults = {
      appThemeID: 'electric-static',
      bubbleStyleID: 'bubble-quiet',
      emojiPackID: 'system-unicode'
    };

    if (!user?.appearancePrefs) {
      return reply.send(defaults);
    }
    try {
      const parsed = JSON.parse(user.appearancePrefs);
      reply.send({
        appThemeID: parsed.appThemeID ?? defaults.appThemeID,
        bubbleStyleID: parsed.bubbleStyleID ?? defaults.bubbleStyleID,
        emojiPackID: parsed.emojiPackID ?? defaults.emojiPackID
      });
    } catch {
      reply.send(defaults);
    }
  });

  // PUT /api/profile/appearance
  // Phase 4: persists the user's appearance selection for cross-device restore.
  fastify.put('/profile/appearance', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { appThemeID, bubbleStyleID, emojiPackID } = request.body;

    if (typeof appThemeID !== 'string' ||
        typeof bubbleStyleID !== 'string' ||
        typeof emojiPackID !== 'string') {
      return reply.status(400).send({ error: 'appThemeID, bubbleStyleID, emojiPackID required' });
    }

    const prefs = JSON.stringify({ appThemeID, bubbleStyleID, emojiPackID });

    await prisma.user.update({
      where: { id: request.user.id },
      data: { appearancePrefs: prefs }
    });

    await logAudit({
      userId: request.user.id,
      action: AuditActions.PROFILE_APPEARANCE_UPDATE,
      ip: request.ip,
      metadata: { appThemeID, bubbleStyleID, emojiPackID }
    });

    reply.status(204).send();
  });

  // POST /api/profile/delete
  // Phase 2.7: scheduled account deletion with grace period (14 days).
  // Marks the user as `scheduledForDeletionAt = now + 14d`; a cron job
  // (see services/gdpr.ts) performs the actual cascade delete after the
  // grace period expires. User can cancel by signing in before then.
  fastify.post('/profile/delete', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { confirmAccountId, reason } = request.body;

    if (confirmAccountId !== request.user.id) {
      return reply.status(400).send({
        error: 'Account ID confirmation does not match'
      });
    }

    const scheduledForDeletionAt = new Date();
    scheduledForDeletionAt.setDate(scheduledForDeletionAt.getDate() + 14);

    await prisma.user.update({
      where: { id: request.user.id },
      data: { scheduledForDeletionAt }
    });

    // Revoke all refresh tokens immediately — keeps access token valid until
    // expiry (max 24h) but blocks long-lived session extension.
    // (Import happens lazily to avoid circular import with tokens.js.)
    const { revokeAllUserTokens } = await import('../utils/tokens.js');
    await revokeAllUserTokens(request.user.id);

    await logAudit({
      userId: request.user.id,
      action: AuditActions.ACCOUNT_DELETION_REQUESTED,
      ip: request.ip,
      metadata: { reason: reason ?? 'user_initiated', scheduledForDeletionAt }
    });

    reply.send({
      scheduledForDeletionAt,
      message: 'Account scheduled for deletion in 14 days. Sign in before then to cancel.'
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // /users/me endpoints (existing)
  // ─────────────────────────────────────────────────────────────────────

  fastify.get('/users/:id', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { id } = request.params;
    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, username: true, avatarURL: true, isOnline: true }
    });
    if (!user) return reply.status(404).send({ error: 'User not found' });
    reply.send(user);
  });

  fastify.post('/users/me/create-subscription', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { plan } = request.body;
    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + 1);

    await prisma.user.update({
      where: { id: request.user.id },
      data: { isPremium: true, premiumUntil: expiresAt }
    });
    await prisma.subscription.create({
      data: { userID: request.user.id, plan: plan || 'monthly', expiresAt }
    });
    reply.send({ success: true, expiresAt });
  });

  fastify.get('/users/me/history', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const history = await prisma.watchHistory.findMany({
      where: { userID: request.user.id },
      orderBy: { watchedAt: 'desc' },
      take: 50,
    });
    reply.send(history);
  });
}
