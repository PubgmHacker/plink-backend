// src/types/fastify.d.ts — Fastify module augmentation for Protocol v2
//
// Canonical P0: declares the decorators wired in src/index.ts so the rest
// of the codebase gets type-checking on `fastify.redis`, `fastify.user`,
// `fastify.roomEvents`, `fastify.relayTickets`, and `fastify.prisma`.
//
// tsconfig.json `"include": ["src/**/*"]` already pulls in .d.ts files
// under src/ — no tsconfig change needed.
import 'fastify';
import type Redis from 'ioredis';
import type { PrismaClient } from '@prisma/client';
import type { RoomEventService } from '../services/roomEventService.js';
import type { RelayTicketService } from '../services/relayTicketService.js';

interface AppUser {
  id: string;
  username: string;
  email?: string;
  role: string;
}

declare module 'fastify' {
  interface FastifyInstance {
    prisma: PrismaClient;
    redis: Redis;
    roomEvents: RoomEventService;
    relayTickets: RelayTicketService;
  }

  interface FastifyRequest {
    user: AppUser;
  }
}
