// src/realtime/heartbeat.ts — WS ping/pong heartbeat (runbook §5)
//
// Per §5: heartbeat isAlive via WS ping frames every 20 seconds.
// On WS, the server sends a ping frame; the client must respond with a pong.
// If no pong arrives within ~30s, we terminate the connection.
//
// This catches: half-open TCP (NAT timeout), zombie connections on LB failover,
// clients that crashed without sending close.

import type { WebSocketServer } from 'ws';
import type { PlinkSocket, ConnectionRegistry } from './connectionRegistry.js';

const HEARTBEAT_INTERVAL_MS = 20_000;
const TERMINATE_GRACE_MS = 35_000;

export class Heartbeat {
  private readonly interval: NodeJS.Timeout;
  private readonly registry: ConnectionRegistry;

  constructor(wss: WebSocketServer, registry: ConnectionRegistry) {
    this.registry = registry;

    wss.on('connection', (socket: PlinkSocket) => {
      socket.isAlive = true;
      socket.on('pong', () => {
        socket.isAlive = true;
      });
    });

    this.interval = setInterval(() => {
      wss.clients.forEach((sock) => {
        const socket = sock as PlinkSocket;
        if (socket.isAlive === false) {
          // No pong since last ping — terminate
          socket.terminate();
          this.registry.disconnect(socket);
          return;
        }
        socket.isAlive = false;
        try {
          socket.ping();
        } catch {
          // socket already dead
        }
      });
    }, HEARTBEAT_INTERVAL_MS);
    // Don't keep the event loop alive just for heartbeat
    this.interval.unref();
  }

  close(): void {
    clearInterval(this.interval);
  }
}

// Re-export type for convenience
export type { PlinkSocket };
export const TERMINATE_GRACE = TERMINATE_GRACE_MS;
