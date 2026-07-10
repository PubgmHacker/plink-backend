// src/routes/realtime.ts — Realtime ticket endpoint (runbook §2)
//
// §2: 'JWT для WebSocket передавать через Sec-WebSocket-Protocol с
// короткоживущим ticket, не query string. Выпустить endpoint
// POST /api/realtime/ticket, TTL 60 секунд, одноразовый nonce.'
//
// Flow:
//   1. Client has a normal access JWT (Authorization: Bearer).
//   2. Before opening WS, client calls POST /api/realtime/ticket with
//      { roomId } in body.
//   3. Server verifies access JWT, confirms room membership, mints a
//      short-lived (60s) realtime ticket JWT with typ='realtime_ticket'.
//   4. Server stores a nonce in Redis (TTL 60s) so the ticket can be used
//      exactly once.
//   5. Client opens WS with Sec-WebSocket-Protocol: plink.v2, plink.ticket.<jwt>
//   6. Gateway verifies ticket + deletes nonce (single-use).

import type { FastifyPluginAsync } from 'fastify';
import { randomUUID } from 'node:crypto';
import { config } from '../config/index.js';
import { redis } from '../config/redis.js';
import { prisma } from '../config/db.js';

export const realtimeTicketRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.post('/realtime/ticket', {
    preHandler: [(fastify as any).authenticate],
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
  }, async (request: any, reply: any) => {
    const userId = request.user.id;
    const { roomId } = request.body ?? {};
    if (!roomId || typeof roomId !== 'string') {
      return reply.status(400).send({ error: 'roomId required' });
    }

    // Membership check
    let isMember = false;
    try {
      const p = await prisma.roomParticipant.findUnique({
        where: { roomID_userID: { roomID: roomId, userID: userId } },
        select: { id: true },
      });
      isMember = p !== null;
    } catch {
      const p = await prisma.roomParticipant.findFirst({
        where: { roomID: roomId, userID: userId },
        select: { id: true },
      });
      isMember = p !== null;
    }
    if (!isMember) {
      return reply.status(403).send({ error: 'Not a room member' });
    }

    const nonce = randomUUID();
    const ticket = fastify.jwt.sign(
      {
        id: userId,
        username: request.user.username,
        role: request.user.role,
        roomId,
        nonce,
        typ: 'realtime_ticket',
      },
      { expiresIn: `${config.REALTIME_TICKET_TTL_SEC}s` },
    );

    // Single-use nonce: store in Redis with same TTL.
    // Gateway will DEL on first use — second attempt fails.
    if (redis) {
      await redis.set(
        `plink:ticket:${userId}:${nonce.slice(-12)}`,
        '1',
        'EX',
        config.REALTIME_TICKET_TTL_SEC,
      );
    }

    return reply.send({
      ticket,
      expiresInSec: config.REALTIME_TICKET_TTL_SEC,
      protocol: ['plink.v2', `plink.ticket.${ticket}`],
    });
  });
};
