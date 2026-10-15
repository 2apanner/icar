# iCAR — Master Product Requirements Document (PRD)

**Document Version:** 3.0 (Master Unified Specification)  
**Status:** Approved Architectural Blueprint  
**Platforms:** iOS & Android (Single Codebase: React Native + Expo Dev Client)  
**Author / Engineering Stakeholders:** iCAR Core Architecture Group  
**Supersedes:** `car_scan_calude_plan_v2_3.md`, `Gemin4_plan.md`, `plan_chatgpt.md`

---

## 1. Executive Summary & Product Vision

**iCAR** is a high-performance, calm, trustworthy automotive OBD-II scanner and diagnostic suite built for mobile devices. Unlike conventional OBD apps that suffer from cluttered, dated web-view UIs, aggressive subscription paywalls, and brittle protocol handling that crashes on cheap adapter clones, iCAR is engineered to an **"Apple Automotive"** standard:
1. **Calm, One-Tap Clarity:** One primary action on Home (**Quick Scan**) produces an immediate, plain-language vehicle health status backed by immutable diagnostic data.
2. **Native Performance & Zero-Glare Ergonomics:** 60–120 fps hardware-accelerated gauges driven by direct UI-thread rendering (`@shopify/react-native-skia` + `react-native-reanimated`), packaged in a true OLED-black, high-contrast cabin design system.
3. **Zero Cloud API Cost & Complete Privacy:** Local-first architecture. All databases, logs, and diagnostic decoders live on-device. Advanced AI diagnostics use **Ask AI OS Handoff**—generating structured diagnostic prompts handed to the user's installed AI app (ChatGPT, Claude, Gemini) via the native system share sheet with zero backend servers or recurring API costs.
4. **Hardened Protocol Engine:** Pure TypeScript OBD core isolated from the UI, featuring half-duplex command queuing, BLE 20-byte MTU ring-buffering, multi-vendor GATT profile matching, ISO-TP multi-frame reassembly, and robust tolerance for clone quirks.

---

## 2. Platform Realities & Target Boundaries

### 2.1 Adapter Compatibility Matrix

| Transport Type | iOS (iPhone) | Android | Architectural Handling |
| :--- | :--- | :--- | :--- |
| **Bluetooth Low Energy (BLE 4.0/5.x)** | Supported | Supported | Primary cross-platform transport. Auto-matches GATT UUIDs; handles 20-byte MTU fragmentation. |
| **Wi-Fi ELM327 (TCP Socket)** | Supported | Supported | Configurable IP/port (default `192.168.0.10:35000`). Handles cellular drop / "No Internet" routing. |
| **Bluetooth Classic (RFCOMM)** | **Not Supported** | Supported | Android-only fallback via `react-native-bluetooth-classic`. Apple restricts Classic SPP to MFi hardware. |
| **Dual-Mode Adapters** (e.g. Vgate iCar Pro BLE) | Supported (via BLE) | Supported | Automatically directs iOS to BLE; permits BLE or Classic on Android. |

> [!IMPORTANT]
> **Onboarding Rule:** The app must explicitly guide the user through their adapter type. If an iOS user attempts to connect to a Classic Bluetooth adapter, iCAR displays a friendly explanatory dialog clarifying Apple's hardware policy before they encounter a connection failure.

### 2.2 Scope Boundaries (v1 vs. Post-v1)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        iCAR v1 Core Release Scope                      │
├────────────────────────────────────────────────────────────────────────┤
│ • Generic OBD-II Modes: 01 (Live), 02 (Freeze Frame), 03 (Stored DTCs),│
│   04 (Safe Clear + Snapshot), 07 (Pending DTCs), 09 (VIN), 0A (Perm)   │
│ • Transports: BLE (iOS/Android), Wi-Fi TCP, Android Classic Bluetooth │
│ • 5-Tab Native Navigation: Home, Live, Codes, Logs, Settings           │
│ • 60fps Skia Live Dashboard with Reanimated SharedValue pipeline       │
│ • Ask AI OS Share Sheet Handoff (Zero API keys, privacy toggles)       │
│ • High-Frequency Battery Cranking Voltage Drop Test (ATRV at ~20 Hz)   │
│ • Offline Bundled DTC Dictionary (SAE J2012 + clean plain-text prose)  │
│ • Continuous Batched Logging & Scrubbable Session Replay               │
│ • PDF Diagnostic Reports & CSV Raw Export                              │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Deferred Post-v1
┌──────────────────────────────────▼─────────────────────────────────────┐
│ • Make-Specific UDS Pack (BMW Service Reset via JSON-driven UDS)      │
│ • Mode 06 On-Board Monitoring Tests (Advanced component diagnostics)   │
│ • Apple CarPlay / Android Auto Display Entitlements                    │
│ • Bidirectional Mode 08 Actuator Control (Safety/Liability Gated)      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Seven Architectural Pillars (Resolved Protocol Landmines)

iCAR resolves seven critical hardware and protocol failure points identified across real-world automotive implementations:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       7 CRITICAL PROTOCOL LANDMINES                     │
├────────────────────────────────────┬────────────────────────────────────┤
│ Landmine                           │ Engineering Solution               │
├────────────────────────────────────┼────────────────────────────────────┤
│ 1. BLE Vendor UUID Chaos           │ KNOWN_BLE_PROFILES Table + dynamic │
│                                    │ Notify/Write characteristic probe  │
├────────────────────────────────────┼────────────────────────────────────┤
│ 2. BLE 20-Byte Packet Truncation   │ Android requestMTU(512) + RX ring  │
│                                    │ buffer accumulating until '>' seen │
├────────────────────────────────────┼────────────────────────────────────┤
│ 3. Wi-Fi "No Internet" Cell Drop   │ Pre-cache VIN data + prompt copy   │
│                                    │ banner before AI share sheet       │
├────────────────────────────────────┼────────────────────────────────────┤
│ 4. 15 Hz React Render Thrashing    │ Bypass React state: LiveDataService│
│                                    │ → Reanimated SharedValue → Skia    │
├────────────────────────────────────┼────────────────────────────────────┤
│ 5. ISO-TP Multi-ECU Collision      │ ATH1 (Headers ON) during init/DTCs │
│                                    │ to isolate 7E8 Engine vs 7E9 Trans │
├────────────────────────────────────┼────────────────────────────────────┤
│ 6. SQLite I/O Battery Wear         │ 2.0s In-Memory Batched Commit +    │
│                                    │ immediate flush on AppState pause  │
├────────────────────────────────────┼────────────────────────────────────┤
│ 7. Proprietary EDIABAS .prg Risk   │ Declarative UDS-over-ISO-TP (0x22/ │
│                                    │ 0x2E/0x31) JSON catalog files      │
└────────────────────────────────────┴────────────────────────────────────┘
```

### 3.1 BLE GATT Auto-Discovery Profile Table
Unlike serial ports, BLE OBD adapters lack a universal service UUID. The `BleTransport` evaluates known profiles first before falling back to characteristic heuristic scanning:

```ts
export interface BleGattProfile {
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
```

---

## 4. System Architecture & Component Model

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Presentation Layer (React Native)               │
│      HomeTab · LiveDashboard · CodesTab · LogsTab · SettingsTab        │
│          Gauges & Line Charts (@shopify/react-native-skia)             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ UI Thread Reanimated SharedValues
                                    │ (Zero React re-renders)
┌───────────────────────────────────▼────────────────────────────────────┐
│                         Application Services                           │
│   ConnectionService · LiveDataService · DtcService · ScanService       │
│         LogService (Batched SQLite) · ReportService · AskAiService     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Typed Commands & Observation Events
┌───────────────────────────────────▼────────────────────────────────────┐
│                       Pure TypeScript OBD Core                         │
│  CommandQueue (Half-Duplex Mutex) · Elm327Parser · IsoTpReassembler    │
│    PollScheduler (Priority Tiers) · PidRegistry · DtcDecoder           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Byte Stream / ASCII Lines ('\r' / '>')
┌───────────────────────────────────▼────────────────────────────────────┐
│                          Transport Interface                           │
│   BleTransport  │  WifiTcpTransport  │ ClassicTransport │ MockTransport│
└────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Strict Transport Contract
All hardware abstraction adheres to a unified interface:

```ts
export type TransportKind = 'ble' | 'wifi' | 'classic' | 'mock';

export interface AdapterTarget {
  id: string;
  name: string;
  address?: string; // MAC or IP
  port?: number;    // TCP port (default 35000)
}

export interface Transport {
  readonly kind: TransportKind;
  connect(target: AdapterTarget): Promise<void>;
  disconnect(): Promise<void>;
  write(data: string): Promise<void>; // Must append '\r'
  onData(listener: (chunk: string) => void): () => void;
  onClose(listener: (reason?: string) => void): () => void;
  isConnected(): boolean;
}
```

### 4.2 Half-Duplex ELM327 CommandQueue & Framing
ELM327 microcontrollers are strictly half-duplex. Issuing a command before receiving the `>` prompt corrupts internal adapter registers.

```ts
export type CommandPriority = 'IMMEDIATE' | 'USER_ACTION' | 'POLL_FAST' | 'POLL_SLOW';

export interface QueuedCommand {
  id: string;
  rawCommand: string;
  priority: CommandPriority;
  timeoutMs: number;
  resolve: (lines: string[]) => void;
  reject: (error: ObdError) => void;
}
```

**Framing Rules:**
1. Append `\r` to outgoing payload.
2. Accumulate incoming ASCII stream into `rxBuffer`.
3. Halt processing until `rxBuffer` contains `>`.
4. Strip command echoes (e.g. if `ATE0` failed on clone), eliminate `\r`, `\n`, whitespace, and `SEARCHING...`.
5. Parse and classify typed terminal errors: `NO DATA`, `UNABLE TO CONNECT`, `CAN ERROR`, `BUS INIT...ERROR`, `STOPPED`, `?`.

---

## 5. Visual Design System ("Apple Automotive" Aesthetic)

The cabin environment demands zero distraction, instantaneous peripheral recognition, and legibility under direct sunlight or pitch-black night driving.

### 5.1 Color Tokens & Theming

| Token | Dark Mode (Primary OLED) | Light Mode | Application |
| :--- | :--- | :--- | :--- |
| `bg.canvas` | `#000000` (True Black) | `#F2F2F7` | Screen canvas, eliminating cabin backlight bleed |
| `bg.card` | `#1C1C1E` (Apple Inset) | `#FFFFFF` | Inset grouped list tiles, gauge backgrounds |
| `bg.elevated` | `#2C2C2E` | `#E5E5EA` | Bottom sheets, action sheets, modals |
| `text.primary` | `#FFFFFF` | `#000000` | Large titles, primary readouts |
| `text.secondary`| `#8E8E93` | `#6C6C70` | Units (`rpm`, `km/h`, `psi`), timestamps |
| `accent.brand` | `#0A84FF` (System Blue) | `#007AFF` | Primary CTAs, Quick Scan button, active tabs |
| `status.good` | `#30D158` (System Green)| `#34C759` | All systems ready, voltage normal, pass badge |
| `status.warn` | `#FF9F0A` (System Amber)| `#FF9500` | Pending DTCs, monitor incomplete, warm temp |
| `status.crit` | `#FF453A` (System Red)  | `#FF3B30` | Stored DTCs, MIL active, redline, overheat |

### 5.2 Typography & Numerics
- **UI Labels & Prose:** System Default (`SF Pro` on iOS, `Roboto` on Android).
- **Gauges, Digital Readouts, DTCs:** `SF Mono` / `Roboto Mono` configured with `fontVariant: ['tabular-nums']` to completely eliminate horizontal numeric jitter during high-rate polling.

---

## 6. Detailed Screen Specifications & Wireframes

### 6.1 Home Screen (`app/(tabs)/home.tsx`)
The anchor of the application. Calm, unhurried, and oriented around one primary action.

```
┌──────────────────────────────────────────────────────────┐
│ [Garage: 2018 Volkswagen GTI ▾]                  [🟢 8Hz]│ ← Header: Vehicle Switcher + Link Pill
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ ● Connected · Vgate iCar Pro BLE           12.6V  ›  │ │ ← Tappable Connection & Voltage Strip
│ │   VIN: WVWZZZAU... (Confirmed) · ISO 15765-4 CAN     │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ ┌──────────────────────────────────────────────────────┐ │
│ │                     (  ⚡  )                         │ │
│ │                   QUICK SCAN                         │ │ ← Hero Button (Haptic Medium on Press)
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
│ │ [ ✨ Ask AI ]                     [ 📄 Share PDF ]   │ │ ← Immediate Action Buttons
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ VEHICLE TOOLS                                            │
│ ┌─────────────────────────┐  ┌─────────────────────────┐ │
│ │ 🔋 Cranking Drop Test   │  │ 📈 Live Dashboard   ›   │ │
│ └─────────────────────────┘  └─────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### 6.2 Live Dashboard (`app/(tabs)/live.tsx`)
- Swipeable pages with customizable tile layouts (persisted per vehicle in SQLite).
- Screen keep-awake enabled automatically via `expo-keep-awake`.
- Polling scheduler automatically suspends when tab is blurred or app is backgrounded.
- Tile Types:
  - **1x1 Compact Digital Readout:** Parameter Name + Huge Tabular Value + Metric/Imperial Unit + Min/Max Session Peak.
  - **2x2 Circular Skia Sweep Gauge:** 240° sweep arc, color zones (Green/Amber/Red), peak-hold tick.
  - **6-Col Full-Width Bezier Graph:** Rolling 30-second Skia canvas rendering dual overlaid PIDs (e.g. Boost vs. RPM).

### 6.3 Diagnostic Codes Screen (`app/(tabs)/codes.tsx`)
- Segmented Control: `Stored (Mode 03)` | `Pending (Mode 07)` | `Permanent (Mode 0A)`.
- **DTC Row Card:** Alphanumeric Badge (`P0301`) + Component Title ("Cylinder 1 Misfire Detected") + Severity Chip.
- Detail View (Bottom Sheet): SAE official description, Freeze Frame snapshot, and direct **Ask AI** button.
- **Clear Codes Action:**
  1. User taps "Clear DTCs".
  2. Prompts native warning dialog explaining that resetting clears emissions readiness and freeze-frame data.
  3. Takes an automatic pre-clear immutable snapshot saved to SQLite.
  4. Issues Mode 04 (`04\r`).
  5. Automatically executes a post-clear verification re-read.

### 6.4 Ask AI Sheet (`app/sheets/ask-ai.tsx`)
A native modal sheet that constructs a rich, privacy-controlled prompt and dispatches it via the OS share sheet.

```
┌──────────────────────────────────────────────────────────┐
│ Ask AI Assistant                                [Close]  │
├──────────────────────────────────────────────────────────┤
│ ℹ️ Connected via Wi-Fi Adapter (No Internet)              │
│ Tap 'Copy Prompt', disconnect adapter Wi-Fi, then paste  │
│ into ChatGPT, Claude, or Gemini.                         │
├──────────────────────────────────────────────────────────┤
│ Observed Symptoms (Optional):                            │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Stumbles slightly during cold idle in the morning.   │ │
│ └──────────────────────────────────────────────────────┘ │
│ Quick Chips: [Rough Idle] [Hard Start] [Loss of Power]   │
│                                                          │
│ Privacy & Diagnostic Context Included:                   │
│ [✓ Vehicle Details]  [✓ DTCs (1)]   [✓ Freeze Frame]    │
│ [✓ Readiness Status] [✓ Voltage]    [🔒 Hide VIN: ON]    │
│                                                          │
│ Formatted AI Prompt Preview:                             │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Vehicle: 2018 Volkswagen GTI                          │ │
│ │ Trouble Codes: P0171 (Pending) - System Too Lean     │ │
│ │ Freeze Frame: RPM 1850, Coolant 82°C, STFT +18.2%    │ │
│ │ ...                                                  │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ [  📤 Share to AI App...  ]      [  📋 Copy Prompt  ]    │
│                                                          │
│ ⚠️ AI insights do not replace certified mechanic repair. │
└──────────────────────────────────────────────────────────┘
```

---

## 7. Functional Requirements (FR) Catalog

### 7.1 Connection & Hardware Abstraction
- **FR-1 (Adapter Discovery):** Scan and list BLE peripherals matching OBD GATT profiles, discover TCP Wi-Fi adapters at configured IP/port, and list paired Android Classic Bluetooth devices.
- **FR-2 (Onboarding Compatibility Wizard):** Guide users through selecting their adapter hardware. Explicitly inform iOS users that generic Bluetooth Classic dongles cannot be accessed on iOS without MFi licensing.
- **FR-3 (Tolerant Init Sequence):** Execute standard initialization (`ATZ` → `ATE0` → `ATL0` → `ATS0` → `ATH1` → `ATSP0` → `0100`). Handle clone quirks (e.g. ignore `?` responses on optional AT commands, handle unprompted echoes).
- **FR-4 (Auto-Reconnection & Backoff):** Automatically attempt reconnection with exponential backoff (1s, 2s, 4s, max 8s) if signal drops temporarily.
- **FR-5 (In-App Flight Recorder):** Maintain a rolling 500-line circular buffer of raw TX/RX ASCII communication with millisecond timestamps, exportable via system share for troubleshooting adapter quirks.

### 7.2 Diagnostics & Vehicle Telemetry
- **FR-6 (Automatic VIN Acquisition):** Request Mode 09 PID 02 immediately upon establishing vehicle communication. Parse multi-frame ISO-TP payload into standard 17-character VIN. Fall back to manual garage entry if ECU returns `NO DATA`.
- **FR-7 (Supported PID Bitmask Discovery):** Query PIDs `0100`, `0120`, `0140`, `0160`, `0180`, `01A0`, `01C0`. Never poll an unsupported PID during live dashboard operation.
- **FR-8 (Priority-Tiered Polling Scheduler):**
  - **Fast Tier (Every Cycle, ~10–15 Hz):** RPM (`010C`), Speed (`010D`), Throttle (`0111`), Engine Load (`0104`).
  - **Medium Tier (Every 3rd Cycle, ~3–5 Hz):** MAP (`010B`), MAF (`0110`), Timing Advance (`010E`), Short/Long Fuel Trim (`0106`/`0107`).
  - **Slow Tier (Every 10th Cycle, ~1 Hz):** Coolant Temp (`0105`), Intake Temp (`010F`), Fuel Level (`012F`), Ambient Temp (`0146`).
- **FR-9 (Multi-PID SAE J1979 Packing):** On modern CAN protocols, probe support for bundling up to 6 PIDs into a single Mode 01 request frame (e.g. `01 0C 0D 04 11\r`). If vehicle responds with valid combined payload, enable packing to double effective polling frequency.
- **FR-10 (DTC Enumeration):** Concurrently query Mode 03 (Stored), Mode 07 (Pending), and Mode 0A (Permanent). Disassemble two-byte DTC encodings according to standard SAE J2012 format (`P`, `C`, `B`, `U`).
- **FR-11 (Freeze Frame Capture):** Extract Mode 02 freeze-frame parameters for associated stored DTCs to record engine state at the exact moment the fault was triggered.
- **FR-12 (Safe Code Clear):** Mode 04 clearing requires explicit modal confirmation, persists an immutable pre-clear snapshot, and issues an immediate post-clear re-scan to verify ECU status.
- **FR-13 (Readiness Monitors):** Decode Byte B, C, D of Mode 01 PID 01 to report complete/incomplete status across Catalyst, Evaporative System, Oxygen Sensors, and Secondary Air systems.

### 7.3 Battery & System Analysis
- **FR-14 (High-Rate Cranking Drop Test):** Execute rapid `ATRV` polling (~20 Hz) while prompting user to crank engine. Capture baseline resting voltage, minimum cranking dip, and running alternator charge voltage:
  - Dip < 9.6 V: Flag as Weak Battery / Impending Failure.
  - Running Charge < 13.5 V or > 14.8 V: Flag as Alternator / Charging System Warning.

### 7.4 Logging, Storage & Export
- **FR-15 (Batched Crash-Safe Recording):** Live session telemetry buffers in memory and executes a batched SQLite transaction commit every 2.0 seconds, plus immediately upon app backgrounding, navigation away, or disconnect.
- **FR-16 (Session Scrubbable Replay):** Graphically scrub through recorded drive sessions on the Live Dashboard using a timeline slider.
- **FR-17 (PDF Diagnostic Reports):** Generate vector PDF inspection summaries via `expo-print` containing vehicle profile, timestamp with IANA timezone, full DTC register, freeze-frame metrics, and professional mechanic disclaimer.
- **FR-18 (CSV Telemetry Export):** Export raw timestamped sample rows (`t_offset_ms, pid_name, value, unit`) via standard RFC 4180 CSV for external analysis.

### 7.5 Ask AI System Integration
- **FR-19 (Pure TS Prompt Generator):** Construct cleanly formatted plain-text diagnostic summaries containing vehicle make/model/year, check-engine light state, active codes, freeze frame, readiness gaps, and user symptoms.
- **FR-20 (Privacy-Controlled Handoff):** VIN is excluded by default from AI prompts (user can toggle on). Personal location or telemetry history is never included.
- **FR-21 (Safety-Critical Visual Banners):** If scanned DTCs contain chassis/ABS (`C` prefix) or airbag/restraint (`B` prefix) codes, display an in-app caution banner mandating professional inspection regardless of AI interpretation.

---

## 8. Database Architecture & SQLite Schema

iCAR utilizes `expo-sqlite` with Write-Ahead Logging (`WAL`) enabled to ensure high-frequency writes never block UI read queries.

```sql
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- Registered Vehicles in Garage
CREATE TABLE IF NOT EXISTS vehicles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  vin TEXT,
  vin_source TEXT CHECK(vin_source IN ('ecu', 'manual')) DEFAULT 'ecu',
  make TEXT,
  model TEXT,
  year INTEGER,
  platform_code TEXT,
  preferred_adapter_id TEXT,
  protocol TEXT,
  supported_pids_json TEXT,
  responding_ecus_json TEXT,
  dashboard_layout_json TEXT,
  created_at INTEGER NOT NULL
);

-- Immutable Diagnostic Scan Snapshots
CREATE TABLE IF NOT EXISTS scans (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  scanned_at_utc INTEGER NOT NULL,
  timezone TEXT NOT NULL,
  vin_snapshot TEXT,
  mil_on INTEGER NOT NULL CHECK(mil_on IN (0, 1)),
  dtc_count INTEGER NOT NULL,
  dtcs_json TEXT NOT NULL,
  freeze_frame_json TEXT,
  readiness_json TEXT,
  battery_volts REAL,
  cleared_at_utc INTEGER
);

-- Drive Sessions & Recordings
CREATE TABLE IF NOT EXISTS recordings (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  started_at_utc INTEGER NOT NULL,
  ended_at_utc INTEGER,
  pids_json TEXT NOT NULL,
  sample_count INTEGER DEFAULT 0,
  summary_stats_json TEXT
);

-- High-Frequency Live Telemetry Samples
CREATE TABLE IF NOT EXISTS samples (
  recording_id TEXT NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
  t_offset_ms INTEGER NOT NULL,
  pid INTEGER NOT NULL,
  val REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_samples_rec_time ON samples(recording_id, t_offset_ms);

-- Bundled Read-Only DTC Reference Dictionary
CREATE TABLE IF NOT EXISTS dtc_dictionary (
  code TEXT NOT NULL,
  make TEXT NOT NULL DEFAULT 'GENERIC',
  title TEXT NOT NULL,
  severity TEXT CHECK(severity IN ('info', 'caution', 'serious')) NOT NULL,
  causes_json TEXT,
  PRIMARY KEY (code, make)
);
```

### 8.1 100% Commercially Clean DTC Database Strategy
To avoid copyright infringement and GPL licensing restrictions (which conflict with App Store DRM guidelines):
1. Extract public standard SAE J2012 fault code numbers and formal designations (`P0xxx`, `P2xxx`, `P34xx`, `B0xxx`, `C0xxx`, `U0xxx`).
2. Run an offline pre-build synthesis script using an LLM to generate 100% original, consumer-friendly English descriptions, inspection guidance, and severity categorizations.
3. Package the output into a bundled read-only SQLite database (`assets/dtc/codes_v1.db`), copied to application storage on first launch.

---

## 9. Phased Implementation Roadmap

```
Phase 0: Architecture Setup & Pure TS Core Simulator (Days 1–5)
├── Scaffold strict TypeScript repo, ESLint, Jest, and directory structure
├── Build pure TS CommandQueue, Elm327Parser, IsoTpReassembler, DtcDecoder
├── Build SmartMockTransport simulating normal, split-chunk, and dirty clone responses
└── 100% Unit test coverage on PID formulas and framing

Phase 1: App Shell, Navigation & Quick Scan Vertical Slice (Days 6–10)
├── Expo Prebuild config with dev client on iOS and Android
├── 5-tab native layout with SF Symbols and OLED black tokens
├── Quick Scan state machine wired to SmartMockTransport
├── SQLite WAL database initialization and bundled DTC database loader
└── Ask AI bottom sheet with system share sheet integration

Phase 2: Real Hardware Transports & In-App Terminal (Days 11–16)
├── BleTransport with KNOWN_BLE_PROFILES + requestMTU(512)
├── WifiTcpTransport (192.168.0.10:35000) with cellular drop detection
├── Android ClassicTransport fallback
├── In-app circular Flight Recorder / raw terminal screen
└── Driveway validation on physical test vehicle

Phase 3: 60fps Skia Live Dashboard & Logging Engine (Days 17–22)
├── Reanimated SharedValue live data bridge
├── Skia 240° sweep gauges, numeric tiles, and rolling line graphs
├── 2.0s Batched SQLite LogService recording pipeline
└── Scrubbable session replay and CSV export

Phase 4: Reports, Battery Diagnostics & Vehicle Registry (Days 23–28)
├── High-rate battery cranking voltage drop test
├── PDF diagnostic report generator (expo-print) with share sheet
├── Vehicle profile confirmation & garage multi-car switcher
└── Hardening against clone adapter timing errors

Phase 5: Store Readiness, Polish & Beta Release (Days 29–35)
├── Platform permissions hardening (Bluetooth scan/connect, local network)
├── Comprehensive UI/E2E test flows (Maestro / Detox)
├── Internal Android testing track & TestFlight distribution
└── Final store metadata, privacy policy, and commercial packaging
```

---

## 10. Acceptance Criteria & Definition of Done

A build milestone is deemed complete only when it meets the following objective verification gates:

1. **Protocol Integrity:** The pure TypeScript core handles split 20-byte BLE packets, command echoes, multi-frame ISO-TP lines, and dirty error responses (`NO DATA`, `CAN ERROR`, `?`) without hanging the `CommandQueue` or throwing unhandled rejections.
2. **60 FPS Live Rendering:** The Live Dashboard maintains a sustained 60 fps (120 fps on ProMotion displays) during 15 Hz PID updates, with zero React component tree re-renders measured via React DevTools profiler.
3. **Snapshot Truthfulness:** Every recorded diagnostic scan snapshot stores immutable timestamps, UTC timezone, vehicle VIN, active DTCs, freeze frame, and readiness status.
4. **Data Safety:** Destructive actions (Clearing DTCs) cannot be triggered in fewer than two explicit taps, always record a pre-clear snapshot, and immediately verify the result via an automated re-scan.
5. **Privacy Enforcement:** Ask AI prompts strictly exclude the vehicle VIN by default and never transmit payload data across background network connections; all transfers proceed through user interaction with the native OS share sheet.
6. **Zero Hardware Wear:** High-frequency telemetry writes execute through in-memory aggregation with transaction batching, preventing flash storage wear and thermal throttling.
