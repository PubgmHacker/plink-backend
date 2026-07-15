import { prisma } from '../config/db.js';

export default async function profileRoutes(fastify) {
  // P0: POST /users/me/avatar — save base64 directly to DB as avatarData (no filesystem)
  // This solves Railway /tmp and ephemeral storage issues. No files, no volumes needed.
  fastify.post('/users/me/avatar', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { avatar } = request.body;

    if (!avatar || typeof avatar !== 'string') {
      return reply.status(400).send({ error: 'Avatar data required' });
    }

    // Store the full base64 string (including prefix) or stripped — we store as-is for simplicity
    // iOS will handle decoding. Limit size to avoid DB bloat (e.g. ~100KB per avatar)
    const avatarData = avatar;

    await prisma.user.update({
      where: { id: request.user.id },
      data: { avatarData }
    });

    reply.send({ avatarData });
  });
  fastify.get('/users/me', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { id: true, username: true, email: true, avatarURL: true, avatarData: true, isPremium: true, premiumUntil: true, role: true, createdAt: true }
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
