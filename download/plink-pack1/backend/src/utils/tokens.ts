// src/utils/tokens.ts — JWT token generation with refresh tokens
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import { prisma } from '../config/db.js';
import { config } from '../config/index.js';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  accessExpiresAt: number;
  refreshExpiresAt: number;
}

export async function issueTokenPair(fastify: any, userId: string): Promise<TokenPair> {
  // Short-lived access token (15 min)
  const accessToken = fastify.jwt.sign(
    { id: userId },
    { expiresIn: config.ACCESS_TOKEN_TTL }
  );
  
  // Long-lived refresh token (30 days, stored hashed in DB)
  const refreshPayload = crypto.randomBytes(48).toString('hex');
  const refreshHash = await bcrypt.hash(refreshPayload, 10);
  const refreshExpiresAt = new Date(
    Date.now() + config.REFRESH_TOKEN_TTL_DAYS * 24 * 3600 * 1000
  );
  
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: refreshHash,
      expiresAt: refreshExpiresAt,
    },
  });
  
  const refreshToken = `${userId}.${refreshPayload}`;
  
  return {
    accessToken,
    refreshToken,
    accessExpiresAt: Date.now() + 15 * 60 * 1000,
    refreshExpiresAt: refreshExpiresAt.getTime(),
  };
}

export async function verifyRefreshToken(fastify: any, refreshToken: string) {
  const [userId, payload] = refreshToken.split('.');
  if (!userId || !payload) return null;
  
  const tokens = await prisma.refreshToken.findMany({
    where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
  });
  
  for (const stored of tokens) {
    const match = await bcrypt.compare(payload, stored.tokenHash);
    if (match) {
      // Rotation: revoke this token
      await prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date() },
      });
      return { userId, tokenId: stored.id };
    }
  }
  return null;
}

export async function revokeAllUserTokens(userId: string) {
  await prisma.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
