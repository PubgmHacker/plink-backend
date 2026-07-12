// src/routes/discovery.ts
//
// Brain Phase 5: first-party Popular in Plink.
//
// GET /api/discovery/popular?window=24h&limit=20
//
// Aggregates ONLY Plink activity from public rooms:
//   - unique viewers (RoomParticipant)
//   - unique rooms
//   - recent starts (joins within window)
//
// Response includes room name, thumbnail (from mediaItem), active room/viewer
// counts. Excludes private rooms (privacy='private' or password set) — there
// is no separate isBlocked/isReported field on Room; reported rooms are in
// the Report table and excluded via NOT IN subquery.
//
// This is NOT scraping Netflix / VK / Kinopoisk. It is a first-party
// popularity signal derived from Plink room activity only.

import { PrismaClient } from '@prisma/client';
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

const prisma = new PrismaClient();

const MIN_COHORT_FOR_PRIVACY = 3; // hide cohorts with < 3 unique viewers
const DEFAULT_WINDOW_HOURS = 24;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;

export async function discoveryRoutes(fastify: FastifyInstance, _options: any) {
  // ═══════════════════════════════════════════════════════════════════
  // GET /api/discovery/popular?window=24h&limit=20
  // ═══════════════════════════════════════════════════════════════════
  fastify.get('/discovery/popular', {
    config: { rateLimit: { max: 60, timeWindow: '1 minute' } },
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    const query = request.query as any;
    const windowHours = Math.min(Math.max(parseInt(query.window) || DEFAULT_WINDOW_HOURS, 1), 168);
    const limit = Math.min(Math.max(parseInt(query.limit) || DEFAULT_LIMIT, 1), MAX_LIMIT);

    const since = new Date(Date.now() - windowHours * 60 * 60 * 1000);

    try {
      // Aggregate room activity in the window.
      // Group by mediaItem (which is the content URL/title identifier) and
      // count unique viewers and rooms.
      const rows = await prisma.$queryRaw<Array<{
        media_item: string | null;
        room_name: string;
        unique_viewers: bigint;
        unique_rooms: bigint;
        recent_starts: bigint;
      }>>`
        SELECT
          r."mediaItem" AS media_item,
          MAX(r."name") AS room_name,
          COUNT(DISTINCT rp."userID") AS unique_viewers,
          COUNT(DISTINCT r."id") AS unique_rooms,
          COUNT(DISTINCT CASE WHEN rp."joinedAt" >= ${since} THEN rp."userID" END) AS recent_starts
        FROM "Room" r
        INNER JOIN "RoomParticipant" rp ON rp."roomID" = r."id"
        WHERE
          r."createdAt" >= ${since}
          AND r."privacy" = 'public'
          AND r."password" IS NULL
          AND r."id" NOT IN (SELECT "roomId" FROM "Report" WHERE "status" = 'pending')
        GROUP BY r."mediaItem"
        HAVING COUNT(DISTINCT rp."userID") >= ${MIN_COHORT_FOR_PRIVACY}
        ORDER BY unique_viewers DESC, unique_rooms DESC
        LIMIT ${limit}
      `;

      const results = rows.map((row) => ({
        // mediaItem is opaque content identifier (URL or video ID).
        contentURL: row.media_item ?? '',
        title: row.room_name,
        thumbnailURL: null as string | null,
        uniqueViewers: Number(row.unique_viewers),
        uniqueRooms: Number(row.unique_rooms),
        recentStarts: Number(row.recent_starts),
        // YouTube content can be directly opened in a Plink room.
        directCreateRoomDraft: Boolean(
          row.media_item &&
          (row.media_item.includes('youtube.com') ||
           row.media_item.includes('youtu.be') ||
           /^[A-Za-z0-9_-]{11}$/.test(row.media_item))
        ),
      }));

      return reply.send({
        window: `${windowHours}h`,
        generatedAt: new Date().toISOString(),
        results,
      });
    } catch (err: any) {
      request.log.error({ err }, 'discovery/popular failed');
      return reply.status(500).send({ error: 'Internal Server Error' });
    }
  });
}
