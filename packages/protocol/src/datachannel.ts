import { z } from "zod";

// --- Mouse control (Client → Host) ---

export const MouseMoveMessageSchema = z.object({
  type: z.literal("mouse_move"),
  x: z.number(),
  y: z.number(),
});
export type MouseMoveMessage = z.infer<typeof MouseMoveMessageSchema>;

export const MouseDownMessageSchema = z.object({
  type: z.literal("mouse_down"),
  x: z.number(),
  y: z.number(),
  button: z.enum(["left", "right", "middle"]),
});
export type MouseDownMessage = z.infer<typeof MouseDownMessageSchema>;

export const MouseUpMessageSchema = z.object({
  type: z.literal("mouse_up"),
  x: z.number(),
  y: z.number(),
  button: z.enum(["left", "right", "middle"]),
});
export type MouseUpMessage = z.infer<typeof MouseUpMessageSchema>;

export const MouseWheelMessageSchema = z.object({
  type: z.literal("mouse_wheel"),
  x: z.number(),
  y: z.number(),
  deltaX: z.number(),
  deltaY: z.number(),
});
export type MouseWheelMessage = z.infer<typeof MouseWheelMessageSchema>;

// --- Keyboard control (Client → Host) ---

export const KeyDownMessageSchema = z.object({
  type: z.literal("key_down"),
  key: z.string(),
  modifiers: z.array(z.enum(["shift", "ctrl", "alt", "meta"])),
});
export type KeyDownMessage = z.infer<typeof KeyDownMessageSchema>;

export const KeyUpMessageSchema = z.object({
  type: z.literal("key_up"),
  key: z.string(),
  modifiers: z.array(z.enum(["shift", "ctrl", "alt", "meta"])),
});
export type KeyUpMessage = z.infer<typeof KeyUpMessageSchema>;

// --- Clipboard (Client → Host) ---

export const ClipboardMessageSchema = z.object({
  type: z.literal("clipboard"),
  text: z.string(),
});
export type ClipboardMessage = z.infer<typeof ClipboardMessageSchema>;

// --- File transfer (bidirectional) ---

export const FileTransferStartMessageSchema = z.object({
  type: z.literal("file_transfer_start"),
  name: z.string(),
  size: z.number(),
});
export type FileTransferStartMessage = z.infer<
  typeof FileTransferStartMessageSchema
>;

export const FileTransferChunkMessageSchema = z.object({
  type: z.literal("file_transfer_chunk"),
  data: z.string(), // base64
  index: z.number(),
});
export type FileTransferChunkMessage = z.infer<
  typeof FileTransferChunkMessageSchema
>;

export const FileTransferEndMessageSchema = z.object({
  type: z.literal("file_transfer_end"),
});
export type FileTransferEndMessage = z.infer<
  typeof FileTransferEndMessageSchema
>;

// --- Union ---

export const DataChannelMessageSchema = z.discriminatedUnion("type", [
  MouseMoveMessageSchema,
  MouseDownMessageSchema,
  MouseUpMessageSchema,
  MouseWheelMessageSchema,
  KeyDownMessageSchema,
  KeyUpMessageSchema,
  ClipboardMessageSchema,
  FileTransferStartMessageSchema,
  FileTransferChunkMessageSchema,
  FileTransferEndMessageSchema,
]);

export type DataChannelMessage = z.infer<typeof DataChannelMessageSchema>;
