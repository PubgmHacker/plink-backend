/**
 * Plink Backend — Room Routes (безопасные)
 * Этап 1: Хеширование паролей + проверка прав хоста + фильтрация приватных
 */

import { hashRoomPassword, verifyRoomPassword, requireHost } from '../middleware/security.js';

export default async function roomRoutes(fastify, _options) {
    const { prisma } = fastify;

    // POST /api/rooms — Создание комнаты
    fastify.post('/rooms', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const { name, maxParticipants, mediaItem, privacy, password } = request.body;

        const hashedPassword = password ? await hashRoomPassword(password) : null;

        const room = await prisma.room.create({
            data: {
                name,
                hostID: request.user.id,
                hostName: request.user.username,
                code: generateRoomCode(),
                maxParticipants: maxParticipants || 10,
                mediaItem: mediaItem ? JSON.stringify(mediaItem) : null,
                privacy: privacy || 'public',
                password: hashedPassword,
                hostIsPremium: await getUserPremiumStatus(prisma, request.user.id),
                isActive: true,
            }
        });

        const { password: _, ...roomWithoutPassword } = room;
        reply.send(roomWithoutPassword);
    });

    // POST /api/rooms/join — Вход в комнату (с проверкой пароля)
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

        const { password: _, ...roomWithoutPassword } = room;
        reply.send(roomWithoutPassword);
    });

    // POST /api/rooms/:id/playback — Только хост
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

        reply.send({ success: true });
    });

    // GET /api/rooms — Только публичные
    fastify.get('/rooms', {
        preHandler: [fastify.authenticate]
    }, async (request, reply) => {
        const rooms = await prisma.room.findMany({
            where: { isActive: true, privacy: 'public' },
            include: { _count: { select: { participants: true } } },
            orderBy: { createdAt: 'desc' },
            take: 50,
        });

        const safeRooms = rooms.map(({ password, ...r }) => r);
        reply.send(safeRooms);
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

        const safeRooms = rooms.map(({ password, ...r }) => r);
        reply.send(safeRooms);
    });
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
