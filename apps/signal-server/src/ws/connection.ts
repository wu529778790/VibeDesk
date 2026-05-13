import type { WebSocket } from "ws";

export function handleConnection(ws: WebSocket): void {
  ws.on("message", (raw) => {
    ws.send(JSON.stringify({ type: "error", message: "Not implemented" }));
  });
}
