import { z } from "zod";

// --- Host -> Server ---

export const CreateRoomMessageSchema = z.object({
  type: z.literal("create_room"),
});
export type CreateRoomMessage = z.infer<typeof CreateRoomMessageSchema>;

// --- Server -> Host ---

export const RoomCreatedMessageSchema = z.object({
  type: z.literal("room_created"),
  roomId: z.string().length(6),
});
export type RoomCreatedMessage = z.infer<typeof RoomCreatedMessageSchema>;

// --- Client -> Server ---

export const JoinRoomMessageSchema = z.object({
  type: z.literal("join_room"),
  roomId: z.string().length(6),
});
export type JoinRoomMessage = z.infer<typeof JoinRoomMessageSchema>;

// --- Server -> Client ---

export const RoomJoinedMessageSchema = z.object({
  type: z.literal("room_joined"),
  peerId: z.string(),
});
export type RoomJoinedMessage = z.infer<typeof RoomJoinedMessageSchema>;

// --- Server -> Host ---

export const PeerJoinedMessageSchema = z.object({
  type: z.literal("peer_joined"),
  peerId: z.string(),
});
export type PeerJoinedMessage = z.infer<typeof PeerJoinedMessageSchema>;

// --- SDP relay (bidirectional via server) ---

export const OfferMessageSchema = z.object({
  type: z.literal("offer"),
  sdp: z.string(),
  targetPeerId: z.string(),
});
export type OfferMessage = z.infer<typeof OfferMessageSchema>;

export const AnswerMessageSchema = z.object({
  type: z.literal("answer"),
  sdp: z.string(),
  targetPeerId: z.string(),
});
export type AnswerMessage = z.infer<typeof AnswerMessageSchema>;

// --- ICE Candidate (bidirectional via server) ---

export const IceCandidateMessageSchema = z.object({
  type: z.literal("ice_candidate"),
  candidate: z.unknown(),
  targetPeerId: z.string(),
});
export type IceCandidateMessage = z.infer<typeof IceCandidateMessageSchema>;

// --- Disconnect ---

export const LeaveRoomMessageSchema = z.object({
  type: z.literal("leave_room"),
});
export type LeaveRoomMessage = z.infer<typeof LeaveRoomMessageSchema>;

export const PeerLeftMessageSchema = z.object({
  type: z.literal("peer_left"),
  peerId: z.string(),
});
export type PeerLeftMessage = z.infer<typeof PeerLeftMessageSchema>;

// --- Error ---

export const ErrorMessageSchema = z.object({
  type: z.literal("error"),
  message: z.string(),
});
export type ErrorMessage = z.infer<typeof ErrorMessageSchema>;

// --- Device discovery (authenticated) ---

export const ConnectDeviceMessageSchema = z.object({
  type: z.literal("connect_device"),
  targetDeviceId: z.string(),
});
export type ConnectDeviceMessage = z.infer<typeof ConnectDeviceMessageSchema>;

export const DeviceListRequestSchema = z.object({
  type: z.literal("device_list_request"),
});
export type DeviceListRequest = z.infer<typeof DeviceListRequestSchema>;

export const DeviceListResponseSchema = z.object({
  type: z.literal("device_list"),
  devices: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      platform: z.string(),
      online: z.boolean(),
    })
  ),
});
export type DeviceListResponse = z.infer<typeof DeviceListResponseSchema>;

// --- Union ---

export const SignalingMessageSchema = z.discriminatedUnion("type", [
  CreateRoomMessageSchema,
  RoomCreatedMessageSchema,
  JoinRoomMessageSchema,
  RoomJoinedMessageSchema,
  PeerJoinedMessageSchema,
  OfferMessageSchema,
  AnswerMessageSchema,
  IceCandidateMessageSchema,
  LeaveRoomMessageSchema,
  PeerLeftMessageSchema,
  ErrorMessageSchema,
  ConnectDeviceMessageSchema,
  DeviceListRequestSchema,
  DeviceListResponseSchema,
]);

export type SignalingMessage = z.infer<typeof SignalingMessageSchema>;
