/**
 * Plink Backend Security Middleware
 * Этап 1: Бэкенд и безопасность (3.1, 3.3, 3.5)
 */

import bcrypt from 'bcrypt';

// ═══════════════════════════════════════════════════════════════════════
// 3.1 — ПРОВЕРКА ПРАВ ХОСТА
// ═══════════════════════════════════════════════════════════════════════

export async function isRoomHost(prisma, roomId: string, userId: string): Promise<boolean> {
    const room = await prisma.room.findUnique({
        where: { id: roomId },
        select: { hostID: true }
    });
    return room?.hostID === userId;
}

export function requireHost(prisma) {
    return async (request, reply) => {
        const { id: roomId } = request.params;
        const userId = request.user.id;
        const room = await prisma.room.findUnique({
            where: { id: roomId },
            select: { hostID: true }
        });
        if (!room) return reply.status(404).send({ error: 'Room not found' });
        if (room.hostID !== userId) {
            return reply.status(403).send({ error: 'Only host can control playback' });
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════
// 3.3 — ВАЛИДАЦИЯ SENDERID В ЧАТЕ
// ═══════════════════════════════════════════════════════════════════════

export async function sanitizeChatMessage(
    clientMsg: any,
    user: { id: string; username: string; role: string }
) {
    return {
        type: 'chat',
        roomID: clientMsg.roomID,
        id: clientMsg.id || crypto.randomUUID(),
        senderID: user.id,
        senderName: user.username,
        senderRole: user.role,
        text: sanitizeText(clientMsg.text),
        timestamp: Date.now(),
    };
}

function sanitizeText(text: string): string {
    if (!text || typeof text !== 'string') return '';
    let cleaned = text
        .replace(/<[^>]*>/g, '')
        .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&').replace(/&quot;/g, '"')
        .replace(/&#x27;/g, "'").replace(/&#x2F;/g, '/');
    if (cleaned.length > 150) cleaned = cleaned.substring(0, 150);
    cleaned = cleaned.replace(/[\x00-\x1F\x7F]/g, '');
    return cleaned.trim();
}

// ═══════════════════════════════════════════════════════════════════════
// 3.5 — ХЕШИРОВАНИЕ ПАРОЛЕЙ КОМНАТ
// ═══════════════════════════════════════════════════════════════════════

const BCRYPT_ROUNDS = 10;

export async function hashRoomPassword(plain: string): Promise<string> {
    return bcrypt.hash(plain, BCRYPT_ROUNDS);
}

export async function verifyRoomPassword(plain: string, hashed: string): Promise<boolean> {
    try { return await bcrypt.compare(plain, hashed); } catch { return false; }
}

// ═══════════════════════════════════════════════════════════════════════
// Rate limiting (max 10/sec per user)
// ═══════════════════════════════════════════════════════════════════════

const rlMap = new Map<string, { count: number; resetAt: number }>();

export function checkRateLimit(userId: string): boolean {
    const now = Date.now();
    const e = rlMap.get(userId);
    if (!e || now > e.resetAt) {
        rlMap.set(userId, { count: 1, resetAt: now + 1000 });
        return true;
    }
    if (e.count >= 10) return false;
    e.count++;
    return true;
}

setInterval(() => {
    const now = Date.now();
    for (const [k, v] of rlMap) if (now > v.resetAt) rlMap.delete(k);
}, 60_000);
