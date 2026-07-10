# Prisma migrations

This directory is the Prisma migration history root. The schema lives at
`prisma/schema.prisma` and the production datasource is **PostgreSQL**
(`provider = "postgresql"`, `url = env("DATABASE_URL")`).

`start.sh` runs `npx prisma migrate deploy` on boot, which applies any pending
migrations found under this directory. Production deploys therefore require
this directory to contain a real initial migration BEFORE the first deploy.

## Baseline migration — REQUIRED on first dev setup

This directory currently ships with **only** `migration_lock.toml`. There is
**no** `*/migration.sql` baseline checked in. The migration was intentionally
NOT hand-generated, because the schema has 13 models with composite relations,
enum types, indexes, unique constraints, and cascade rules — hand-writing the
SQL risks drift from what Prisma would generate, and a divergent baseline would
poison every future migration. The task spec explicitly forbade this:
*"Do NOT generate incorrect SQL."*

To create the baseline, a developer with a local Postgres instance MUST run:

```bash
# 1. Make sure DATABASE_URL points at an EMPTY dev Postgres database
export DATABASE_URL="postgresql://user:pass@localhost:5432/plink_dev"

# 2. Generate the initial migration from schema.prisma
npx prisma migrate dev --name init

# 3. Commit the generated prisma/migrations/<timestamp>_init/migration.sql
```

This will produce `prisma/migrations/<timestamp>_init/migration.sql` containing
the canonical `CREATE TABLE` statements for every model in `schema.prisma`
(User, Room, RoomParticipant, ChatMessage, DirectMessage, FriendRequest,
Friendship, WatchHistory, PlaybackState, Subscription, UserBlock, Report,
RefreshToken, AuditLog, Referral, FeatureFlag, AdBreak — plus the
`"UserRole"` enum and `_prisma_migrations` shadow table).

After the baseline migration is committed, `prisma migrate deploy` in
production will apply it on the next deploy and stamp the database as migrated.

## Until the baseline is generated

`prisma migrate deploy` against an empty `prisma/migrations/` (only
`migration_lock.toml`) prints `No pending migrations to apply.` and exits 0.
The database is left empty (no tables). This is acceptable as a placeholder
state for CI but **not** for runtime — the backend will crash on first DB
query. Generate the baseline before the first production deploy.

## Why not SQLite?

The task spec suggested `provider = "sqlite"` in `migration_lock.toml`, but
`prisma/schema.prisma` declares `provider = "postgresql"`. A mismatch between
`migration_lock.toml` and `schema.prisma` providers causes
`prisma migrate deploy` to fail with
`P3006: Migration history is incompatible with local datasource`. The
`migration_lock.toml` here uses `provider = "postgresql"` to match the schema.
