# iCAR — Design System & UI/UX Plan (v3.0 Master)

**Product Concept:** Apple Automotive Diagnostic & Telemetry Suite  
**Visual Theme:** Obsidian & Champagne (`#121317` Canvas / `#D8B17A` Accent / Strict Zero-Blue)  
**Target Ergonomics:** Dark vehicle cabin cockpit, zero driver distraction, instant peripheral comprehension  

---

## 1. Visual Philosophy & Cabin Ergonomics

Automotive user interfaces must satisfy strict constraints that ordinary mobile applications ignore:
1. **Zero-Blue Light Rule:** Blue wavelengths (440–490 nm) aggressively trigger melanopsin retinal receptors and destroy scotopic night vision adaptation in dark car cabins. iCAR enforces a strict **Zero-Blue** palette across all UI states—replacing standard blue accents with a warm, elegant **Champagne Gold** (`#D8B17A`).
2. **Peripheral Comprehension:** Important states (nominal, warning, critical redline) must be recognizable instantly in peripheral vision via unambiguous color luminance and shape contrast.
3. **Zero Horizontal Layout Jitter:** All high-frequency numerical readouts utilize monospace tabular digits (`tabular-nums`) to prevent text bounding-box width fluctuations during 15 Hz sensor polling.

---

## 2. Design Tokens & Palette Specifications

| Token Name | Hex / RGBA Value | Ergonomic Purpose |
| :--- | :--- | :--- |
| **`canvas.background`** | `#121317` | True OLED black base; zero cabin backlight bleed |
| **`surface.frosted`** | `rgba(26, 27, 31, 0.75)` | Acrylic glass cards with 1px border (`#ffffff15`) |
| **`surface.elevated`** | `rgba(38, 40, 47, 0.85)` | Bottom sheets, popovers, active dialog surfaces |
| **`accent.champagne`** | `#D8B17A` | Primary CTA buttons, tachometer sweep arc, active tabs |
| **`status.nominal`** | `#34D399` (Mint Emerald) | Passed readiness monitors, nominal temperatures, zero faults |
| **`status.warning`** | `#F59E0B` (Warm Amber) | Pending faults, incomplete drive cycles, sensor drift > 10% |
| **`status.critical`** | `#EF4444` (Crimson) | Stored DTCs, active check-engine MIL, redline warnings |
| **`text.primary`** | `#F3F4F6` (95% White) | High-contrast primary readings, fault titles |
| **`text.secondary`** | `#9CA3AF` (Muted Gray) | Units (`RPM`, `PSI`, `°C`), bus metadata, timestamps |

---

## 3. Typography & Monospace Rules

- **Display & Headings:** `SF Pro Display` (iOS) / `Inter` (Android), Semibold (600) and Bold (700).
- **Body & Captions:** `SF Pro Text` / `Inter`, Regular (400) and Medium (500).
- **Live Sensor Telemetry & DTC Codes:** `SF Mono` / `Roboto Mono` with `FontFeature.tabularFigures()` enabled to lock character kerning widths.

---

## 4. Primary Screen Specifications & Detailed Wireframes

### 4.1 Overview & System Health Hub (`SCREEN_7`)

The primary launchpad of the application. Provides instantaneous one-tap status without scrolling.

```
┌──────────────────────────────────────────────────────────┐
│ [● Vgate iCar BLE]    [500 kbps]    [12.6V]   [Golf GTI ▾]│
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │                SYSTEM STATUS: ATTENTION            │  │
│  │  1 Pending Fault Detected · 7/8 Readiness Monitors │  │
│  │                                                    │  │
│  │         [  ⚡ START COMPREHENSIVE SCAN  ]          │  │
│  │               (Tap to interrogate ECUs)            │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  SYSTEM HEALTH MATRIX                                    │
│  ┌───────────────────────┬────────────────────────────┐  │
│  │ Stored Faults         │ 0 Clear                    │  │
│  │ Pending Codes         │ 1 Flagged (P0171 Lean)     │  │
│  │ I/M Readiness         │ 7/8 Complete (EVAP Incomp) │  │
│  │ Battery Rest Circuit  │ 12.6V (Nominal AGM)        │  │
│  └───────────────────────┴────────────────────────────┘  │
│                                                          │
│  RAPID VEHICLE PROBES                                    │
│  ┌─────────────────────────┐  ┌───────────────────────┐  │
│  │  ⚡ Battery Cranking Drop│  │  📈 Live Telemetry Hub│  │
│  │  (ATRV @ 20Hz Waveform) │  │  (CustomPainter View) │  │
│  └─────────────────────────┘  └───────────────────────┘  │
│                                                          │
│  [ 📤 Ask AI Assistant ]       [ 📄 Export PDF Report ]  │
└──────────────────────────────────────────────────────────┘
```

### 4.2 Live Telemetry Cockpit (`SCREEN_6`)

High-rate telemetry rendering powered by `CustomPainter` listening to `ValueNotifier` inputs.

```
┌──────────────────────────────────────────────────────────┐
│ [Page 1 of 3]          [Live 14.8 Hz]      [🔴 REC 04:12] │
├──────────────────────────────────────────────────────────┤
│                                                          │
│                   240° SWEEP TACHOMETER                  │
│                                                          │
│                       . - ~ - .                          │
│                   . '    3850   ' .                      │
│                 /         RPM       \                    │
│                |    [ GEAR 4 ]       |                   │
│                \    Throttle: 54%    /                   │
│                  ' .   [PEAK: 6200]'                     │
│                                                          │
│  LIVE TELEMETRY QUAD                                     │
│  ┌─────────────────────────┬──────────────────────────┐  │
│  │ BOOST PRESSURE          │ COOLANT TEMPERATURE      │  │
│  │ 14.2 PSI   [Peak 18.1]  │ 91 °C        [Target 90] │  │
│  ├─────────────────────────┼──────────────────────────┤  │
│  │ STFT BANK 1             │ MASS AIR FLOW (MAF)      │  │
│  │ +4.2%      [Normal ±10] │ 18.4 g/s     [Peak 142]  │  │
│  └─────────────────────────┴──────────────────────────┘  │
│                                                          │
│  ROLLING DUAL-TRACE OSCILLOSCOPE (30 SECONDS)            │
│  ┌────────────────────────────────────────────────────┐  │
│  │ RPM (Gold) ──/\/\/\/\──/\───                       │  │
│  │ Boost (Mint)  ──/''''\──/\──                       │  │
│  └────────────────────────────────────────────────────┘  │
│  [ ⏸ Freeze Frame ]               [ 📥 Export CSV Data ]  │
└──────────────────────────────────────────────────────────┘
```

### 4.3 Diagnostics & Historical Diff Inspector (`SCREEN_4`)

Compares two temporal scans (Baseline vs. Current) to evaluate sensor drift and fault evolution.

```
┌──────────────────────────────────────────────────────────┐
│ [‹ Scans]        DIAGNOSTIC DIFF INSPECTOR      [Compare]│
├──────────────────────────────────────────────────────────┤
│ Comparing: [Oct 02 Baseline] ➔ [Oct 14 Current Scan]     │
│                                                          │
│ FAULT CODE LIFECYCLE                                     │
│ ┌─────────────────────────────────────────────────────┐  │
│ │ 🔴 NEW FAULT: P0171 (System Too Lean Bank 1)        │  │
│ │    Freeze Frame: 2400 RPM · 42 km/h · STFT +22.4%   │  │
│ │ 🟢 RESOLVED: P0301 (Cylinder 1 Misfire)             │  │
│ └─────────────────────────────────────────────────────┘  │
│                                                          │
│ SENSOR DRIFT VARIANCE MATRIX (Δ)                         │
│ ┌──────────────────────┬──────────┬──────────┬────────┐  │
│ │ Parameter            │ Baseline │ Current  │ Delta  │  │
│ ├──────────────────────┼──────────┼──────────┼────────┤  │
│ │ Long-Term Fuel Trim  │ +2.1%    │ +17.4%   │ +15.3% ⚠️│
│ │ Coolant At Operating │ 90 °C    │ 91 °C    │ +1.0 °C│  │
│ │ Battery Resting      │ 12.6 V   │ 12.1 V   │ -0.5 V ⚠️│
│ └──────────────────────┴──────────┴──────────┴────────┘  │
│                                                          │
│ PROTECTED ACTIONS                                        │
│ [ ⚠️ Clear DTCs (Mode 04) ]     [ 📄 Export Diff Report ] │
└──────────────────────────────────────────────────────────┘
```

### 4.4 Ask AI Privacy & Context Sheet

- Automatically detects Wi-Fi OBD adapter (No Internet) and prompts user to copy prompt before switching connections.
- Context toggles: Car details, active DTCs, freeze frames, and battery voltage.
- VIN is masked by default (`1VW***492`) to protect vehicle privacy.

---

## 5. Micro-Interactions & Haptic Feedback

- **Tachometer Sweep:** Smooth exponential spring damping for analog needle response.
- **DTC Clear Safeguard:** Two-step confirm modal with a 3-second hold action to prevent accidental erasure of vehicle freeze-frame history.
- **Haptic Feedback:** `HapticFeedback.lightImpact()` on quick scan actions; `HapticFeedback.heavyImpact()` on fault detection or critical redline alert.
