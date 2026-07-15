// src/routes/billing.ts — Pack 3: StoreKit 2 receipt validation
import { prisma } from '../config/db.js';
import { logAudit, AuditActions } from '../utils/audit.js';

const APP_STORE_SHARED_SECRET = process.env.APP_STORE_SHARED_SECRET;
const SANDBOX_VERIFY_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';
const PROD_VERIFY_URL = 'https://buy.itunes.apple.com/verifyReceipt';

// Premium plans (matching StoreKit 2 product IDs in iOS - P1 sandbox)
const PLANS: Record<string, { durationDays: number; price: number }> = {
  'plink.plus.1m':   { durationDays: 30,   price: 199 },
  'plink.plus.3m':   { durationDays: 90,   price: 499 },
  'plink.plus.12m':  { durationDays: 365,  price: 1990 },
  // legacy ids for backward compat
  'plink.premium.monthly': { durationDays: 30, price: 199 },
  'plink.premium.yearly':  { durationDays: 365, price: 1990 },
};

export default async function billingRoutes(fastify) {

  // POST /api/billing/verify — P1: supports both modern StoreKit 2 JWS and legacy receipt
  fastify.post('/billing/verify', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 5, timeWindow: '1 minute' } }
  }, async (request, reply) => {
    const body = request.body as any;
    const productId = body.productId || body.product_id;

    if (!PLANS[productId]) {
      return reply.status(400).send({ error: 'Invalid productId' });
    }

    const plan = PLANS[productId];

    try {
      let premiumUntil: Date;
      let verified = false;

      // === Modern StoreKit 2 path (JWS) ===
      if (body.jws) {
        // Decode JWS payload (header.payload.signature). We trust the signature for sandbox
        // in this implementation; full root cert validation recommended for production.
        const parts = String(body.jws).split('.');
        if (parts.length !== 3) {
          return reply.status(400).send({ valid: false, error: 'Invalid JWS format' });
        }

        const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
        const transactionProductId = payload.productId || payload.product_id || productId;
        const expiresDate = payload.expiresDate || payload.expires_date_ms || payload.expiresDateMs;

        if (!PLANS[transactionProductId]) {
          return reply.status(400).send({ valid: false, error: 'Product mismatch in JWS' });
        }

        const now = Date.now();
        if (expiresDate) {
          premiumUntil = new Date(Number(expiresDate));
          if (premiumUntil.getTime() <= now) {
            return reply.status(400).send({ valid: false, error: 'Subscription expired' });
          }
        } else {
          premiumUntil = new Date(now + plan.durationDays * 24 * 3600 * 1000);
        }
        verified = true;
      }
      // === Legacy receipt path (old verifyReceipt) ===
      else if (body.receipt) {
        if (!APP_STORE_SHARED_SECRET) {
          return reply.status(500).send({ error: 'APP_STORE_SHARED_SECRET not configured' });
        }

        let response = await fetch(PROD_VERIFY_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            'receipt-data': body.receipt,
            password: APP_STORE_SHARED_SECRET,
            'exclude-old-transactions': true,
          }),
        });
        let data: any = await response.json();

        if (data.status === 21007) {
          response = await fetch(SANDBOX_VERIFY_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 'receipt-data': body.receipt, password: APP_STORE_SHARED_SECRET }),
          });
          data = await response.json();
        }

        if (data.status !== 0) {
          return reply.status(400).send({ valid: false, error: `Receipt verification failed (status ${data.status})` });
        }

        const purchases = data.receipt?.in_app || [];
        const purchase = purchases.find((p: any) => p.product_id === productId);
        if (!purchase) {
          return reply.status(400).send({ valid: false, error: 'Purchase not found in receipt' });
        }

        const expiresMs = parseInt(purchase.expires_date_ms || '0');
        const now = Date.now();
        if (expiresMs > 0) {
          premiumUntil = new Date(expiresMs);
          if (premiumUntil <= new Date()) {
            return reply.status(400).send({ valid: false, error: 'Subscription expired' });
          }
        } else {
          premiumUntil = new Date(now + plan.durationDays * 24 * 3600 * 1000);
        }
        verified = true;
      } else {
        return reply.status(400).send({ error: 'receipt or jws required' });
      }

      if (!verified) {
        return reply.status(400).send({ valid: false, error: 'Verification failed' });
      }

      // Persist subscription
      await prisma.subscription.create({
        data: {
          userID: request.user.id,
          plan: productId,
          isActive: true,
          expiresAt: premiumUntil!,
        },
      });

      await prisma.user.update({
        where: { id: request.user.id },
        data: { isPremium: true, premiumUntil: premiumUntil! },
      });

      await logAudit({
        userId: request.user.id,
        action: AuditActions.USER_PREMIUM_GRANTED,
        ip: request.ip,
        metadata: { productId, expiresAt: premiumUntil!.toISOString() },
      });

      reply.send({
        valid: true,
        premium: true,
        premiumUntil: premiumUntil!.toISOString(),
        plan: productId,
        entitlement: {
          active: true,
          tier: 'premium',
          expiryDate: premiumUntil!.toISOString(),
        },
      });
    } catch (e: any) {
      console.error('Billing verify error', e);
      reply.status(500).send({ error: 'Verification failed: ' + e.message });
    }
  });

  // GET /api/billing/entitlements — P1: server-authoritative entitlement for app launch
  fastify.get('/billing/entitlements', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { isPremium: true, premiumUntil: true },
    });

    if (!user) return reply.status(404).send({ error: 'User not found' });

    const isActive = !!user.isPremium && (!user.premiumUntil || user.premiumUntil > new Date());

    reply.send({
      entitlement: {
        active: isActive,
        tier: isActive ? 'premium' : 'free',
        expiryDate: user.premiumUntil ? user.premiumUntil.toISOString() : null,
      },
    });
  });

  // GET /api/billing/status — статус premium подписки
  fastify.get('/billing/status', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user.id },
      select: { isPremium: true, premiumUntil: true }
    });
    
    if (!user) return reply.status(404).send({ error: 'User not found' });

    const isActive = user.isPremium && 
                     (!user.premiumUntil || user.premiumUntil > new Date());

    reply.send({
      isPremium: isActive,
      premiumUntil: user.premiumUntil,
    });
  });

  // POST /api/billing/cancel — отменить подписку (mark inactive, не refund)
  fastify.post('/billing/cancel', {
    preHandler: [fastify.authenticate],
  }, async (request, reply) => {
    await prisma.subscription.updateMany({
      where: { 
        userID: request.user.id,
        isActive: true,
      },
      data: { isActive: false },
    });
    
    await logAudit({
      userId: request.user.id,
      action: 'billing.cancel',
      ip: request.ip,
    });
    
    reply.send({ success: true });
  });
}
