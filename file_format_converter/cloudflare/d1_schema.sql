-- Cloudflare D1 schema for file_converter_db
-- Run this once in the Cloudflare D1 console or via wrangler:
--   wrangler d1 execute file_converter_db --file=cloudflare/d1_schema.sql

CREATE TABLE IF NOT EXISTS user_devices (
    device_id              TEXT PRIMARY KEY,
    device_model           TEXT,
    brand                  TEXT,
    os_version             TEXT,
    app_version            TEXT,
    plan                   TEXT DEFAULT 'free',
    total_conversions      INTEGER DEFAULT 0,
    conversions_by_type    TEXT DEFAULT '{}',   -- stored as JSON string
    ip_address             TEXT,
    email                  TEXT,
    session_count          INTEGER DEFAULT 0,
    first_seen             TEXT,
    last_seen              TEXT,
    plan_updated_at        TEXT,
    force_logout           INTEGER DEFAULT 0    -- 0=false, 1=true
);

CREATE INDEX IF NOT EXISTS idx_user_devices_plan ON user_devices(plan);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_seen ON user_devices(last_seen);

-- Failover log table
CREATE TABLE IF NOT EXISTS failover_log (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp         TEXT NOT NULL,
    from_provider     TEXT NOT NULL,
    to_provider       TEXT NOT NULL,
    reason            TEXT
);
