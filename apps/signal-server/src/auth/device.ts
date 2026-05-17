import { config } from "../config.js";

export interface Device {
  id: string;
  user_id: string;
  device_name: string;
  platform: string;
  last_seen: string;
}

// In-memory device registry for devices connected to this server.
// For multi-instance deployments, replace with Supabase queries.
const connectedDevices = new Map<
  string,
  { userId: string; deviceName: string; platform: string; ws: any }
>();

export class DeviceManager {
  register(
    deviceId: string,
    userId: string,
    deviceName: string,
    platform: string,
    ws: any
  ): void {
    connectedDevices.set(deviceId, { userId, deviceName, platform, ws });
  }

  unregister(deviceId: string): void {
    connectedDevices.delete(deviceId);
  }

  getDevicesForUser(userId: string): Array<{
    id: string;
    name: string;
    platform: string;
    online: boolean;
  }> {
    const devices: Array<{
      id: string;
      name: string;
      platform: string;
      online: boolean;
    }> = [];
    for (const [id, info] of connectedDevices) {
      if (info.userId === userId) {
        devices.push({
          id,
          name: info.deviceName,
          platform: info.platform,
          online: true,
        });
      }
    }
    return devices;
  }

  getDevice(deviceId: string): {
    userId: string;
    deviceName: string;
    platform: string;
    ws: any;
  } | null {
    return connectedDevices.get(deviceId) ?? null;
  }
}

export const deviceManager = new DeviceManager();
