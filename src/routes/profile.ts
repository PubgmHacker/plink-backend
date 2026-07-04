import { prisma } from '../config/db.js';

export default async function profileRoutes(fastify) {
  fastify.get('/users/me', { preHandler: [fastify.authenticate] }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { id: true, username: true, email: true, avatarURL: true, isPremium: true, premiumUntil: true, role: true, createdAt: true }
    });
    reply.send(user);
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
