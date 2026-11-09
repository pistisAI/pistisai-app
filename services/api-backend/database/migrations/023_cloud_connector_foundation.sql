-- Migration: Cloud connector foundation
-- Per-user cloud connector support: device registry + presence tracking
-- See docs/architecture/SECURE_DEVICE_MESH.md

CREATE TABLE IF NOT EXISTS cloud_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id VARCHAR(64) UNIQUE NOT NULL,
  device_name VARCHAR(200),
  platform VARCHAR(50),
  app_version VARCHAR(50),
  runtime_location VARCHAR(50) NOT NULL DEFAULT 'local',
  capabilities JSONB NOT NULL DEFAULT '{}',
  status VARCHAR(20) NOT NULL DEFAULT 'offline',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cloud_devices_user_id ON cloud_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_cloud_devices_device_id ON cloud_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_cloud_devices_status ON cloud_devices(status);

CREATE TABLE IF NOT EXISTS cloud_presence (
  device_uuid UUID PRIMARY KEY REFERENCES cloud_devices(id) ON DELETE CASCADE,
  last_seen TIMESTAMP NOT NULL DEFAULT NOW(),
  runtime_available BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_cloud_presence_last_seen ON cloud_presence(last_seen);
