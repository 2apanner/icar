# iCAR — Development Plan & Task Breakdown (v3.0 Master)

**Product Name:** iCAR (Apple Automotive Diagnostic & Telemetry Suite)  
**Platform:** Flutter (iOS & Android) with Impeller GPU Backend  
**Methodology:** Incremental Vertical Slicing with Test-Driven Pure Dart Core  

---

## 1. Project Overview & Delivery Strategy

The iCAR development plan is structured around a **Simulator-First, Core-Isolated Architecture**:
1. **Zero-Gas Desktop Development:** 90% of the OBD-II protocol state machine, ISO-TP reassembly, DTC decoders, and live UI gauges are built and tested on the developer's desk using `SmartMockTransport`.
2. **Pure Dart Core Isolation:** All OBD logic resides in `lib/core/` with zero dependencies on Flutter UI libraries, enabling 100% test coverage and execution in background isolates.
3. **Phase-Gated Quality:** Each phase delivers an end-to-end usable slice verified by unit, integration, and UI tests.

---

## 2. Phase-by-Phase Roadmap

```
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 0: FOUNDATION, PURE DART OBD ENGINE & SIMULATOR (Days 1–5)       │
│ • Pure Dart CommandQueue (Mutex) & ELM327 framing state machine        │
│ • ISO-TP multi-frame reassembler & SAE J2012 DTC decoder               │
│ • SmartMockTransport (sinusoidal RPM/Speed, split 20-byte chunks)      │
│ • 100% unit test coverage for PID formulas and framing errors          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: APP SHELL, NAVIGATION & QUICK SCAN VERTICAL SLICE (Days 6–10) │
│ • Flutter app scaffold, Obsidian & Champagne design tokens             │
│ • Drift SQLite setup with WAL mode & bundled DTC dictionary            │
│ • Quick Scan state machine (Connect → Init → Read VIN → DTCs → Save)   │
│ • Ask AI Bottom Sheet with native OS Share Sheet handoff               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: HARDWARE TRANSPORTS & FLIGHT RECORDER (Days 11–16)            │
│ • BLE Transport (Known GATT profile discovery + requestMtu(512))       │
│ • Wi-Fi TCP Transport (192.168.0.10:35000) with cellular drop detector │
│ • Android Classic Bluetooth RFCOMM channel                             │
│ • In-app circular Flight Recorder & raw TX/RX ASCII terminal           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: 60–120 FPS IMPELLER COCKPIT & BATCHED LOGGER (Days 17–22)     │
│ • CustomPainter 240° sweep tachometer driven by ValueNotifier          │
│ • Rolling 30-second dual-trace oscilloscope with Freeze-Frame          │
│ • 2.0s Batched SQLite LogService with crash-safe WAL commits           │
│ • Scrubbable session replay and raw CSV telemetry export               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: DIAGNOSTIC DIFF ENGINE & BATTERY TESTING (Days 23–28)         │
│ • Side-by-Side Diagnostic Diff Inspector (Fault lifecycle & Δ matrix)  │
│ • Two-step protected Mode 04 DTC Clear with pre-clear archive snapshot │
│ • 20 Hz ATRV Battery Cranking Voltage Drop Test                        │
│ • Comparative vector PDF diagnostic report generator                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ PHASE 5: HARDENING, POLISH & TESTFLIGHT / PLAY BETA (Days 29–35)       │
│ • Permissions hardening (Bluetooth scan/connect, local network)        │
│ • Real vehicle validation (Vgate, Veepeak, OBDLink hardware)           │
│ • Integration tests & golden UI widget tests                           │
│ • TestFlight build and Google Play Internal Track distribution         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Work Breakdown Structure (Detailed Task Plan)

### Phase 0: Pure Dart OBD Core & Desktop Simulator
| Task ID | Task Description | Priority | Dependencies | Deliverable |
| :--- | :--- | :--- | :--- | :--- |
| **`CORE-01`** | **Scaffold Flutter Project & Pure Dart Workspace**<br>Configure strict `analysis_options.yaml`, Flutter 3.24+, and modular folder structure (`lib/core`, `lib/transports`, `lib/services`, `lib/ui`). | P0 | None | Working repo with lint pass |
| **`CORE-02`** | **ELM327 CommandQueue & Framing State Machine**<br>Implement half-duplex mutex queue with priority insertion (`immediate`, `userAction`, `pollFast`, `pollSlow`), timeout handling, and `>` prompt framing. | P0 | `CORE-01` | `lib/core/elm327/command_queue.dart` |
| **`CORE-03`** | **ISO-TP (ISO 15765-2) Multi-Frame Reassembler**<br>Implement frame reassembly for Single Frame (`0x0_`), First Frame (`0x1_`), and Consecutive Frame (`0x2_`) isolated by ECU identifier (`7E8`, `7E9`). | P0 | `CORE-01` | `lib/core/obd/isotp_reassembler.dart` |
| **`CORE-04`** | **SAE J2012 DTC Decoder & Status Classifier**<br>Decode 2-byte hex trouble codes into standard alphanumeric badges (`P0171`, `C0300`, `U0100`), classify severity, and extract Mode 02 Freeze Frames. | P0 | `CORE-01` | `lib/core/obd/dtc_decoder.dart` |
| **`CORE-05`** | **PID Registry & Math Formulas**<br>Implement standard Mode 01 formulas: RPM (`((A*256)+B)/4`), Speed (`A`), Boost/MAP, Coolant Temp (`A-40`), Fuel Trims (`(A-128)*100/128`), MAF. | P0 | `CORE-01` | `lib/core/obd/pid_registry.dart` |
| **`CORE-06`** | **SmartMockTransport Engine**<br>Simulate vehicle ECU responses for `ATZ`, `0100`, `0902` (VIN), `03` (DTCs), and emit dynamic sine-wave RPM/Speed with configurable noise and split 20-byte BLE chunks. | P0 | `CORE-02` | `lib/transports/smart_mock_transport.dart` |
| **`TEST-01`** | **Core Unit Test Suite**<br>Verify dirty clone responses (`SEARCHING...`, `NO DATA`, `CAN ERROR`, split chunks, timeout recovery). | P0 | `CORE-02`..`06` | 100% test pass on CI |

---

### Phase 1: App Shell, Design System & Quick Scan Slice
| Task ID | Task Description | Priority | Dependencies | Deliverable |
| :--- | :--- | :--- | :--- | :--- |
| **`UI-01`** | **Design System Tokens & Frosted Acrylic Containers**<br>Implement Obsidian theme (`#121317`), Champagne Gold (`#D8B17A`), frosted glass cards (`rgba(26,27,31,0.75)`), and 1px hairline borders. | P0 | `CORE-01` | `lib/ui/theme/` |
| **`UI-02`** | **5-Tab Cupertino/Material Shell Navigation**<br>Overview, Live Cockpit, Diagnostic Codes, Logs/History, and Settings tabs with persistent bottom bar. | P0 | `UI-01` | `lib/ui/navigation/` |
| **`DB-01`** | **Drift SQLite Setup with WAL Mode**<br>Configure `drift` with `sqlite3` FFI, Write-Ahead Logging (`WAL`), and tables: `vehicles`, `scans`, `dtc_records`, `live_samples`, `dtc_dictionary`. | P0 | `CORE-01` | `lib/data/database.dart` |
| **`DB-02`** | **Bundled DTC Dictionary Loader**<br>Pre-populate offline SAE J2012 database from bundled asset SQLite/JSON on initial app launch. | P1 | `DB-01` | `lib/data/dtc_repository.dart` |
| **`FEAT-01`** | **Quick Scan State Machine & Overview Screen**<br>Single-tap scan workflow: Connect ➔ Handshake ➔ Read VIN ➔ Stored/Pending Codes ➔ Freeze Frame ➔ Readiness ➔ Save to SQLite. | P0 | `CORE-06`, `DB-01` | `lib/ui/home/home_screen.dart` |
| **`FEAT-02`** | **Ask AI Assistant OS Share Sheet Handoff**<br>Construct structured diagnostic prompt with automatic VIN masking (`1VW***492`), Wi-Fi drop warning, and dispatch via `share_plus`. | P1 | `FEAT-01` | `lib/ui/sheets/ask_ai_sheet.dart` |

---

### Phase 2: Hardware Transports & Protocol Hardening
| Task ID | Task Description | Priority | Dependencies | Deliverable |
| :--- | :--- | :--- | :--- | :--- |
| **`TRANS-01`** | **BLE Transport Implementation**<br>Implement `BleTransport` with KNOWN_BLE_PROFILES (Vgate, Veepeak, OBDLink, Nordic UART) + dynamic heuristic characteristic discovery + `requestMtu(512)`. | P0 | `CORE-02` | `lib/transports/ble_transport.dart` |
| **`TRANS-02`** | **Wi-Fi TCP Transport**<br>Implement `WifiTcpTransport` on `192.168.0.10:35000` with socket keep-alive and cellular routing drop detection. | P1 | `CORE-02` | `lib/transports/wifi_tcp_transport.dart` |
| **`TRANS-03`** | **Android Classic Bluetooth Transport**<br>Implement Kotlin platform channel wrapping Android `BluetoothSocket` (RFCOMM SPP) with graceful fallback dialog on iOS. | P1 | `CORE-02` | `lib/transports/classic_transport.dart` |
| **`FEAT-03`** | **In-App Flight Recorder & Terminal**<br>500-line circular in-memory buffer capturing all raw ASCII TX/RX bytes with timestamps, filterable and exportable via share sheet. | P1 | `TRANS-01` | `lib/ui/settings/flight_recorder_screen.dart` |

---

### Phase 3: 60–120 FPS Cockpit & Batched Logger
| Task ID | Task Description | Priority | Dependencies | Deliverable |
| :--- | :--- | :--- | :--- | :--- |
| **`UI-03`** | **CustomPainter 240° Sweep Tachometer**<br>Direct GPU canvas painter listening to `ValueNotifier<double>` without widget rebuilds: smooth sweep arc, peak-hold tick, redline glow. | P0 | `UI-01` | `lib/ui/live/widgets/sweep_tachometer.dart` |
| **`UI-04`** | **Quad Live Sensor Metrics & Sparklines**<br>Tabular tiles for Boost, Coolant Temp, STFT, and MAF with target ranges and peak holds. | P1 | `UI-01` | `lib/ui/live/widgets/sensor_quad.dart` |
| **`UI-05`** | **Rolling Dual-Trace Oscilloscope**<br>30-second double-buffered waveform canvas rendering synchronized RPM vs. Boost with Freeze-Frame toggle. | P0 | `UI-01` | `lib/ui/live/widgets/oscilloscope.dart` |
| **`FEAT-04`** | **Crash-Safe Batched Telemetry Logger**<br>Accumulate 10–15 Hz live samples in memory ring buffer; flush as single batched SQLite transaction every 2.0s or on app backgrounding. | P0 | `DB-01` | `lib/services/log_service.dart` |
| **`FEAT-05`** | **Session Replay & CSV Export**<br>Scrubbable timeline replay on live gauges and RFC 4180 CSV file export via system share. | P1 | `FEAT-04` | `lib/services/export_service.dart` |

---

### Phase 4: Diagnostic Diff Engine & Battery Analysis
| Task ID | Task Description | Priority | Dependencies | Deliverable |
| :--- | :--- | :--- | :--- | :--- |
| **`FEAT-06`** | **Side-by-Side Diagnostic Diff Engine**<br>Compare baseline vs. current scan: classify faults into New (`🔴`), Resolved (`🟢`), Persistent (`⚪`); calculate sensor drift deltas ($\Delta$). | P0 | `DB-01`, `FEAT-01` | `lib/services/diff_service.dart` |
| **`UI-06`** | **Compare Scans Screen**<br>Inspection UI displaying DTC lifecycle and sensor variance matrix with warning flags for shifts > 10%. | P0 | `FEAT-06` | `lib/ui/compare/compare_scans_screen.dart` |
| **`FEAT-07`** | **Two-Step Protected DTC Clear (Mode 04)**<br>Safe clear workflow: pre-clear snapshot archive ➔ 3-second hold confirmation ➔ `04\r` execution ➔ automatic verification re-read. | P0 | `FEAT-01`, `DB-01` | `lib/services/dtc_clear_service.dart` |
| **`FEAT-08`** | **Battery Cranking Drop Test Engine**<br>Rapid `ATRV` polling (~20 Hz) during ignition crank; capture minimum drop voltage (< 9.6V weak, < 13.5V alternator failure). | P1 | `CORE-02`, `TRANS-01` | `lib/services/battery_test_service.dart` |
| **`FEAT-09`** | **Vector PDF Inspection Report Generator**<br>Generate multi-page PDF inspection summary via `pdf` and `printing` packages including vehicle metadata, DTCs, freeze frames, and mechanic disclaimers. | P1 | `FEAT-01`, `FEAT-06` | `lib/services/pdf_report_service.dart` |

---

### Phase 5: Hardening, Polish & App Store Distribution
| Task ID | Task Description | Priority | Dependencies | Deliverable |
| :--- | :--- | :--- | :--- | :--- |
| **`HARD-01`** | **Platform Permissions & Background Lifecycle**<br>Configure iOS `NSBluetoothAlwaysUsageDescription`, `NSLocalNetworkUsageDescription`, Android 12+ `BLUETOOTH_SCAN`/`CONNECT`, and app lifecycle pause hooks. | P0 | `TRANS-01`..`03` | Verified manifest configs |
| **`HARD-02`** | **Real Vehicle Driveway Validation**<br>Test across physical adapters (Vgate iCar Pro, Veepeak Ble, OBDLink CX) and real vehicles (CAN 500kbps, KWP2000). | P0 | All phases | Driveway test signoff |
| **`TEST-02`** | **Integration & Golden Widget Tests**<br>End-to-end integration tests (`integration_test`) covering Quick Scan, Diff compare, and live gauge rendering under synthetic data load. | P0 | All phases | CI test report |
| **`DIST-01`** | **TestFlight & Google Play Internal Track**<br>Configure Fastlane/GitHub Actions pipeline for automated beta deployment to iOS TestFlight and Google Play Console. | P0 | `HARD-01` | Active beta build |

---

## 4. Verification Gates & Definition of Done

A task or milestone is marked complete **only** when:
1. **Zero UI Thrashing:** Live gauge repaints execute via `CustomPainter` without triggering parent widget rebuilds.
2. **Immutable Snapshots:** Diagnostic scans store complete, unmodified timestamps, DTC registers, and Freeze Frame snapshots.
3. **No Unhandled Rejections:** Protocol timeout, adapter disconnect, or dirty error bytes (`NO DATA`, `?`) resolve cleanly without crashing.
4. **Zero-Blue Integrity:** All UI screens strictly adhere to the Obsidian & Champagne zero-blue palette.
