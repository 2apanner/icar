# iCAR — Executive Project Brief & Product Specification (v3.2 Master)

**Product Name:** iCAR (Apple Automotive OBD-II Diagnostic & Telemetry Suite)  
**Target Form Factor:** iOS & Android (Unified React Native + Expo Dev Client)  
**Design System:** Obsidian & Champagne (`#121317` Canvas / `#D8B17A` Accent / Strict Zero-Blue)  
**Status:** Approved Master Specification & Design Prototype Baseline  

---

## 1. Executive Summary & Vision Statement

**iCAR** is a calm, high-performance automotive OBD-II scanner and real-time telemetry application engineered to an **"Apple Automotive"** standard. While traditional automotive diagnostic tools suffer from cluttered web-views, banner advertisements, aggressive subscription walls, and eye-straining cabin glare, iCAR delivers an understated, distraction-free cockpit experience.

### Core Product Principles:
1. **Calm, One-Tap Clarity:** Single primary action on the Home overview initiates a comprehensive multi-module ECU health scan with instant plain-language diagnosis.
2. **macOS Frosted Elegance (Zero Blue):** Translucent acrylic containers (`rgba(255, 255, 255, 0.08)`), subtle window traffic-light indicators, and a warm champagne gold (`#D8B17A`) accent palette. **Strictly zero blue light** across all screens to preserve night-vision adaptation in dark vehicle cabins.
3. **Local-First Privacy & Zero-Cloud AI Diagnostics:** 100% on-device SAE J2012 DTC decoding. Advanced AI troubleshooting operates via native OS share-sheet handoffs (to user-installed ChatGPT, Claude, or Gemini apps) with zero backend server dependencies and automatic VIN masking.
4. **Fluid UI-Thread Rendering:** 60–120 fps hardware-accelerated gauges and rolling dual-trace oscilloscopes driven directly by Reanimated SharedValues into Skia canvas without React re-render thrashing.

---

## 2. Information Architecture & Primary Screens

The application is architected around 3 core pillars established on the canvas:

### 2.1 Overview & System Health Hub (`SCREEN_7`)
- **Header & Connection Strip:** Displays active adapter profile (*Vgate iCar Pro BLE*), live bus speed (*500 kbps*), battery resting potential (*12.6V*), and vehicle selector (*2018 Golf GTI*).
- **Hero Diagnostic Action:** Tactile, understated frosted button triggering a complete interrogation across Engine (PCM), Transmission (TCM), ABS, and Comfort gateways.
- **System Health Inspector:** Fixed-width tabular indicators displaying:
  - Stored Faults: `0 Clear`
  - Pending Faults: `1 Flagged` (`P0171 - System Too Lean`)
  - I/M Emissions Readiness: `7/8 Passed` (`EVAP Incomplete`)
  - Alternator / Battery Rest: `12.6V` (Agm starter circuit OK)
- **Immediate Action Center:** Direct triggers for *Ask AI Assistant* and *Export PDF Report*.
- **Vehicle Quick Probes:** Quick-launch modules for high-frequency Cranking Battery Drop testing and live multi-PID telemetry streaming.

### 2.2 Live Telemetry Cockpit (`SCREEN_6`)
- **240° Skia Sweep Tachometer:** High-precision analog-digital sweep arc displaying `3,850 RPM`, active gear indicator (`Gear 4`), throttle position (`TPS 54%`), peak-hold marker, and crimson redline warning.
- **Quad Live Sensor Metrics:** High-contrast tabular tiles for:
  - *Boost Pressure:* `14.2 PSI` with historical peak hold and live mini-sparkline.
  - *Coolant Temp:* `91°C` with optimal target range bar (`50°C - 120°C`).
  - *Short-Term Fuel Trim (STFT Bank 1):* `+4.2%` with bipolar normal range slider (`±10%`).
  - *Mass Air Flow (MAF):* `18.4 g/s` with discrete step indicator bar.
- **Rolling Multi-Channel Oscilloscope:** Synchronized 30-second dual-trace waveform buffer (RPM vs. Boost) with instant freeze-frame and CSV raw export.

### 2.3 Diagnostics & Historical Diff Inspector (`SCREEN_4`)
- **DTC Deep-Dive Inspector:** Detailed breakdown of active trouble codes (`P0171 - System Too Lean Bank 1`) with Mode 02 Freeze Frame snapshot (RPM, Coolant, STFT, Vehicle Speed) and heuristic confidence rating.
- **Side-by-Side Scan Comparison Engine:** Compares historical baseline (Oct 02) against current scan (Oct 14):
  - *Fault Lifecycle Triage:* Categorizes codes into `🔴 New Fault`, `🟢 Resolved Issue`, and `⚪ Persistent`.
  - *Sensor Drift Variance Matrix:* Flags numerical delta ($\Delta$) and percentage shifts (e.g., Long-Term Fuel Trim climbing $+15.3\%$ into warning territory; battery resting potential dropping $-0.5V$).
- **Safe Command Actions:** Two-step protected trigger for Mode 04 DTC Clear (with automatic pre-clear SQLite snapshot archiving) and comparative PDF export.

---

## 3. Design Tokens & Visual Specifications ("Obsidian & Champagne")

| Token | Specification / Value | Usage & Ergononics |
| :--- | :--- | :--- |
| **Canvas Background** | `#121317` (Deep Obsidian) | OLED black base, zero backlight bleed |
| **Surface Containers** | `rgba(26, 27, 31, 0.75)` | Translucent frosted glass with 1px hairline border (`#ffffff15`) |
| **Primary Accent** | `#D8B17A` (Champagne Gold) | Primary CTA buttons, tachometer sweep arc, active tabs |
| **Status Nominal** | `#34D399` (Mint Emerald) | Ready readiness monitors, normal temperatures, clear codes |
| **Status Warning** | `#F59E0B` (Warm Amber) | Pending faults, incomplete drive cycles, sensor drift flags |
| **Status Critical** | `#EF4444` (Crimson / Redline) | Stored DTCs, active MIL, redline tachometer alert |
| **Typography** | `Inter` / `SF Pro` | macOS-style headings and metadata labels |
| **Numerics** | `SF Mono` (`tabular-nums`) | Eliminates horizontal layout jitter during 15 Hz polling |

---

## 4. Hardware Transport & Protocol Architecture

1. **Bluetooth Low Energy (BLE 4.0/5.x):** Primary cross-platform transport on iOS and Android. Dynamic GATT profile probe (Vgate, Veepeak, OBDLink, Nordic UART) with 20-byte packet MTU ring buffering.
2. **Wi-Fi ELM327 (TCP Socket `192.168.0.10:35000`):** Secondary transport with automatic prompt copy caching prior to AI share-sheet handoff.
3. **Bluetooth Classic (RFCOMM):** Android-only fallback with onboard compatibility wizard explaining Apple iOS MFi restrictions.
4. **Three-Tier Priority Polling Scheduler:**
   - *Fast (10–15 Hz):* Engine Speed, Vehicle Speed, Throttle Position, Engine Load.
   - *Medium (3–5 Hz):* MAP, MAF, Timing Advance, Short/Long Fuel Trim.
   - *Slow (1 Hz):* Coolant Temp, Intake Temp, Ambient Temp, Fuel Level.
5. **Continuous Scan Archiving & Crash-Safe SQLite Storage:** Pre-clear immutable snapshots, 2.0-second batched commit writes, and Write-Ahead Logging (`WAL`) to prevent flash wear.

---

## 5. Development Roadmap & Milestones

- **Phase 1 (Complete):** Architecture definition, master PRD, visual design system, and 3 macOS-inspired mobile screen designs.
- **Phase 2 (Protocol & Transports):** BLE/Wi-Fi transport layer, half-duplex command queue, and in-app circular terminal Flight Recorder.
- **Phase 3 (Cockpit Engine):** Reanimated SharedValue to Skia gauge pipeline, 60fps waveform rendering, and batched SQLite logging.
- **Phase 4 (Diff & Battery Analysis):** Diagnostic Diff Engine, high-rate battery cranking drop test flow (`ATRV` @ ~20 Hz), and vector PDF report generation.
- **Phase 5 (Release Hardening):** iOS local network and Bluetooth permission hardening, TestFlight build, and App Store submission.
