-- ==============================================================================
-- iCAR Professional Cloud Database Schema (Supabase / PostgreSQL)
-- Multi-Vehicle Diagnostics, Telemetry, and Fleet Management Backend
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Vehicles Registry Table (Keyed by 17-character VIN)
CREATE TABLE IF NOT EXISTS public.vehicles (
    vin VARCHAR(17) PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL,
    engine VARCHAR(100),
    bus_protocol VARCHAR(100),
    resting_voltage NUMERIC(4, 2),
    last_scanned_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Index for fast lookup by make/model and scan date
CREATE INDEX IF NOT EXISTS idx_vehicles_last_scanned ON public.vehicles (last_scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicles_make_model ON public.vehicles (make, model);

-- 3. Diagnostic Scans History Table
CREATE TABLE IF NOT EXISTS public.diagnostic_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vin VARCHAR(17) NOT NULL REFERENCES public.vehicles(vin) ON DELETE CASCADE,
    scan_timestamp TIMESTAMPTZ DEFAULT now(),
    total_faults_count INTEGER DEFAULT 0,
    stored_dtcs_count INTEGER DEFAULT 0,
    pending_dtcs_count INTEGER DEFAULT 0,
    permanent_dtcs_count INTEGER DEFAULT 0,
    readiness_passed INTEGER DEFAULT 0,
    readiness_total INTEGER DEFAULT 8,
    battery_voltage NUMERIC(4, 2),
    battery_soc INTEGER,
    registered_battery_type VARCHAR(50),
    dtcs JSONB DEFAULT '[]'::jsonb,
    ecu_breakdown JSONB DEFAULT '[]'::jsonb,
    cbs_intervals JSONB DEFAULT '[]'::jsonb,
    full_report_text TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast history lookup per vehicle
CREATE INDEX IF NOT EXISTS idx_scans_vin_timestamp ON public.diagnostic_scans (vin, scan_timestamp DESC);

-- 4. Vehicle Convenience Settings Snapshot Table
CREATE TABLE IF NOT EXISTS public.vehicle_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vin VARCHAR(17) NOT NULL REFERENCES public.vehicles(vin) ON DELETE CASCADE,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(vin)
);

-- 5. Row Level Security (RLS) Configuration
-- Configured for anonymous/authenticated access for the iCAR app and future web dashboard
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diagnostic_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_settings ENABLE ROW LEVEL SECURITY;

-- Allow read & write with public anon key for now (user auth will be layered on later)
CREATE POLICY "Allow public read-write for vehicles" ON public.vehicles
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow public read-write for diagnostic_scans" ON public.diagnostic_scans
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow public read-write for vehicle_settings" ON public.vehicle_settings
    FOR ALL USING (true) WITH CHECK (true);
