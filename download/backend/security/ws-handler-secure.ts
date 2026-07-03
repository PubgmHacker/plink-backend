/**
 * Plink Backend — WebSocket Handler (безопасный)
 * Этап 1: Валидация senderID + проверка прав хоста + rate limiting
 */

import { isRoomHost, sanitizeChatMessage, checkRateLimit } from '../middleware/security.js';

export function setupWebSocketHandler(io, prisma, fastify) {

    io.use(async (socket, next) => {
        try {
            const token = socket.handshake.auth?.token 
                       || socket.handshake.query?.token;
            if (!token) return next(new Error('No token'));

            const payload = fastify.jwt.verify(token);
            const user = await prisma.user.findUnique({
                where: { id: payload.id },
                select: { id: true, username: true, role: true, bannedUntil: true }
            });

            if (!user) return next(new Error('User not found'));
            if (user.bannedUntil && user.bannedUntil > new Date()) {
                return next(new Error('User banned'));
            }

            socket.user = user;
            next();
        } catch (err) {
            next(new Error('Auth failed'));
        }
    });

    io.on('connection', (socket) => {
        console.log(`[WS] ${socket.user.username} connected`);

        socket.on('join', async (data) => {
            const { roomId } = data;
            socket.join(roomId);
            socket.activeRoomId = roomId;
            socket.to(roomId).emit('participant_update', {
                action: 'joined',
                userID: socket.user.id,
                username: socket.user.username,
            });
        });

        socket.on('sync', async (msg) => {
            if (!checkRateLimit(socket.user.id)) {
                socket.emit('error', { message: 'Rate limit exceeded' });
                return;
            }

            if (['play', 'pause', 'seek'].includes(msg.command)) {
                const hostCheck = await isRoomHost(prisma, msg.roomID, socket.user.id);
                if (!hostCheck) {
                    socket.emit('error', { message: 'Only the host can control playback' });
                    return;
                }
            }

            msg.senderID = socket.user.id;
            socket.to(msg.roomID).emit('sync', msg);
        });

        socket.on('chat', async (msg) => {
            if (!checkRateLimit(socket.user.id)) {
                socket.emit('error', { message: 'Rate limit exceeded' });
                return;
            }

            const safeMsg = await sanitizeChatMessage(msg, socket.user);

            await prisma.chatMessage.create({
                data: {
                    roomID: safeMsg.roomID,
                    senderID: safeMsg.senderID,
                    text: safeMsg.text,
                }
            });

            io.to(safeMsg.roomID).emit('chat', safeMsg);
        });

        socket.on('reaction', (msg) => {
            if (!checkRateLimit(socket.user.id)) return;
            socket.to(msg.roomID).emit('reaction', {
                ...msg,
                senderID: socket.user.id,
                senderName: socket.user.username,
            });
        });

        socket.on('disconnect', () => {
            if (socket.activeRoomId) {
                socket.to(socket.activeRoomId).emit('participant_update', {
                    action: 'left',
                    userID: socket.user.id,
                    username: socket.user.username,
                });
            }
        });
    });
}
