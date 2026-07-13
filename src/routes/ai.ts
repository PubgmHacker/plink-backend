// src/routes/ai.ts — Pack 6: AI Assistant endpoint + P0.4 action confirmation
import crypto from 'node:crypto';
import { prisma } from '../config/db.js';
import { logAudit, AuditActions } from '../utils/audit.js';

const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;
const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// P0.4: Pending AI actions store (in-memory, TTL 5 min).
// In production, use Redis. For MVP, this works for single-instance deploys.
interface PendingAction {
  confirmationId: string;
  userId: string;
  type: string;  // 'create_room' | 'build_queue' | 'get_friend_activity'
  payload: any;
  createdAt: number;
  expiresAt: number;
}
const pendingActions = new Map<string, PendingAction>();
const ACTION_TTL_MS = 5 * 60 * 1000;  // 5 minutes

// Cleanup expired actions every minute
setInterval(() => {
  const now = Date.now();
  for (const [id, action] of pendingActions) {
    if (action.expiresAt < now) pendingActions.delete(id);
  }
}, 60_000).unref?.();

export default async function aiRoutes(fastify) {
  
  // POST /api/ai/chat — universal AI assistant
  fastify.post('/ai/chat', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
  }, async (request, reply) => {
    const { messages, context, mode } = request.body;
    
    if (!OPENROUTER_API_KEY) {
      return reply.status(503).send({ 
        error: 'AI not configured. Set OPENROUTER_API_KEY env var.' 
      });
    }
    
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return reply.status(400).send({ error: 'Messages array required' });
    }
    
    // System prompt depends on mode
    const systemPrompt = buildSystemPrompt(mode, context, request.user);
    
    try {
      const response = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
          'HTTP-Referer': 'https://plink.app',
          'X-Title': 'Plink AI Assistant',
        },
        body: JSON.stringify({
          model: 'openai/gpt-4o-mini',
          messages: [
            { role: 'system', content: systemPrompt },
            ...messages,
          ],
          temperature: 0.7,
          max_tokens: 1000,
        }),
      });
      
      if (!response.ok) {
        const errText = await response.text();
        console.error('OpenRouter error', response.status, errText);
        return reply.status(response.status).send({ 
          error: 'AI request failed',
          details: errText,
        });
      }
      
      const data: any = await response.json();
      const aiMessage = data.choices?.[0]?.message?.content || '';

      // P0.4: Detect action intent from AI response. If user asked to create
      // a room, AI should mention "create_room" in response. We check for
      // keywords and create a pending action.
      let proposedAction: any = null;
      const lowerMsg = aiMessage.toLowerCase();

      if (lowerMsg.includes('созда') && (lowerMsg.includes('комнат') || lowerMsg.includes('room'))) {
        // AI wants to create a room — create pending action
        const confirmationId = crypto.randomUUID();
        const mediaItem = context?.mediaItem || {
          id: 'youtube_search',
          title: context?.title || 'AI suggested content',
          streamURL: context?.url || '',
          source: 'youtube'
        };
        pendingActions.set(confirmationId, {
          confirmationId,
          userId: request.user.id,
          type: 'create_room',
          payload: {
            name: context?.roomName || `${request.user.username}'s room`,
            mediaItem,
            privacy: 'public',
            maxParticipants: 10,
          },
          createdAt: Date.now(),
          expiresAt: Date.now() + ACTION_TTL_MS,
        });
        proposedAction = {
          type: 'create_room',
          confirmationId,
          expiresAt: new Date(Date.now() + ACTION_TTL_MS).toISOString(),
          payloadPreview: {
            title: pendingActions.get(confirmationId)!.payload.name,
            privacy: 'public',
            maxParticipants: 10,
            mediaTitle: mediaItem.title,
          }
        };
      }

      reply.send({
        message: aiMessage,
        model: data.model,
        usage: data.usage,
        proposedAction,
      });
    } catch (e: any) {
      console.error('AI chat error', e);
      reply.status(500).send({ error: 'AI request failed: ' + e.message });
    }
  });
  
  // POST /api/ai/recommend — recommend movies/shows based on mood
  fastify.post('/ai/recommend', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
  }, async (request, reply) => {
    const { mood, genre, service } = request.body;
    
    if (!OPENROUTER_API_KEY) {
      return reply.status(503).send({ error: 'AI not configured' });
    }
    
    const prompt = buildRecommendationPrompt(mood, genre, service);
    
    try {
      const response = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
          'HTTP-Referer': 'https://plink.app',
          'X-Title': 'Plink AI',
        },
        body: JSON.stringify({
          model: 'openai/gpt-4o-mini',
          messages: [
            { role: 'system', content: 'You are a movie/TV recommendation expert. Return JSON only.' },
            { role: 'user', content: prompt },
          ],
          temperature: 0.8,
          max_tokens: 800,
          response_format: { type: 'json_object' },
        }),
      });
      
      if (!response.ok) {
        return reply.status(response.status).send({ error: 'AI request failed' });
      }
      
      const data: any = await response.json();
      const content = data.choices?.[0]?.message?.content || '{}';
      
      try {
        const parsed = JSON.parse(content);
        reply.send(parsed);
      } catch {
        reply.send({ recommendations: [], raw: content });
      }
    } catch (e: any) {
      reply.status(500).send({ error: 'AI request failed: ' + e.message });
    }
  });

  // ─────────────────────────────────────────────────────────────────────
  // P0.4: POST /api/ai/confirm-action
  // ─────────────────────────────────────────────────────────────────────
  // Confirms a pending AI action by confirmationId. Executes the action
  // server-side (create room, build queue, etc.). Idempotent — each
  // confirmationId can only be executed once. Audit-logged.
  fastify.post('/ai/confirm-action', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } }
  }, async (request, reply) => {
    const { confirmationId, idempotencyKey } = request.body;

    if (!confirmationId) {
      return reply.status(400).send({ error: 'confirmationId required' });
    }

    const action = pendingActions.get(confirmationId);
    if (!action) {
      return reply.status(404).send({ error: 'Action not found or expired' });
    }

    // Verify ownership
    if (action.userId !== request.user.id) {
      return reply.status(403).send({ error: 'Action belongs to another user' });
    }

    // Verify not expired
    if (action.expiresAt < Date.now()) {
      pendingActions.delete(confirmationId);
      return reply.status(410).send({ error: 'Action expired' });
    }

    // Idempotency: remove the action before executing (one-shot)
    pendingActions.delete(confirmationId);

    try {
      switch (action.type) {
        case 'create_room': {
          const { name, mediaItem, privacy, maxParticipants } = action.payload;
          const room = await prisma.room.create({
            data: {
              name: name || 'AI Room',
              hostID: request.user.id,
              hostName: request.user.username,
              code: generateRoomCode(),
              mediaItem: mediaItem ? JSON.stringify(mediaItem) : null,
              maxParticipants: maxParticipants || 10,
              privacy: privacy || 'public',
            }
          });

          await prisma.roomParticipant.create({
            data: { roomID: room.id, userID: request.user.id }
          });

          await logAudit({
            userId: request.user.id,
            action: 'room.create',
            ip: request.ip,
            metadata: { roomId: room.id, source: 'ai_confirm', confirmationId }
          });

          return reply.send({ success: true, room });
        }

        case 'get_friend_activity': {
          // Return friend activity data (already fetched in payload)
          return reply.send({ success: true, activity: action.payload.activity });
        }

        case 'build_queue': {
          // Queue built from payload
          return reply.send({ success: true, queue: action.payload.queue });
        }

        default:
          return reply.status(400).send({ error: `Unknown action type: ${action.type}` });
      }
    } catch (e: any) {
      console.error('[ai/confirm-action] Execution failed:', e);
      return reply.status(500).send({ error: 'Action execution failed: ' + e.message });
    }
  });
}

function generateRoomCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

function buildSystemPrompt(mode: string, context: any, user: any): string {
  const base = `You are Plink AI Assistant — a friendly helper inside Plink, an app for watching movies and shows together with friends in real-time.

User context:
- Username: ${user.username}
- Language: detect from user message and respond in same language
- Be concise but warm. Use emojis occasionally. Don't be overly formal.

`;
  
  switch (mode) {
    case 'room_host':
      return base + `The user is hosting a watch party. Help them with:
- Setting up the room
- Choosing what to watch
- Solving sync issues
- Inviting friends
Context: ${JSON.stringify(context || {})}`;
      
    case 'movie_search':
      return base + `The user is looking for something to watch. Help them:
- Suggest movies/shows based on their mood
- Find content available on streaming services
- Give brief descriptions without spoilers
Context: ${JSON.stringify(context || {})}`;
      
    case 'general':
    default:
      return base + `Help the user with any question about Plink, movies, or general chat. Be helpful and friendly.`;
  }
}

function buildRecommendationPrompt(mood: string, genre: string, service: string): string {
  return `Suggest 5 movies or shows to watch with friends.

Criteria:
- Mood: ${mood || 'any'}
- Genre: ${genre || 'any'}
- Available on: ${service || 'any streaming service'}
- Good for group watching

Return JSON in this exact format:
{
  "recommendations": [
    {
      "title": "Movie Name",
      "year": 2024,
      "genre": "Comedy",
      "service": "Netflix",
      "reason": "Why it's good for groups (1 sentence)",
      "rating": 8.5
    }
  ]
}`;
}
