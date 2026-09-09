"""Local development room directory + opaque game packet relay (wire protocol 1).

No world files, profile credentials or room codes are logged. The socket owns its
sender identity; clients cannot select a sender or send to another room.
"""
import asyncio
from dataclasses import dataclass, field
import json
import os
import secrets
import struct
import time

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

MAX_PLAYERS = 6
MAX_ROOMS = 64
MAX_PACKET = 65536
MAX_QUEUE = 256
MAX_QUEUED_BYTES = 2 * 1024 * 1024
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
rooms = {}
connections = 0


@dataclass(eq=False)
class Client:
    socket: object
    peer: int
    queue: asyncio.Queue = field(default_factory=lambda: asyncio.Queue(MAX_QUEUE))
    queued_bytes: int = 0
    window: float = field(default_factory=time.monotonic)
    byte_count: int = 0
    packet_count: int = 0
    closing: bool = False
    ready: bool = False

    def send(self, value):
        if self.closing:
            return
        size = len(value)
        if self.queue.full() or self.queued_bytes + size > MAX_QUEUED_BYTES:
            self.closing = True
            asyncio.create_task(self.socket.close(1008, "slow_receiver"))
            return
        self.queued_bytes += size
        self.queue.put_nowait(value)

    def event(self, **value):
        self.send(json.dumps(value))

    async def write(self):
        while True:
            value = await self.queue.get()
            self.queued_bytes -= len(value)
            await self.socket.send(value)

    def rate_allowed(self, size):
        now = time.monotonic()
        if now - self.window >= 1:
            self.window, self.byte_count, self.packet_count = now, 0, 0
        self.byte_count += size
        self.packet_count += 1
        return self.byte_count <= 8 * 1024 * 1024 and self.packet_count <= 12000


@dataclass
class Room:
    code: str
    clients: dict = field(default_factory=dict)
    next_peer: int = 2
    ready: bool = False
    refusing: bool = False


def code_new():
    while True:
        code = "".join(secrets.choice(ALPHABET) for _ in range(12))
        if code not in rooms:
            return code


async def reject(socket, reason):
    await socket.send(json.dumps({"op": "error", "reason": reason}))
    await socket.close(1008, reason)


async def handler(socket):
    global connections
    if connections >= MAX_ROOMS * MAX_PLAYERS + 32:
        await reject(socket, "server_full")
        return
    connections += 1
    room = client = writer = None
    try:
        raw = await asyncio.wait_for(socket.recv(), timeout=8)
        if not isinstance(raw, str) or len(raw) > 512:
            await reject(socket, "invalid_request")
            return
        request = json.loads(raw)
        if not isinstance(request, dict) or request.get("protocol") != 1:
            await reject(socket, "protocol_mismatch")
            return
        if request.get("op") == "create":
            if len(rooms) >= MAX_ROOMS:
                await reject(socket, "server_full")
                return
            room = Room(code_new())
            rooms[room.code] = room
            client = Client(socket, 1)
        elif request.get("op") == "join":
            code = request.get("code")
            room = rooms.get(code) if isinstance(code, str) else None
            if room is None or not room.ready or room.refusing:
                room = None
                await reject(socket, "room_unavailable")
                return
            if len(room.clients) >= MAX_PLAYERS:
                room = None
                await reject(socket, "room_full")
                return
            client = Client(socket, room.next_peer)
            room.next_peer += 1
        else:
            await reject(socket, "invalid_request")
            return
        room.clients[client.peer] = client
        writer = asyncio.create_task(client.write())
        client.event(op="welcome", peer=client.peer, code=room.code, protocol=1)
        async for packet in socket:
            if not client.rate_allowed(len(packet)):
                await socket.close(1008, "rate_limit")
                break
            if client.peer != 1 and 1 not in room.clients:
                await socket.close(1001, "host_left")
                break
            if isinstance(packet, str):
                if len(packet) > 512:
                    await socket.close(1008, "invalid_request")
                    break
                message = json.loads(packet)
                if not isinstance(message, dict):
                    await socket.close(1008, "invalid_request")
                    break
                op = message.get("op")
                if op == "ready" and not client.ready:
                    client.ready = True
                    if client.peer == 1:
                        room.ready = True
                    else:
                        room.clients[1].event(op="peer_joined", peer=client.peer)
                        client.event(op="peer_joined", peer=1)
                elif op == "kick" and client.peer == 1:
                    target = message.get("peer")
                    if isinstance(target, int) and target != 1 and target in room.clients:
                        await room.clients[target].socket.close(1008, "removed")
                elif op == "refuse" and client.peer == 1:
                    room.refusing = bool(message.get("value"))
                else:
                    await socket.close(1008, "invalid_request")
                    break
                continue
            if not client.ready or not 6 < len(packet) <= MAX_PACKET + 6:
                await socket.close(1008, "invalid_packet")
                break
            target, channel, mode = struct.unpack_from("<iBB", packet)
            if channel > 3 or mode > 2:
                await socket.close(1008, "invalid_packet")
                break
            # Star topology: guests may only reach the authoritative host.
            if client.peer != 1:
                if target not in (0, 1):
                    await socket.close(1008, "invalid_target")
                    break
                destinations = [room.clients[1]]
            else:
                destinations = [c for pid, c in room.clients.items()
                                if pid != 1 and (target == 0 or pid == target or (target < 0 and pid != -target))]
            forwarded = struct.pack("<iBB", client.peer, channel, mode) + packet[6:]
            for destination in destinations:
                destination.send(forwarded)
    except (ConnectionClosed, asyncio.TimeoutError, ValueError, TypeError):
        pass
    finally:
        if room and client:
            room.clients.pop(client.peer, None)
            if client.peer == 1:
                rooms.pop(room.code, None)
                await asyncio.gather(*(c.socket.close(1001, "host_left") for c in list(room.clients.values())), return_exceptions=True)
            elif 1 in room.clients:
                room.clients[1].event(op="peer_left", peer=client.peer)
        if writer:
            writer.cancel()
            await asyncio.gather(writer, return_exceptions=True)
        connections -= 1


def health(connection, request):
    if request.path == "/health":
        return connection.respond(200, "ok\n")
    if request.path != "/relay":
        return connection.respond(404, "not found\n")


async def main():
    host = os.environ.get("CREW_RELAY_BIND", "127.0.0.1")
    port = int(os.environ.get("CREW_RELAY_PORT", "24680"))
    async with serve(handler, host, port, process_request=health,
                     max_size=MAX_PACKET + 6, max_queue=32,
                     compression=None, ping_interval=15, ping_timeout=20):
        print(f"Crew relay protocol 1 listening on {host}:{port} (/relay, /health)", flush=True)
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Crew relay stopped. Open rooms have expired.")
    except OSError as exc:
        raise SystemExit(f"초대 서버 실행 실패: {exc}. 같은 포트의 서버가 이미 켜져 있는지 확인하세요.")
