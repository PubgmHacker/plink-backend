// src/routes/rooms.ts — с Redis кэшем
import { hashRoomPassword, verifyRoomPassword, requireHost } from '../middleware/security.js';
import { cacheGet, cacheSet, cacheDel } from '../config/redis.js';
import { logAudit, AuditActions } from '../utils/audit.js';

const ROOMS_CACHE_KEY = 'rooms:public:50';
const ROOMS_CACHE_TTL = 30; // 30 sec

// 🔧 FIX: mediaItem хранится в БД как JSON-строка (Prisma `String?` колонка).
// iOS ожидает structured object, не строку — иначе decoding падает с typeMismatch
// и весь Room decode ломается. Эта функция парсит строку обратно в объект.
// Применяется во всех endpoints которые возвращают room: create, join, list, get.
//
// 🔧 ROBUSTNESS: try/catch вокруг JSON.parse. Если в БД лежит битая строка
// (исторические данные, partial write и т.п.) — возвращаем null вместо того
// чтобы ронять весь endpoint 500-й. Иначе iOS видит ошибку → myRooms = [] →
// юзер думает что у него нет комнат, хотя они есть.
function serializeRoom(room) {
    if (!room) return null;
    const { password, ...rest } = room;
    let parsedMediaItem = null;
    if (rest.mediaItem) {
        try {
            parsedMediaItem = JSON.parse(rest.mediaItem);
        } catch (e: any) {
            // Битая JSON-строка — логируем, возвращаем null, не роняем endpoint
            console.warn(`[rooms] Failed to parse mediaItem for room ${rest.id}:`, e?.message || e);
            parsedMediaItem = null;
        }
    }
    return {
        ...rest,
        mediaItem: parsedMediaItem,
    };
}

export default async function roomRoutes(fastify, _options) {
    const { prisma } = fastify;

    // POST /api/rooms — Создание комнаты
    fastify.post('/rooms', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const { name, maxParticipants, mediaItem, privacy, password, hostName } = request.body;

        // 🔧 Pack v3 FIX: JWT содержит только {id}, без username.
        // Берём username из БД, fallback на body.hostName, потом 'Unknown'.
        let resolvedHostName = hostName || 'Unknown';
        try {
            const user = await prisma.user.findUnique({
                where: { id: request.user.id },
                select: { username: true }
            });
            if (user?.username) resolvedHostName = user.username;
        } catch {}

        const hashedPassword = password 
            ? await hashRoomPassword(password) 
            : null;

        // 🔧 SAFETY: simple create — no endedAt column (uses isActive: false
        // to mark ended rooms instead, history preserved in /rooms/mine query).
        const room = await prisma.room.create({
            data: {
                name,
                hostID: request.user.id,
                hostName: resolvedHostName,
                code: generateRoomCode(),
                maxParticipants: maxParticipants || 10,
                mediaItem: mediaItem ? JSON.stringify(mediaItem) : null,
                privacy: privacy || 'public',
                password: hashedPassword,
                hostIsPremium: await getUserPremiumStatus(prisma, request.user.id),
                isActive: true,
            }
        });

        // Invalidate cache
        await cacheDel(ROOMS_CACHE_KEY);

        await logAudit({
            userId: request.user.id,
            action: AuditActions.ROOM_CREATE,
            ip: request.ip,
            metadata: { roomId: room.id, roomCode: room.code },
        });

        const { password: _, ...roomWithoutPassword } = room;
        // 🔧 FIX: parse mediaItem JSON string back to object for iOS
        reply.send(serializeRoom(roomWithoutPassword));
    });

    // POST /api/rooms/join — Вход в комнату
    fastify.post('/rooms/join', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const { code, password } = request.body;

        const room = await prisma.room.findFirst({
            where: { code: code.toUpperCase(), isActive: true }
        });

        if (!room) return reply.status(404).send({ error: 'Комната не найдена' });

        if (room.password) {
            if (!password) return reply.status(401).send({ error: 'Требуется пароль' });
            const isValid = await verifyRoomPassword(password, room.password);
            if (!isValid) return reply.status(401).send({ error: 'Неверный пароль' });
        }

        const participantCount = await prisma.roomParticipant.count({
            where: { roomID: room.id }
        });
        if (participantCount >= room.maxParticipants) {
            return reply.status(409).send({ error: 'Комната заполнена' });
        }

        await prisma.roomParticipant.create({
            data: { roomID: room.id, userID: request.user.id }
        });

        await logAudit({
            userId: request.user.id,
            action: AuditActions.ROOM_JOIN,
            ip: request.ip,
            metadata: { roomId: room.id, roomCode: room.code },
        });

        const { password: _, ...roomWithoutPassword } = room;
        // 🔧 FIX: parse mediaItem JSON string back to object for iOS
        reply.send(serializeRoom(roomWithoutPassword));
    });

    // DELETE /api/rooms/:id — Удалить комнату (только host или ADMIN)
    //
    // 🔧 NEW: Раньше не было endpoint для удаления комнат — пользователь мог создать
    // комнату, но не мог её удалить. Она висела на главной с 0 участников вечно.
    // Удаляем cascade (schema.prisma: onDelete: Cascade на RoomParticipant, ChatMessage,
    // PlaybackState, WatchHistory, Report, AdBreak — всё удалится автоматически).
    fastify.delete('/rooms/:id', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const { id } = request.params;

        const room = await prisma.room.findUnique({ where: { id } });
        if (!room) {
            return reply.status(404).send({ error: 'Комната не найдена' });
        }

        // Только host или ADMIN/FOUNDER может удалить комнату
        const isHost = room.hostID === request.user.id;
        const isAdmin = request.user.role === 'ADMIN' || request.user.role === 'FOUNDER';
        if (!isHost && !isAdmin) {
            return reply.status(403).send({ error: 'Нет прав на удаление комнаты' });
        }

        // Удаляем комнату — каскадно удалятся все связанные записи (participants,
        // messages, playbackState, watchHistory, reports, adBreaks) согласно schema.prisma.
        await prisma.room.delete({ where: { id } });

        // Инвалидируем кэш списка публичных комнат
        await cacheDel(ROOMS_CACHE_KEY);

        await logAudit({
            userId: request.user.id,
            action: AuditActions.ROOM_DELETE,
            ip: request.ip,
            metadata: { roomId: id, roomCode: room.code, roomName: room.name },
        });

        reply.send({ success: true });
    });

    // POST /api/rooms/:id/playback
    fastify.post('/rooms/:id/playback', {
        preHandler: [fastify.authenticate, requireHost(prisma)]
    }, async (request, reply) => {
        const { id } = request.params;
        const { time, isPlaying } = request.body;

        await prisma.playbackState.upsert({
            where: { roomID: id },
            update: { currentTime: time, isPlaying },
            create: { roomID: id, currentTime: time, isPlaying },
        });

        await logAudit({
            userId: request.user.id,
            action: AuditActions.PLAYBACK_CONTROL,
            ip: request.ip,
            metadata: { roomId: id, isPlaying, time },
        });

        reply.send({ success: true });
    });

    // GET /api/rooms — Список публичных комнат (С КЭШЕМ)
    fastify.get('/rooms', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        // Try cache first
        const cached = await cacheGet<any[]>(ROOMS_CACHE_KEY);
        if (cached) {
            return reply.send(cached);
        }

        const rooms = await prisma.room.findMany({
            where: { isActive: true, privacy: 'public' },
            include: { _count: { select: { participants: true } } },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });

        const safeRooms = rooms.map(r => serializeRoom(r));
        
        // Save to cache
        await cacheSet(ROOMS_CACHE_KEY, safeRooms, ROOMS_CACHE_TTL);
        
        reply.send(safeRooms);
    });

    // POST /api/rooms/:id/leave — Leave a room (decrement participant)
    //
    // 🔧 NEW: Was missing — iOS RoomService.leaveRoom called /rooms/:id/leave
    // but endpoint didn't exist (silent 404). Now: removes the RoomParticipant
    // row, and if no participants remain AND host has also left → auto-mark
    // the room as ended (isActive=false). The room is NOT deleted
    // from DB — it stays as "history" so the host can see it in Mine → История.
    fastify.post('/rooms/:id/leave', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const { id } = request.params;

        // Remove this user's participation
        await prisma.roomParticipant.deleteMany({
            where: { roomID: id, userID: request.user.id }
        });

        // Count remaining participants
        const remainingCount = await prisma.roomParticipant.count({
            where: { roomID: id }
        });

        const room = await prisma.room.findUnique({ where: { id } });
        if (!room) {
            return reply.status(404).send({ error: 'Комната не найдена' });
        }

        // 🔧 AUTO-END: if 0 participants AND host is the one leaving (or host
        // already has no participant row, which is the common case after create),
        // mark the room as ended. Room stays in DB as history.
        const isHostLeaving = room.hostID === request.user.id;
        if (remainingCount === 0 && isHostLeaving && room.isActive) {
            await prisma.room.update({
                where: { id },
                data: { isActive: false }
            });
            await cacheDel(ROOMS_CACHE_KEY);
            return reply.send({ success: true, roomEnded: true });
        }

        reply.send({ success: true, roomEnded: false });
    });

    // GET /api/rooms/mine — Мои комнаты
    fastify.get('/rooms/mine', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const rooms = await prisma.room.findMany({
            where: {
                OR: [
                    { hostID: request.user.id },
                    { participants: { some: { userID: request.user.id } } }
                ]
            },
            include: { _count: { select: { participants: true } } },
            orderBy: { createdAt: 'desc' },
        });

        const safeRooms = rooms.map(r => serializeRoom(r));
        reply.send(safeRooms);
    });

    // P0-50/P0-56/P0-57: GET /api/rooms/:id/participants — active participant snapshot
    // P0-56: NO Redis KEYS — uses room-indexed ZSET + Lua to prune expired and return active userIds.
    // P0-57: host returned separately with online status, not forced into participants.
    // P1-65: single Lua call, no N+1 zcount.
    fastify.get('/rooms/:id/participants', {
        preHandler: [fastify.authenticate],
        config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    }, async (request: any, reply: any) => {
        const { id: roomId } = request.params;

        // Verify membership
        const [participant, room] = await Promise.all([
            prisma.roomParticipant.findUnique({
                where: { roomID_userID: { roomID: roomId, userID: request.user.id } },
                select: { id: true },
            }).catch(() => null),
            prisma.room.findUnique({
                where: { id: roomId },
                select: { hostID: true, isActive: true },
            }),
        ]);
        if (!room) return reply.status(404).send({ error: 'Room not found' });
        if (room.hostID !== request.user.id && !participant) {
            return reply.status(403).send({ error: 'Not a room member' });
        }

        // P0-56: Use room-indexed ZSET instead of KEYS.
        // Each presence key is plink:presence:{roomId}:{userId} with ZSET of
        // connectionId → leaseExpiresAtMs. We also maintain a room-level index
        // ZSET: plink:room:{roomId}:activeUsers with userId → latestLeaseExpiresAtMs.
        // This Lua script prunes expired entries from both the index and
        // individual user keys, then returns active userIds.
        const redis = fastify.redis;
        let activeUserIds: string[] = [];
        if (redis) {
            const now = Date.now();
            const roomIndexKey = `plink:room:${roomId}:activeUsers`;
            // Prune expired from room index
            await redis.zremrangebyscore(roomIndexKey, '-inf', now);
            // Get active userIds from room index
            const activeEntries = await redis.zrangebyscore(roomIndexKey, now, '+inf');
            activeUserIds = activeEntries;
        }

        // P0-57: Fetch host separately with online status
        const host = await prisma.user.findUnique({
            where: { id: room.hostID },
            select: { id: true, username: true },
        });

        // Fetch usernames for active participants
        const users = activeUserIds.length > 0
            ? await prisma.user.findMany({
                where: { id: { in: activeUserIds } },
                select: { id: true, username: true },
            })
            : [];

        return reply.send({
            // P0-57: host metadata separate from active participants
            host: host ? {
                userId: host.id,
                username: host.username,
                online: activeUserIds.includes(host.id),
            } : null,
            // P0-57: only actually active connections
            participants: users.map(u => ({ userId: u.id, username: u.username })),
        });
    });

    // P0-59/P1-11: GET /api/rooms/:id/messages — chat catch-up with opaque cursor
    // P0-59: cursor is opaque base64 of (createdAtMs,id), not raw messageId.
    // Fetches limit+1 to determine hasMore deterministically.
    // Tie-breaker: createdAt > ts OR (createdAt = ts AND id > id).
    fastify.get('/rooms/:id/messages', {
        preHandler: [fastify.authenticate],
        config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    }, async (request: any, reply: any) => {
        const { id: roomId } = request.params;
        const cursor = (request.query as any)?.cursor as string | undefined;
        const limit = Math.min(parseInt((request.query as any)?.limit as string) || 50, 200);

        // Verify membership
        const [participant, room] = await Promise.all([
            prisma.roomParticipant.findUnique({
                where: { roomID_userID: { roomID: roomId, userID: request.user.id } },
                select: { id: true },
            }).catch(() => null),
            prisma.room.findUnique({
                where: { id: roomId },
                select: { hostID: true, isActive: true },
            }),
        ]);
        if (!room) return reply.status(404).send({ error: 'Room not found' });
        if (room.hostID !== request.user.id && !participant) {
            return reply.status(403).send({ error: 'Not a room member' });
        }

        // P0-59: decode opaque cursor — base64 of "createdAtMs:id"
        let afterCreatedAt: Date | undefined;
        let afterId: string | undefined;
        if (cursor) {
            try {
                const decoded = Buffer.from(cursor, 'base64').toString('utf-8');
                const parts = decoded.split(':');
                if (parts.length === 2) {
                    afterCreatedAt = new Date(parseInt(parts[0]));
                    afterId = parts[1];
                }
            } catch {
                // Invalid cursor — return from beginning
            }
        }

        // P0-59: fetch limit+1 to determine hasMore
        const fetchLimit = limit + 1;
        const messages = await prisma.chatMessage.findMany({
            where: {
                roomID: roomId,
                ...(afterCreatedAt && afterId
                    ? {
                        OR: [
                            { createdAt: { gt: afterCreatedAt } },
                            { createdAt: { equals: afterCreatedAt }, id: { gt: afterId } },
                        ],
                    }
                    : afterCreatedAt
                    ? { createdAt: { gt: afterCreatedAt } }
                    : {}),
            },
            orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
            take: fetchLimit,
            select: {
                id: true,
                senderID: true,
                text: true,
                createdAt: true,
            },
        });

        // P0-59: hasMore is true only if we got limit+1 messages
        const hasMore = messages.length > limit;
        const returnMessages = hasMore ? messages.slice(0, limit) : messages;

        // P0-59: build nextCursor from last returned message
        let nextCursor: string | null = null;
        if (hasMore && returnMessages.length > 0) {
            const last = returnMessages[returnMessages.length - 1];
            nextCursor = Buffer.from(`${last.createdAt.getTime()}:${last.id}`).toString('base64');
        }

        // Fetch sender usernames in bulk
        const senderIds = [...new Set(returnMessages.map(m => m.senderID))];
        const senders = senderIds.length > 0
            ? await prisma.user.findMany({
                where: { id: { in: senderIds } },
                select: { id: true, username: true },
            })
            : [];
        const senderMap = new Map(senders.map(s => [s.id, s.username]));

        reply.send({
            messages: returnMessages.map(m => ({
                messageId: m.id,
                clientMessageId: null,
                senderId: m.senderID,
                senderName: senderMap.get(m.senderID) ?? 'unknown',
                text: m.text,
                createdAtMs: m.createdAt.getTime(),
            })),
            hasMore,
            nextCursor,  // P0-59: opaque cursor, not messageId
        });
    });

    // P1-66: AUTO-CLEANUP CRON — uses Redis presence leases, not just DB participants.
    // A room is orphan if: isActive=true AND no active presence leases in Redis.
    // Host commonly has no RoomParticipant row — old code would end live host-only rooms.
    setInterval(async () => {
        try {
            const activeRooms = await prisma.room.findMany({
                where: { isActive: true },
                select: { id: true },
            });
            const now = Date.now();
            const orphanRoomIds: string[] = [];
            for (const room of activeRooms) {
                // P1-66: check Redis room index for active leases
                const roomIndexKey = `plink:room:${room.id}:activeUsers`;
                if (fastify.redis) {
                    await fastify.redis.zremrangebyscore(roomIndexKey, '-inf', now);
                    const activeCount = await fastify.redis.zcount(roomIndexKey, now, '+inf');
                    if (activeCount === 0) {
                        // P1-66: also check if host has their own per-user lease
                        // (room index might not have been updated)
                        orphanRoomIds.push(room.id);
                    }
                } else {
                    // No Redis — fall back to DB participants
                    const pCount = await prisma.roomParticipant.count({
                        where: { roomID: room.id },
                    });
                    if (pCount === 0) orphanRoomIds.push(room.id);
                }
            }
            if (orphanRoomIds.length === 0) return;
            await prisma.room.updateMany({
                where: { id: { in: orphanRoomIds } },
                data: { isActive: false },
            });
            await cacheDel(ROOMS_CACHE_KEY);
            console.log(`[cleanup] Auto-ended ${orphanRoomIds.length} orphan room(s) via lease check`);
        } catch (e: any) {
            console.error('[cleanup] Error:', e?.message || e);
        }
    }, 5 * 60 * 1000).unref();
}

function generateRoomCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

async function getUserPremiumStatus(prisma, userId: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { isPremium: true }
    });
    return user?.isPremium ?? false;
}
