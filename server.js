'use strict';

const Fastify = require('fastify');
const cors = require('@fastify/cors');
const websocket = require('@fastify/websocket');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';

const MAX_PLAYERS = 6;
const ROOM_CODE_LENGTH = 6;
const ROOM_TTL_MS = 30 * 60 * 1000;
const MAX_MESSAGE_SIZE = 64 * 1024;

const app = Fastify({
  logger: true,
  bodyLimit: MAX_MESSAGE_SIZE
});

const rooms = new Map();
const profiles = new Map();
const clans = new Map();

function makeRoomCode() {
  let code;

  do {
    code = crypto
      .randomBytes(4)
      .toString('hex')
      .toUpperCase()
      .slice(0, ROOM_CODE_LENGTH);
  } while (rooms.has(code));

  return code;
}

function makePlayerId() {
  return crypto.randomUUID();
}

function sanitizeName(name) {
  if (typeof name !== 'string') {
    return 'Player';
  }

  const clean = name
    .trim()
    .replace(/[^\p{L}\p{N}_ -]/gu, '')
    .slice(0, 20);

  return clean || 'Player';
}

function createRoom(hostName, mode = 'campaign', maxPlayers = 6) {
  const code = makeRoomCode();
  const hostId = makePlayerId();

  const room = {
    code,
    createdAt: Date.now(),
    lastActivity: Date.now(),
    hostId,
    mode: ['campaign', 'team_duel', 'solo_duel'].includes(mode) ? mode : 'campaign',
    maxPlayers: Math.max(2, Math.min(6, Number(maxPlayers) || 6)),
    started: false,
    players: new Map()
  };

  room.players.set(hostId, {
    id: hostId,
    name: sanitizeName(hostName),
    ready: false,
    host: true,
    socket: null,
    connected: false
  });

  rooms.set(code, room);

  return {
    room,
    player: room.players.get(hostId)
  };
}

function roomToJSON(room) {
  return {
    code: room.code,
    maxPlayers: room.maxPlayers || MAX_PLAYERS,
    mode: room.mode || 'campaign',
    started: room.started,
    players: [...room.players.values()].map((player) => ({
      id: player.id,
      name: player.name,
      ready: player.ready,
      host: player.host,
      connected: player.connected
    }))
  };
}

function send(socket, data) {
  if (!socket || socket.readyState !== 1) return;

  const payload = JSON.stringify(data);

  if (Buffer.byteLength(payload, 'utf8') > MAX_MESSAGE_SIZE) {
    return;
  }

  socket.send(payload);
}

function broadcast(room, data, exceptId = null) {
  for (const player of room.players.values()) {
    if (player.id === exceptId) continue;
    send(player.socket, data);
  }
}

function touch(room) {
  room.lastActivity = Date.now();
}

function removePlayer(room, playerId) {
  const player = room.players.get(playerId);

  if (!player) return;

  room.players.delete(playerId);

  if (player.socket) {
    try {
      player.socket.close();
    } catch {}
  }

  if (room.players.size === 0) {
    rooms.delete(room.code);
    return;
  }

  if (room.hostId === playerId) {
    const nextHost = [...room.players.values()][0];

    room.hostId = nextHost.id;

    for (const p of room.players.values()) {
      p.host = p.id === nextHost.id;
    }

    send(nextHost.socket, {
      type: 'host_changed',
      playerId: nextHost.id
    });
  }

  touch(room);

  broadcast(room, {
    type: 'player_left',
    playerId,
    room: roomToJSON(room)
  });
}

async function start() {
  await app.register(cors, {
    origin: true,
    methods: ['GET', 'POST', 'OPTIONS']
  });

  await app.register(websocket);

  app.get('/', async () => {
    return {
      name: 'CADIS WAR Online Server',
      status: 'online',
      version: '1.0.0',
      maxPlayersPerRoom: MAX_PLAYERS,
      websocket: '/ws',
      health: '/health'
    };
  });

  app.get('/health', async () => {
    return {
      status: 'ok',
      service: 'cadis-war-online',
      uptime: process.uptime(),
      rooms: rooms.size,
      players: [...rooms.values()].reduce(
        (total, room) => total + room.players.size,
        0
      ),
      maxPlayersPerRoom: MAX_PLAYERS,
      timestamp: new Date().toISOString()
    };
  });

  app.get('/rooms', async () => {
    return {
      rooms: [...rooms.values()].map(room => ({
        code: room.code,
        players: room.players.size,
        maxPlayers: MAX_PLAYERS,
        started: room.started
      }))
    };
  });

  app.post('/rooms', async (request, reply) => {
    const body = request.body || {};
    const hostName = sanitizeName(body.name);
    const mode = String(body.mode || 'campaign');
    const maxPlayers = body.maxPlayers;

    const { room, player } = createRoom(hostName, mode, maxPlayers);

    return reply.code(201).send({
      success: true,
      room: roomToJSON(room),
      player: {
        id: player.id,
        name: player.name,
        host: true
      }
    });
  });

  app.post('/rooms/join', async (request, reply) => {
    const body = request.body || {};

    const code = String(body.code || '')
      .trim()
      .toUpperCase();

    const name = sanitizeName(body.name);

    const room = rooms.get(code);

    if (!room) {
      return reply.code(404).send({
        success: false,
        error: 'ROOM_NOT_FOUND'
      });
    }

    if (room.started) {
      return reply.code(409).send({
        success: false,
        error: 'GAME_ALREADY_STARTED'
      });
    }

    if (room.players.size >= (room.maxPlayers || MAX_PLAYERS)) {
      return reply.code(409).send({
        success: false,
        error: 'ROOM_FULL'
      });
    }

    const id = makePlayerId();

    const player = {
      id,
      name,
      ready: false,
      host: false,
      socket: null,
      connected: false
    };

    room.players.set(id, player);
    touch(room);

    broadcast(room, {
      type: 'player_joined',
      player: {
        id: player.id,
        name: player.name,
        ready: false,
        host: false,
        connected: false
      },
      room: roomToJSON(room)
    });

    return {
      success: true,
      room: roomToJSON(room),
      player: {
        id: player.id,
        name: player.name,
        host: false
      }
    };
  });

  app.get('/ws', { websocket: true }, (socket) => {
    let playerId = null;
    let roomCode = null;

    socket.on('message', (raw) => {
      if (Buffer.byteLength(raw) > MAX_MESSAGE_SIZE) {
        send(socket, {
          type: 'error',
          error: 'MESSAGE_TOO_LARGE'
        });
        return;
      }

      let message;

      try {
        message = JSON.parse(raw.toString());
      } catch {
        send(socket, {
          type: 'error',
          error: 'INVALID_JSON'
        });
        return;
      }

      const type = message.type;

      if (type === 'connect') {
        roomCode = String(message.code || '').trim().toUpperCase();
        playerId = String(message.playerId || '');

        const room = rooms.get(roomCode);

        if (!room || !room.players.has(playerId)) {
          send(socket, {
            type: 'error',
            error: 'INVALID_ROOM_OR_PLAYER'
          });

          socket.close();
          return;
        }

        const player = room.players.get(playerId);

        player.socket = socket;
        player.connected = true;

        touch(room);

        send(socket, {
          type: 'connected',
          room: roomToJSON(room),
          playerId
        });

        broadcast(
          room,
          {
            type: 'player_connection',
            playerId,
            connected: true
          },
          playerId
        );

        return;
      }

      if (!playerId || !roomCode) {
        send(socket, {
          type: 'error',
          error: 'NOT_CONNECTED'
        });
        return;
      }

      const room = rooms.get(roomCode);
      const player = room?.players.get(playerId);

      if (!room || !player) {
        send(socket, {
          type: 'error',
          error: 'ROOM_NOT_FOUND'
        });
        return;
      }

      touch(room);

      switch (type) {
        case 'ping':
          send(socket, {
            type: 'pong',
            timestamp: Date.now()
          });
          break;

        case 'result': {
          const profile = profiles.get(playerId) || {
            name: player.name,
            wins: 0,
            losses: 0,
            rewards: 0
          };
          if (message.won) profile.wins += 1;
          else profile.losses += 1;
          profile.rewards += Number(message.reward) || (message.won ? 100 : 25);
          profiles.set(playerId, profile);
          const ranking = [...profiles.values()]
            .sort((a, b) => b.wins - a.wins || b.rewards - a.rewards)
            .slice(0, 50);
          send(socket, { type: 'profile', profile, leaderboard: ranking });
          break;
        }

        case 'clan_create': {
          const tag = String(message.tag || '')
            .toUpperCase()
            .replace(/[^A-Z0-9]/g, '')
            .slice(0, 5);
          if (!tag || clans.has(tag)) {
            send(socket, { type: 'error', error: 'CLAN_TAG_INVALID_OR_TAKEN' });
            break;
          }
          const clan = {
            tag,
            name: String(message.name || 'Clan').slice(0, 24),
            ownerId: playerId,
            members: [playerId]
          };
          clans.set(tag, clan);
          send(socket, { type: 'clan', clan });
          break;
        }

        case 'ready': {
          if (room.started) return;

          player.ready = Boolean(message.ready);

          broadcast(room, {
            type: 'player_ready',
            playerId,
            ready: player.ready,
            room: roomToJSON(room)
          });

          break;
        }

        case 'start_game': {
          if (room.hostId !== playerId) {
            send(socket, {
              type: 'error',
              error: 'ONLY_HOST_CAN_START'
            });
            return;
          }

          if (room.started) return;

          const otherPlayers = [...room.players.values()];

          const everyoneReady = otherPlayers.every(
            p => p.id === playerId || p.ready
          );

          if (!everyoneReady) {
            send(socket, {
              type: 'error',
              error: 'PLAYERS_NOT_READY'
            });
            return;
          }

          room.started = true;

          broadcast(room, {
            type: 'game_started',
            room: roomToJSON(room),
            timestamp: Date.now()
          });

          break;
        }

        case 'player_state': {
          const state = message.state;

          if (!state || typeof state !== 'object') return;

          const safeState = {
            x: Number(state.x) || 0,
            y: Number(state.y) || 0,
            z: Number(state.z) || 0,
            rx: Number(state.rx) || 0,
            ry: Number(state.ry) || 0,
            rz: Number(state.rz) || 0,
            vx: Number(state.vx) || 0,
            vy: Number(state.vy) || 0,
            vz: Number(state.vz) || 0
          };

          broadcast(
            room,
            {
              type: 'player_state',
              playerId,
              state: safeState,
              timestamp: Date.now()
            },
            playerId
          );

          break;
        }

        case 'game_event': {
          broadcast(
            room,
            {
              type: 'game_event',
              playerId,
              event: message.event || null,
              data: message.data || null,
              timestamp: Date.now()
            },
            playerId
          );

          break;
        }

        case 'chat': {
          const text = String(message.message || '')
            .trim()
            .slice(0, 300);

          if (!text) return;

          broadcast(room, {
            type: 'chat',
            playerId,
            name: player.name,
            message: text,
            timestamp: Date.now()
          });

          break;
        }

        case 'leave':
          removePlayer(room, playerId);
          playerId = null;
          roomCode = null;
          break;

        default:
          send(socket, {
            type: 'error',
            error: 'UNKNOWN_MESSAGE_TYPE'
          });
      }
    });

    socket.on('close', () => {
      if (!playerId || !roomCode) return;

      const room = rooms.get(roomCode);

      if (!room) return;

      const player = room.players.get(playerId);

      if (!player) return;

      player.socket = null;
      player.connected = false;

      touch(room);

      broadcast(room, {
        type: 'player_connection',
        playerId,
        connected: false
      });
    });
  });

  setInterval(() => {
    const now = Date.now();

    for (const [code, room] of rooms) {
      const inactive = now - room.lastActivity > ROOM_TTL_MS;

      if (inactive) {
        for (const player of room.players.values()) {
          send(player.socket, {
            type: 'room_expired'
          });

          try {
            player.socket?.close();
          } catch {}
        }

        rooms.delete(code);
      }
    }
  }, 60_000);

  await app.listen({
    port: PORT,
    host: HOST
  });
}

start().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
