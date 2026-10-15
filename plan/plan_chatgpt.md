# iCAR — ChatGPT Implementation Plan

**Status:** proposed implementation plan  
**Audience:** personal-use build first, with a credible commercial path  
**Target:** one React Native codebase for Android and iPhone

This plan reconciles `car_scan_calude_plan_v2_3.md` with `Gemin4_plan.md`. The product direction in both is sound: build a calm, local-first OBD-II scanner that makes a trustworthy quick health check easy and keeps advanced live data available when wanted. The main change here is sequencing: reliability of the byte stream, ELM327 protocol, and real-hardware testing comes before rich UI, reports, or vehicle-specific tools.

---

## 1. Product decision

Build **iCAR v1** as a generic OBD-II diagnostic reader for personal use:

- Connect to BLE and Wi-Fi ELM327-compatible adapters on iPhone and Android.
- Add Android Bluetooth Classic after BLE is reliable. Do not promise Classic Bluetooth support on iPhone.
- Read live PIDs, stored/pending/permanent DTCs, readiness, freeze-frame data, VIN when available, and adapter/ECU voltage.
- Save scans and recordings locally, export CSV/PDF, and hand a user-reviewed prompt to any AI app through the system share sheet.
- Provide a polished five-tab experience: Home, Live, Codes, Logs, Settings.

### Explicit v1 boundaries

Do **not** include these in the first usable release:

- Coding, actuator control, module programming, or service-reset writes.
- BMW Ediabas `.prg`/`.grp` parsing or an interpreter.
- Built-in cloud AI, accounts, analytics, or a backend.
- CarPlay / Android Auto.
- Performance-timing features until the scanner itself is stable.

BMW and other make-specific tools can be a separate later pack. If that work begins, use documented UDS-over-ISO-TP requests backed by a reviewed data catalog; do not attempt to run proprietary Ediabas bytecode in TypeScript.

---

## 2. Architecture that protects reliability

### 2.1 Layering

```text
React Native UI
  └─ App services (connection, scan, live, log, reports, Ask AI)
       └─ Pure TypeScript OBD core
            ├─ command queue and ELM327 framing
            ├─ init / adapter quirks / capability discovery
            ├─ ISO-TP and response parsing
            ├─ PID, DTC, readiness, and unit conversion
            └─ poll scheduler
                 └─ transport adapters (BLE, Wi-Fi, Classic Android, mock)
```

The core must have no React Native imports. It receives bytes, produces typed events/results, and is tested with captured conversations. The UI never sends raw ELM327 commands directly.

### 2.2 Transport contract

```ts
export interface Transport {
  readonly kind: 'ble' | 'wifi' | 'classic' | 'mock';
  connect(target: AdapterTarget): Promise<void>;
  disconnect(): Promise<void>;
  write(data: string): Promise<void>;
  onData(listener: (chunk: string) => void): Unsubscribe;
  onClose(listener: (reason?: string) => void): Unsubscribe;
  isConnected(): boolean;
}
```

Only `CommandQueue` writes to a connected transport. It appends the carriage return, waits for the ELM327 `>` prompt, and guarantees that no next command is written early. A pending command always settles as a success or a typed error, including on timeout, disconnect, `NO DATA`, `STOPPED`, `?`, `CAN ERROR`, and `UNABLE TO CONNECT`.

### 2.3 Byte-stream and BLE rules

Treat transport data as an arbitrary stream, not command-sized messages. In particular, BLE callbacks can split a short response, a long VIN response, or the terminal prompt across several notifications.

- Keep a receive buffer in `CommandQueue`; parse only after a `>` prompt is present.
- On Android, request a larger BLE MTU after connection when the library/device supports it. Do not rely on it: 20-byte notifications must remain correct.
- For BLE, first match known GATT profiles (Vgate/iOS-Vlink, FFE0 clones, OBDLink/vLinker, Nordic UART), then use a conservative fallback that finds a writable characteristic paired with a notify/indicate characteristic.
- Save the successful profile for an adapter, expose the selected profile in the debug log, and never guess silently when a device offers ambiguous characteristics.
- Wi-Fi defaults are configurable. Start with the common `192.168.0.10:35000` but do not hard-code it as universal.

### 2.4 ELM327 initialization and scan mode

Use a tolerant init state machine rather than assuming every clone implements every AT command:

1. Reset/wake adapter, wait for prompt, identify it, and record the raw response.
2. Disable echo when supported; normalize linefeeds and spaces.
3. Set automatic protocol selection, trigger detection with a safe request, then record `ATDPN` when available.
4. Run capability discovery and only make optional AT commands fatal when their absence prevents the active flow.

Use **headers on** (`ATH1`) and **spaces off** (`ATS0`) during protocol discovery, VIN retrieval, supported-PID discovery, and DTC scans. This preserves ECU addresses such as `7E8` and `7E9`, which are necessary to reliably group multi-ECU and ISO-TP responses. For fast live polling, either target the engine ECU deliberately or switch to header-less parsing only after the selected ECU is known and tested.

Add quirk profiles based on observed behaviour, never marketing labels such as “v2.1.” Optional-command `?` responses are non-fatal; persistent framing failures, response corruption, and required-command failures are not.

### 2.5 OBD data handling

- Discover Mode 01 supported PID bitmasks before exposing or polling a PID.
- Decode all PID formulas and unit conversions in isolated, deterministic functions with known-vector unit tests.
- Support Mode 03, 07, and 0A DTC reads; Mode 04 clearing is a deliberately confirmed operation with a saved pre-clear scan and a verification re-read.
- Reassemble both headered CAN ISO-TP frames and ELM327 indexed multi-line responses. Group headered frames by ECU before reassembly.
- Treat VIN, protocol, vehicle details, DTCs, readiness, freeze frame, and voltage as a single immutable scan snapshot when it is stored.
- Try packed multi-PID Mode 01 requests only behind per-vehicle capability detection; immediately fall back to single-PID polling if the response is invalid or incomplete.

### 2.6 UI data flow

Zustand stores slow-changing application state only: connection status, selected vehicle, layout, scan state, persisted history, and errors. It must not receive every 10–15 Hz PID update.

`LiveDataService` publishes high-frequency values to a narrow live-data bridge; the dashboard maps those values to Reanimated shared values, and Skia renders gauges/graphs on the UI thread. React state updates only for low-rate display metadata such as measured Hertz and recording status. This prevents the live screen from turning every incoming PID into a React render.

### 2.7 Local storage

Use SQLite for vehicles, scan snapshots, recordings, samples, and the offline DTC dictionary. Enable foreign keys and test WAL mode on target devices. Recording samples buffer in memory and flush in a transaction every roughly two seconds, plus immediately on backgrounding, disconnect, and stopping a recording. This is crash-resilient without hundreds of tiny disk transactions per minute.

Store timestamps in UTC with the scan-time IANA timezone alongside them. Store the VIN and vehicle identity as a snapshot on every scan/report so history remains truthful if the Garage record changes later.

---

## 3. UX priorities

### Home

The first screen has one primary action: **Quick Scan**. It shows connection state, active vehicle, the last health summary, a safe path to Live/Codes, and a connection troubleshooting path. A successful scan summarizes rather than diagnoses: no active codes, attention needed, or problem found, backed by the raw data a user can inspect.

### Live

Offer a useful default page (RPM, speed, coolant, voltage, load) before adding customization. After that, allow persistent per-vehicle pages with digital tiles, gauges, and graphs. Poll only visible PIDs, stop polling off-screen/backgrounded, and expose actual update rate rather than a theoretical promise.

### Codes

Separate stored, pending, and permanent DTCs. Detail sheets distinguish sourced descriptions from unavailable information. Clearing codes requires an explicit warning that it can erase valuable diagnostic data and readiness status, automatically saves a snapshot, and shows the result of a re-read.

### Ask AI

Generate a plain-text prompt locally in pure TypeScript. Vehicle basics, codes, freeze frame, readiness, and voltage are on by default; VIN and live-data snapshots are off by default. The user sees and can edit exactly what leaves the app before Share or Copy. For a Wi-Fi adapter connection, show that the adapter Wi-Fi may have no internet and instruct the user to copy first, then disconnect before using an AI service.

Ask AI is an operating-system handoff, not an in-app diagnosis. Safety-critical code groups get an in-app “seek professional help” banner regardless of an AI response.

---

## 4. Project structure

```text
icar/
├─ app/                         # Expo Router screens and sheets
├─ src/
│  ├─ core/                     # pure TS: zero React Native imports
│  │  ├─ elm327/                # queue, framing, init, quirk profiles
│  │  ├─ obd/                   # PID/DTC/readiness/ISO-TP/polling
│  │  └─ units/
│  ├─ transports/               # BLE, Wi-Fi TCP, Classic Android, mock
│  ├─ services/                 # connection, scan, live, logging, reports
│  ├─ db/                       # migrations, queries, bundled DTC data
│  ├─ store/                    # slow application state only
│  └─ ui/                       # visual components, Skia, accessibility
├─ assets/dtc/
├─ tests/
│  ├─ core/
│  ├─ fixtures/                 # captured/replayed adapter sessions
│  └─ e2e/
└─ docs/
```

Use Expo development builds and prebuild/CNG, not Expo Go, because Bluetooth and TCP use native modules. Pin a compatible Expo/RN version only after verifying the actively maintained BLE, Classic Bluetooth, and TCP library options against that version.

---

## 5. Delivery sequence and hard exit criteria

### Phase 0 — Feasibility and foundations (2–3 days)

- Confirm the test adapter models and target test vehicle(s).
- Set up an Expo development build on Android; set up iPhone only when a Mac/Xcode path exists.
- Scaffold strict TypeScript, linting, test runner, error taxonomy, and a raw TX/RX flight recorder.
- Implement `MockTransport` with normal responses, split responses, no-data paths, timeouts, a VIN, sample DTCs, and smooth live values.

**Exit:** mock connect/init/scan works in tests, and at least one physical target builds and runs.

### Phase 1 — Protocol core and BLE vertical slice (5–7 days)

- Implement `Transport`, serial command queue, prompt framing, init state machine, parser, ISO-TP reassembly, DTC decoder, PID registry, and capability discovery.
- Implement BLE known-profile matching, fallback characteristic inspection, chunk handling, and reconnection.
- Build a minimal connection screen plus raw-log export.
- Test against the real adapter before expanding product scope.

**Exit:** a real BLE adapter connects repeatedly; `ATRV`, `0100`, PID `010C`, and VIN/DTC paths either return validated data or a clear typed error without a hung queue.

### Phase 2 — Quick Scan and persistence (4–5 days)

- Implement scan orchestration: connect → init → detect protocol → VIN → capability discovery → DTCs → freeze frame → readiness → voltage → save.
- Add SQLite migrations, DTC lookup, Garage basics, and the Home health summary.
- Add safe clear-code flow with snapshot and re-read.

**Exit:** a scan survives app restart, snapshot data is internally consistent, and code clearing cannot be triggered accidentally.

### Phase 3 — Live dashboard and recordings (5–7 days)

- Implement scheduler tiers, visible-PID polling, performance metrics, Reanimated/Skia rendering, and default dashboard.
- Add recording buffer/transaction flush, Logs history, CSV export, and replay from recorded data.
- Verify UI responsiveness on a lower-end Android device where available.

**Exit:** a 20-minute recording is persisted without runaway memory use, queue corruption, or UI stutter; leaving the Live tab stops polling.

### Phase 4 — Reports and Ask AI handoff (3–4 days)

- Build report models/templates and system share integration.
- Implement `buildAiPrompt(scan, options)` with snapshot tests for privacy toggles, metric/imperial units, and incomplete data.
- Add copy/share preview and Wi-Fi no-internet warning.

**Exit:** reports accurately reflect stored snapshot data; VIN is excluded from AI prompts unless explicitly enabled; Share and Copy work on both target platforms.

### Phase 5 — Additional transports and quality (5–10 days)

- Implement Wi-Fi TCP and validate it on a real adapter.
- Implement Android Classic Bluetooth and validate separately; it must not alter the core.
- Add permission/onboarding flows, accessibility, reconnect behaviour, dark/light presentation, error recovery, and UI end-to-end tests.

**Exit:** every transport follows the same protocol regression suite, and the app is useful on at least two vehicle/adapter combinations.

---

## 6. Test plan

The test suite is part of the product, not a final cleanup task.

| Layer | Required coverage |
|---|---|
| Pure core | PID equations, DTC decoding, bitmasks, units, prompt builder, error mapping |
| Queue/framing | split chunks, echoes, multiple prompts, timeouts, disconnects, clone quirks |
| ISO-TP | headered multi-ECU frames, indexed frames, VIN, long DTC lists, bad sequence numbers |
| Replay fixtures | captured sessions for each owned adapter and vehicle, including failure sessions |
| UI | connect, Quick Scan, clear-code confirmation, recording, report, AI preview/share paths |
| Field tests | ignition-on/engine-off and engine-running scenarios; never use the app while driving |

Every real fault fixed from an adapter or vehicle should become a replay fixture first, then receive a regression test.

---

## 7. Safety, privacy, and commercial readiness

- Local-first by default: no account, tracking, or hidden upload path.
- Clearly explain Bluetooth and local-network permissions at the time they are requested.
- Never describe DTCs or AI suggestions as a conclusive diagnosis.
- Use an offline DTC dataset whose commercial rights are verified. If rights are uncertain, use only a legally reviewed generic data set plus original explanatory prose.
- Keep a visible disclaimer for safety-critical systems and all state-changing operations.
- Maintain an adapter compatibility list based on real validation, not marketplace claims.
- Before store work, verify present-day package compatibility, licensing, platform permission requirements, store fees, and policies from their official sources.

---

## 8. Decisions needed before Phase 0 completes

1. Which adapter(s) and vehicle(s) are available for the first hardware tests?
2. Is an iPhone plus a Mac/Xcode environment available now, or should Android BLE be the initial target?
3. Does personal use need Wi-Fi or Android Classic immediately, or can those follow a working BLE release?
4. Is the first release strictly diagnostic/read-only except Mode 04 code clearing, as recommended here?

Until these are answered, use BLE + `MockTransport` as the default implementation path and keep every non-BLE transport behind the common interface.

---

## 9. Definition of a successful personal-use release

The release is ready for daily personal use when it can repeatedly connect to the target adapter, create a reliable saved Quick Scan, show stable live RPM/speed/coolant data, preserve recordings, export an honest report, and recover clearly from ignition-off, bad-adapter, timeout, and dropped-connection cases. Any vehicle-specific write feature remains excluded until the generic scanner has met those criteria.

