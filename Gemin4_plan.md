Part 1: Architectural Critique of v2.3 (What's Great & What Needs Fixing)Your v2.3 plan is already better than 90% of commercial OBD app specs on the market. Isolating the Transport interface, separating pure TypeScript OBD core logic from React Native, using Skia for 60fps gauges, and using the OS Share Sheet for zero-cost Ask AI are all spot-on engineering decisions.   However, before you write a single line of code, there are seven hidden hardware/protocol landmines in v2.3 that will cause real-world bugs if not addressed in the architecture now:Missing BLE GATT Service/Characteristic Discovery: Unlike Classic Bluetooth (RFCOMM) or Wi-Fi (TCP sockets), BLE does not have a standard "serial port" profile. Every adapter vendor uses different GATT UUIDs:Vgate iCar Pro BLE: Service 18F0 (Write 2AF1, Notify 2AF0)Veepeak / Generic HM-10 clones: Service FFE0 (R/W/Notify FFE1)OBDLink CX: Service FFF0 (Write FFF2, Notify FFF1)Fix: Your BleTransport needs an Auto-UUID Matcher table + a fallback heuristic that scans all services on an unknown BLE device and picks the pair of [Write/WriteWithoutResponse] and [Notify/Indicate] characteristics.BLE 20-Byte MTU Truncation: Default BLE 4.0 packets are capped at 20 bytes. A multi-frame response like a VIN (Mode 09 PID 02) is ~60+ ASCII characters and will arrive across 3–4 separate BLE notification callbacks before the > prompt arrives.Fix: BleTransport must call requestMTU(512) on Android upon connection (iOS negotiates ~185 bytes automatically) and feed chunks into a ring buffer that only resolves the command promise when > is seen or a timeout hits.Wi-Fi "No Internet" Cellular Drop on iOS/Android: When a user connects to a Wi-Fi ELM327 (192.168.0.10), the phone sees an open Wi-Fi router with no internet. If they then tap online VIN decode or Ask AI, the request will hang or fail because the OS routes traffic to the dead OBD Wi-Fi.   Fix: Cache the NHTSA VIN decode the moment they get back on cellular/home Wi-Fi, and in the Ask AI sheet, detect if transport.kind === 'wifi' and show a one-tap banner: "Connected to Wi-Fi Adapter (No Internet). Copy prompt now, disconnect Wi-Fi, then paste into your AI app."High-Frequency Rendering Bottleneck (Zustand → Reanimated): If you push 15 Hz PID updates through React state (Zustand), React will re-render the component tree 15 times a second, dropping frames and heating up the phone.   Fix: Use Zustand only for connection state, dashboard layout, and slow status. Pipe live high-frequency PID values directly from LiveDataService into Reanimated SharedValues (useSharedValue), which drive your @shopify/react-native-skia canvas directly on the UI thread at 60–120fps with zero React re-renders.ISO-TP Multi-Frame Confusion (ATH0 vs ATH1): In section 7.2 you initialize with ATH0 (headers off), and in 7.3 you note that multi-ECU responses should prefer 7E8 (with headers on). Without headers (ATH0), if both the Engine (7E8) and Transmission (7E9) respond to 0100 or 03 (DTCs), you cannot reliably tell which byte mask or multi-frame sequence belongs to which module.   Fix: Run ATH1 (Headers ON) and ATS0 (Spaces OFF) during init, PID discovery, VIN read, and DTC scans so you can deterministically group frames by ECU address (7E8, 7E9, 7EA). Switch to ATH0 (Headers OFF) only during high-speed Live Polling (or lock the target header via ATSH 7E0) to save serial bandwidth.SQLite I/O Wear & Battery Drain During Recording: Writing every individual sample (INSERT INTO samples...) at 10–15 Hz directly to SQLite causes 600–900 disk transactions per minute.   Fix: Use an in-memory buffer inside LogService that flushes a single batched BEGIN TRANSACTION; INSERT...; COMMIT; every 2.0 seconds (or immediately on AppState backgrounding / disconnect). You keep crash-safety without thrashing flash storage.BMW Ediabas / UDS Reality in TypeScript: Section 6.9 mentions .prg/.grp files. .prg files are compiled binary BEST/2 virtual machine bytecode—porting a full BEST/2 interpreter to pure TypeScript is a massive 6-month side quest.   Fix: For your BMW Pack (E9x/E6x/F-series/G-series), use UDS over ISO-TP (Service 0x22 ReadDataByIdentifier, 0x2E WriteDataByIdentifier, 0x31 RoutineControl) defined in clean JSON catalog files. That covers 95% of BMW CBS service resets, battery registration, exhaust flap control, and common F/G-series coding parameters without touching proprietary .prg binaries.Part 2: Complete Technical & System Design (v3.0 Master Blueprint)Below is the complete, production-ready system design and full specification that upgrades v2.3 into an engineering blueprint you can build straight from.1. Visual Design System & UI Specification ("Apple Automotive" Aesthetic)1.1 Color Palette & Tokens (Dark-First Automotive Theme)Car cabins require high contrast, zero glare at night, and instant peripheral color recognition.TokenDark Mode (Default in Car)Light ModeUsagebg.canvas#000000 (True OLED Black)#F2F2F7Main screen backgroundbg.card#1C1C1E#FFFFFFInset grouped cards, Gauge tilesbg.elevated#2C2C2E#E5E5EAModals, Bottom Sheets, segmented controlstext.primary#FFFFFF#000000Primary titles, digital gauge readoutstext.secondary#8E8E93#6C6C70Units (rpm, km/h), PID labels, timestampsaccent.brand#0A84FF (iOS System Blue)#007AFFPrimary CTAs, Quick Scan button, active tabstatus.good#30D158 (System Green)#34C759Connected chip, "Ready" monitor, Pass statusstatus.warn#FF9F0A (System Amber)#FF9500Pending DTC, Incomplete monitor, Warm thresholdstatus.crit#FF453A (System Red)#FF3B30Stored/Permanent DTC, MIL ON, Redline/Overheat1.2 Typography & NumericsUI Text: System Default (SF Pro on iOS, Roboto on Android).   Live Digital Gauges & DTC Codes: SF Mono / Roboto Mono with fontVariant: ['tabular-nums']. Crucial: Without tabular-nums, numbers jitter horizontally as RPM or speed changes rapidly.1.3 Detailed Screen Wireframes & Component StatesA. Home Tab (app/(tabs)/home.tsx)┌──────────────────────────────────────────────────────────┐
│ [Garage: 2016 BMW 328i ▾]                        [🟢 8Hz]│ ← Header: Vehicle Switcher + Live Link Pill
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ ● Connected · Vgate iCar Pro BLE           12.6V  ›  │ │ ← Tappable Adapter & Port Voltage Strip
│ │   VIN: WBA8E9G5... (Confirmed) · ISO 15765-4 CAN     │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │                     (  ⚡  )                         │ │
│ │                   QUICK SCAN                         │ │ ← Hero Button (Haptic Medium on press)
│ │        Read Codes, Readiness, Freeze Frame & Battery │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ HEALTH SUMMARY · Today, 2:45 PM                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ ⚠️  ATTENTION NEEDED                      [MIL OFF]  │ │
│ │ ──────────────────────────────────────────────────── │ │
│ │ • 0 Stored Codes · 1 Pending Code (P0171)            │ │
│ │ • 7/8 Readiness Monitors Ready (EVAP Incomplete)     │ │
│ │ • Battery Health: 12.6V Rest / 14.2V Charging (Good) │ │
│ │                                                      │ │
│ │ [ ✨ Ask AI ]                     [ 📄 Share PDF ]   │ │ ← Instant Action Bar
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ VEHICLE TOOLS (Loaded for BMW F30)                       │
│ ┌─────────────────────────┐  ┌─────────────────────────┐ │
│ │ 🔋 Battery / Crank Test │  │ 🛠 BMW Service Reset ›  │ │
│ └─────────────────────────┘  └─────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
B. Live Dashboard Tab (app/(tabs)/live.tsx)Top Bar: [Page 1 of 3 •••] | [14.2 Hz] badge | [🔴 REC 00:00] button | [Edit] button.Grid System: 6-column virtual grid per swipeable page.1x1 Tile (2 cols wide): Digital Readout (Label + Huge Tabular Number + Unit + Min/Max).2x2 Tile (3 cols wide): Skia Circular Sweep Gauge (240° arc, dynamic color zone, needle or glowing arc fill, peak-hold tick mark).Full-Width Tile (6 cols wide): Rolling 30-second Skia Bezier Line Graph (supports 1 or 2 overlaid PIDs with dual Y-axes, e.g., RPM vs. Boost/MAP).C. Ask AI Bottom Sheet (app/sheets/ask-ai.tsx)Header: Ask AI Assistant | [Close].Wi-Fi Warning Banner (Conditional): Appears only if connected via Wi-Fi TCP adapter (192.168.0.10), reminding user to copy prompt before switching back to mobile data.Symptoms Input: Multi-line text input with quick-tap symptom chips: [Rough Idle] [Hard Start] [Loss of Power] [Poor Fuel Economy] [Stalling].Privacy & Context Toggles: Compact horizontal pill toggles: [✓ Car Info] [✓ Codes (2)] [✓ Freeze Frame] [✓ Readiness] [+ Live Snapshot] [🔒 Hide VIN (Default)].   Collapsible Live Prompt Box: Monospace preview box where user can inspect or manually edit the exact text before sending.   Sticky Bottom Action Bar:Primary: [ 📤 Share to AI App... ] (triggers native OS share sheet)   Secondary: [ 📋 Copy Prompt ] (copies + triggers haptic + toast)   2. Low-Level Protocol & Transport Engineering2.1 BLE Auto-Discovery Profile Table (src/transports/bleProfiles.ts)To make BLE work out-of-the-box on both iPhone and Android without asking the user for UUIDs, BleTransport iterates through this known dictionary first, then falls back to dynamic characteristic inspection:TypeScriptexport interface BleGattProfile {
  name: string;
  serviceUuid: string;
  writeUuid: string;
  notifyUuid: string;
  preferWriteWithoutResponse: boolean;
}

export const KNOWN_BLE_PROFILES: BleGattProfile[] = [
  {
    name: 'Vgate iCar Pro / IOS-Vlink',
    serviceUuid: '000018f0-0000-1000-8000-00805f9b34fb',
    writeUuid:   '00002af1-0000-1000-8000-00805f9b34fb',
    notifyUuid:  '00002af0-0000-1000-8000-00805f9b34fb',
    preferWriteWithoutResponse: true,
  },
  {
    name: 'Veepeak / Carista / Generic FFE0',
    serviceUuid: '0000ffe0-0000-1000-8000-00805f9b34fb',
    writeUuid:   '0000ffe1-0000-1000-8000-00805f9b34fb',
    notifyUuid:  '0000ffe1-0000-1000-8000-00805f9b34fb',
    preferWriteWithoutResponse: true,
  },
  {
    name: 'OBDLink CX / vLinker BLE',
    serviceUuid: '0000fff0-0000-1000-8000-00805f9b34fb',
    writeUuid:   '0000fff2-0000-1000-8000-00805f9b34fb',
    notifyUuid:  '0000fff1-0000-1000-8000-00805f9b34fb',
    preferWriteWithoutResponse: false,
  },
  {
    name: 'Nordic UART Service (NUS)',
    serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
    writeUuid:   '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
    notifyUuid:  '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
    preferWriteWithoutResponse: true,
  },
];
2.2 The ELM327 Command Queue & Framing State Machine (src/core/elm327/CommandQueue.ts)ELM327 is strictly half-duplex. Sending a second command before > arrives corrupts the UART buffer and causes STOPPED or garbage bytes.   TypeScriptexport type CommandPriority = 'IMMEDIATE' | 'USER_ACTION' | 'POLL_FAST' | 'POLL_SLOW';

export interface QueuedCommand {
  id: string;
  rawCommand: string;         // e.g. "010C" or "ATRV"
  priority: CommandPriority;
  timeoutMs: number;          // e.g. 2500ms for 0100, 400ms for live PIDs
  resolve: (lines: string[]) => void;
  reject: (err: ObdError) => void;
}
Framing Rules inside CommandQueue:Append \r to outgoing command.   Accumulate incoming ASCII chunks from Transport.onData into rxBuffer.   Wait until rxBuffer.includes('>').   Extract everything before >, split by \r or \n, strip whitespace, strip echoed command (if ATE0 failed on a bad clone), strip SEARCHING....   Classify terminal error tokens (NO DATA, UNABLE TO CONNECT, CAN ERROR, BUS INIT...ERROR, STOPPED, ?) into typed ObdErrorCode values rather than throwing generic strings.   2.3 ISO-TP (ISO 15765-2) Multi-Frame Reassembler (src/core/obd/isotp.ts)When reading a VIN (0902) or multiple DTCs (03), CAN frames exceed 7 data bytes. With ATH1 (Headers On) and ATS0 (Spaces Off), an ECU (7E8) replies in ISO-TP format:   7E81014490201574241   <-- First Frame (10 = FF, 14 = 20 bytes total, 49 02 01 = Mode 09 PID 02, "WBA")
7E82138453947353132   <-- Consecutive Frame 1 (21 = CF seq 1, "8E9G512")
7E82233343536373839   <-- Consecutive Frame 2 (22 = CF seq 2, "3456789")
Your parser must handle both raw ISO-TP frames (when ATH1 is active) and ELM327 pre-formatted indexed lines (0: 490201..., 1: ... when ATH0 is active), grouping by ECU header (7E8) first before reassembling the byte payload.   2.4 Priority-Tiered & Multi-PID Polling Scheduler (src/core/obd/PollScheduler.ts)To double your refresh rate on modern CAN cars (2008+):Multi-PID Packing (SAE J1979): CAN allows requesting up to 6 PIDs in a single Mode 01 frame (e.g., 01 0C 0D 04 11 requests RPM, Speed, Load, and Throttle in one round-trip instead of four).   Fallback: During init, send a test 2-PID probe (010C0D). If the ECU returns a valid combined response, enable multiPidSupported = true for that vehicle profile; if it returns ? or NO DATA (older ISO9141 / KWP2000 cars), fall back to single-PID polling.Cycle Pattern:
[Fast Pack] → [Fast Pack] → [Medium Pack] → [Fast Pack] → [Fast Pack] → [Slow Pack].   3. Complete SQLite Schema & High-Speed Storage (src/db/schema.sql)Use expo-sqlite with WAL (Write-Ahead Logging) enabled (PRAGMA journal_mode = WAL;) so background log writes never block UI reads.   SQLPRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS vehicles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  vin TEXT,
  vin_source TEXT CHECK(vin_source IN ('ecu', 'manual')) DEFAULT 'ecu',
  make TEXT,
  model TEXT,
  year INTEGER,
  platform_code TEXT,          -- e.g., 'F30', 'E90'
  preferred_adapter_id TEXT,
  protocol TEXT,
  supported_pids_json TEXT,    -- JSON array of supported Mode 01 PIDs
  responding_ecus_json TEXT,   -- e.g., '["7E8","7E9"]'
  dashboard_layout_json TEXT,  -- Custom pages/tiles
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS scans (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  scanned_at_utc INTEGER NOT NULL,
  timezone TEXT NOT NULL,
  vin_snapshot TEXT,
  mil_on INTEGER NOT NULL,     -- 0 or 1
  dtc_count INTEGER NOT NULL,
  dtcs_json TEXT NOT NULL,     -- Stored, Pending, Permanent array
  freeze_frame_json TEXT,
  readiness_json TEXT,
  battery_volts REAL,
  cleared_at_utc INTEGER
);

CREATE TABLE IF NOT EXISTS recordings (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  started_at_utc INTEGER NOT NULL,
  ended_at_utc INTEGER,
  pids_json TEXT NOT NULL,
  sample_count INTEGER DEFAULT 0,
  summary_stats_json TEXT      -- min/max/avg per PID computed on close
);

CREATE TABLE IF NOT EXISTS samples (
  recording_id TEXT NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
  t_offset_ms INTEGER NOT NULL, -- ms since started_at_utc (saves space vs full epoch)
  pid INTEGER NOT NULL,
  val REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_samples_rec_time ON samples(recording_id, t_offset_ms);

-- Bundled Read-Only Reference DB (copied from assets on first launch)
CREATE TABLE IF NOT EXISTS dtc_dictionary (
  code TEXT NOT NULL,
  make TEXT NOT NULL DEFAULT 'GENERIC', -- 'GENERIC', 'BMW', 'FORD', etc.
  title TEXT NOT NULL,
  severity TEXT CHECK(severity IN ('info', 'caution', 'serious')) NOT NULL,
  causes_json TEXT,
  PRIMARY KEY (code, make)
);
   4. Clean Licensing Strategy for the Offline DTC DatabaseIn Section 7.7 you rightly flagged DTC database licensing. Many GitHub repos scrape copyrighted repair manuals or use GPLv3 licenses (which cannot be legally bundled into an iOS App Store binary due to Apple's DRM restrictions).   How to build a 100% commercially clean DTC DB:Use the public SAE J2012 standard code definitions for generic P0xxx, P2xxx, P34xx, B0xxx, C0xxx, and U0xxx ranges.Write a one-time offline Python/Node script during development that uses an LLM to rewrite the public SAE technical labels into original, consumer-friendly plain-English summaries, severity tiers (info / caution / serious), and generic inspection steps.   Store the resulting SQLite file in assets/dtc/codes_v1.db. You now own 100% of the copyright to the prose descriptions and can sell the app commercially without GPL or scraping risk.   5. Upgraded Execution Roadmap (From Day 1 to Store Launch)Instead of waiting until M1 to test UI and M7 to test transports, build the Simulator & Core Engine first so you can develop 90% of the app at your desk at 60fps without sitting in a driveway burning gas.   Phase 1: Pure TS Core & Desktop Simulator (Days 1–5)Deliverable: src/core/ (100% pure TypeScript, zero React Native dependencies).   Build CommandQueue, Elm327Parser, IsoTpReassembler, DtcDecoder, PidRegistry (all Mode 01 formulas + unit converters), and buildAiPrompt().   Build SmartMockTransport: A simulated car in TypeScript that responds to ATZ, 0100, 0902 (returns a real VIN), 03 (returns P0301 + P0171), and generates smooth sine-wave RPM, Speed, and Coolant Temp in real time.   Run Jest unit tests across 100% of formulas and dirty clone responses (SEARCHING..., NO DATA, split BLE 20-byte chunks).   Phase 2: App Shell, SQLite & "Quick Scan" Vertical Slice (Days 6–10)Deliverable: Expo Prebuild app running on iPhone & Android against SmartMockTransport.   Set up Expo Router 5-tab layout (Home, Live, Codes, Logs, Settings) with native SF Symbols.   Implement ScanService (Quick Scan state machine: Connect → Init → Read VIN → Decode Offline WMI/Year → Read Codes → Read Freeze Frame → Read Readiness → Read Voltage → Save to SQLite).   Build the Ask AI Sheet and PDF Report Generator (expo-print).   Phase 3: Real Hardware Transports (BLE + Android Classic + Wi-Fi) (Days 11–16)Deliverable: Real car connection in your driveway.   Implement BleTransport with KNOWN_BLE_PROFILES + dynamic GATT discovery + requestMTU(512).Implement ClassicTransport (Android) and WifiTcpTransport (192.168.0.10:35000).   Build the In-App Raw TX/RX Terminal & Flight Recorder in Settings so every single byte sent/received in your real car can be exported with one tap if an adapter misbehaves.   Phase 4: 60fps Skia Live Dashboard & Batched Recorder (Days 17–22)Deliverable: High-frequency gauges and trip logging.   Build the Reanimated SharedValue bridge so PollScheduler updates Skia gauges without React re-renders.Build the 2-second batched SQLite LogService recorder and the scrubbable post-drive replay chart.   Phase 5: Vehicle Profile Registry & BMW Personal Pack (Days 23–28)Deliverable: Make-aware tool loader (src/services/ToolRegistry.ts).   Add the Battery Cranking Voltage Drop Test (polls ATRV at maximum speed ~20Hz while the user starts the engine, capturing minimum cranking voltage—if < 9.6V, flags weak battery; if charging < 13.5V, flags alternator).   Add JSON-driven UDS (0x22/0x2E/0x31) service reset module for your personal car behind a developer toggle.   Next Step: Let's Lock In Your Hardware Setup