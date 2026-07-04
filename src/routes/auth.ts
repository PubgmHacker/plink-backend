import bcrypt from 'bcrypt';
import { prisma } from '../config/db.js';

export default async function authRoutes(fastify) {

  // POST /api/auth/signup
  fastify.post('/auth/signup', async (request, reply) => {
    const { email, password, username } = request.body;
    if (!email || !password || !username) {
      return reply.status(400).send({ error: 'Missing fields' });
    }
    const existing = await prisma.user.findFirst({
      where: { OR: [{ email }, { username }] }
    });
    if (existing) return reply.status(409).send({ error: 'Email or username taken' });

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { email, username, password: hashedPassword, isOnline: true }
    });

    const token = fastify.jwt.sign(
      { id: user.id, username: user.username, email: user.email, role: user.role },
      { expiresIn: '7d' }
    );

    const { password: _, ...userWithoutPassword } = user;
    reply.send({ token, user: userWithoutPassword, refreshToken: null });
  });

  // POST /api/auth/signin
  fastify.post('/auth/signin', async (request, reply) => {
    const { email, password } = request.body;
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return reply.status(401).send({ error: 'Invalid credentials' });

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return reply.status(401).send({ error: 'Invalid credentials' });

    if (user.bannedUntil && user.bannedUntil > new Date()) {
      return reply.status(403).send({ error: 'Account banned' });
    }

    await prisma.user.update({ where: { id: user.id }, data: { isOnline: true } });

    const token = fastify.jwt.sign(
      { id: user.id, username: user.username, email: user.email, role: user.role },
      { expiresIn: '7d' }
    );

    const { password: _, ...userWithoutPassword } = user;
    reply.send({ token, user: userWithoutPassword, refreshToken: null });
  });

  // POST /api/auth/fcm-token
  fastify.post('/auth/fcm-token', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { token: fcmToken } = request.body;
    await prisma.user.update({
      where: { id: request.user.id },
      data: { fcmToken }
    });
    reply.send({ success: true });
  });

  // POST /api/auth/refresh
  fastify.post('/auth/refresh', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { id: true, username: true, email: true, role: true, isPremium: true }
    });
    if (!user) return reply.status(401).send({ error: 'User not found' });

    const token = fastify.jwt.sign(
      { id: user.id, username: user.username, email: user.email, role: user.role },
      { expiresIn: '7d' }
    );
    reply.send({ token, user, refreshToken: null });
  });
}
