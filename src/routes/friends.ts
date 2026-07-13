import { prisma } from '../config/db.js';
import { sendPushToUser, PushTemplates } from '../services/pushService.js';

export default async function friendRoutes(fastify) {
  fastify.get('/friends', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const friendships = await prisma.friendship.findMany({
      where: { userID: request.user.id },
      include: { friend: { select: { id: true, username: true, avatarURL: true, isOnline: true } } }
    });
    reply.send(friendships.map(f => ({
      id: f.friend.id, username: f.friend.username,
      avatarURL: f.friend.avatarURL, isOnline: f.friend.isOnline,
      friendsSince: f.friendsSince
    })));
  });

  fastify.get('/friends/requests/incoming', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const requests = await prisma.friendRequest.findMany({
      where: { toUserID: request.user.id, status: 'pending' },
      include: { fromUser: { select: { id: true, username: true, avatarURL: true, isOnline: true } } }
    });
    reply.send(requests.map(r => ({
      id: r.id, fromUser: r.fromUser, status: r.status, createdAt: r.createdAt
    })));
  });

  fastify.post('/friends/request', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { friendId } = request.body;
    if (friendId === request.user.id) return reply.status(400).send({ error: 'Cannot friend yourself' });

    const existing = await prisma.friendRequest.findFirst({
      where: { OR: [
        { fromUserID: request.user.id, toUserID: friendId },
        { fromUserID: friendId, toUserID: request.user.id }
      ]}
    });
    if (existing) return reply.status(409).send({ error: 'Request already exists' });

    const req = await prisma.friendRequest.create({
      data: { fromUserID: request.user.id, toUserID: friendId }
    });

    // AUDIT: fetch sender username for push notification
    const sender = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { username: true }
    });

    // AUDIT Block 3.2/3.3: Send push notification to recipient
    if (sender) {
      const pushPayload = PushTemplates.friendRequest(sender.username);
      sendPushToUser(friendId, pushPayload).catch(() => {});
    }

    // AUDIT Block 3.2: Send WebSocket event to recipient if online
    try {
      fastify.io?.to(`user:${friendId}`).emit('friend.request', {
        fromUserId: request.user.id,
        fromUsername: sender?.username || 'Unknown',
        requestId: req.id,
        timestamp: new Date().toISOString()
      });
    } catch (e) {
      // WS delivery is best-effort
    }

    reply.send(req);
  });

  fastify.put('/friends/requests/:id', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { id } = request.params;
    const { status } = request.body;

    const req = await prisma.friendRequest.findUnique({ where: { id } });
    if (!req || req.toUserID !== request.user.id) {
      return reply.status(404).send({ error: 'Request not found' });
    }

    await prisma.friendRequest.update({ where: { id }, data: { status } });

    if (status === 'accepted') {
      await prisma.friendship.create({ data: { userID: req.fromUserID, friendID: req.toUserID } });
      await prisma.friendship.create({ data: { userID: req.toUserID, friendID: req.fromUserID } });

      // AUDIT Block 3.2/3.3: Notify sender that request was accepted
      const accepter = await prisma.user.findUnique({
        where: { id: request.user.id },
        select: { username: true }
      });

      if (accepter) {
        const pushPayload = PushTemplates.friendAccepted(accepter.username);
        sendPushToUser(req.fromUserID, pushPayload).catch(() => {});
      }

      // WebSocket event to sender
      try {
        fastify.io?.to(`user:${req.fromUserID}`).emit('friend.accepted', {
          byUserId: request.user.id,
          byUsername: accepter?.username || 'Unknown',
          timestamp: new Date().toISOString()
        });
      } catch (e) {}
    }

    reply.send({ success: true });
  });

  fastify.delete('/friends/:friendId', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { friendId } = request.params;
    await prisma.friendship.deleteMany({
      where: { OR: [
        { userID: request.user.id, friendID: friendId },
        { userID: friendId, friendID: request.user.id }
      ]}
    });
    reply.send({ success: true });
  });

  fastify.get('/friends/search', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const { q } = request.query;
    if (!q || q.length < 1) return reply.send([]);

    const users = await prisma.user.findMany({
      where: {
        AND: [
          { id: { not: request.user.id } },
          { OR: [
            { username: { contains: q, mode: 'insensitive' } },
            { id: { contains: q, mode: 'insensitive' } }
          ]}
        ]
      },
      select: { id: true, username: true, avatarURL: true, isOnline: true },
      take: 20,
    });
    reply.send(users);
  });
}
