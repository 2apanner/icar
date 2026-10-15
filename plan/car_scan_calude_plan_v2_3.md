# iCAR — Product Requirements & Architecture Plan (v2)

**Version:** 2.3 (supersedes all earlier versions)
**Platforms:** Android + iPhone from **one codebase** (React Native, truly native UI)
**Stage:** Personal use first → polish → sell on the stores if it proves good

---

## 0. What Changed From v1

| Topic | v1 | v2 |
|-------|----|----|
| App shell | Capacitor (web app in a wrapper) | **React Native + Expo (dev builds)** — real native UIKit / Android views |
| Platforms | Android only | **Android + iPhone, one codebase** |
| Look and feel | Web UI | **iOS-native feel**: native tab bar, large titles, SF Symbols, haptics, bottom sheets |
| Bluetooth | BLE or Classic | **BLE + Wi-Fi on both platforms; Classic Bluetooth on Android only** (iOS cannot do it) |
| Business goal | Personal use, zero cost | Personal use now; **commercial release path** if it works well |
| Scope | Read/clear + PDF | Adds Quick Scan, health summary, trip logging, garage, custom dashboards, battery test |
| AI explanations *(new in v2.1)* | none | **Ask AI**: send scan results to whichever AI app the user already has, via the native share sheet |

---

## 1. Product Vision

**iCAR** is a fast, clean, trustworthy OBD-II scanner. It should feel like an app Apple would have made: one obvious action on the home screen, powerful tools one tap deeper, and no dark patterns, no ad spam, no features held hostage behind confusing subscriptions.

### 1.1 Principles

1. **Simple first, powerful on demand.** The default view is calm. Advanced tools appear through progressive disclosure.
2. **One-tap value.** A big **Quick Scan** button connects, reads the car, and gives a plain-language health summary.
3. **Native feel.** Platform conventions, system fonts, haptics, dark mode, Dynamic Type, smooth 60 fps gauges.
4. **Robust over clever.** Cheap adapters misbehave. The app must survive dropouts, clones, and slow ECUs without crashing or lying.
5. **Honest.** Codes are symptoms, not verdicts. Never invent data. Clear warnings before anything that changes car state.
6. **Local-first.** Works offline. Data stays on the device unless the user shares a report.

### 1.2 Goals

| # | Goal |
|---|------|
| G1 | Connect reliably to ELM327-compatible adapters over BLE, Wi-Fi, and (Android) Classic Bluetooth |
| G2 | Smooth real-time dashboard with customizable gauges and graphs |
| G3 | Read stored, pending, and permanent DTCs with plain-language explanations |
| G4 | Clear DTCs safely, with a pre-clear snapshot |
| G5 | Freeze frame, readiness monitors, VIN, vehicle info |
| G6 | Trip and session logging with replay, CSV export, and PDF reports |
| G7 | iPhone-native look and feel on both platforms |
| G8 | Store-ready quality: stable, accessible, privacy-friendly, well tested |
| G9 | One-tap **Ask AI**: hand scan results to ChatGPT, Gemini, Claude, or any AI app on the phone for a detailed explanation |

### 1.3 Non-Goals (v1 release)

- Manufacturer coding, tuning, module programming, or service resets (BMW ISTA/INPA/Bimmercode-style). Proprietary protocols, extra hardware (e.g. K+DCAN/ENET), and real safety and legal risk. Now an optional, separately loaded beta pack for personal use only: see sections 6.8 and 6.9.
- Cloud accounts or a backend (v1 is fully local).
- CarPlay / Android Auto (needs special entitlements; later).
- Mode 08 or any control/actuator commands.

---

## 2. Platform Reality Check (read this first)

### 2.1 Adapter compatibility matrix

| Adapter type | Android | iPhone |
|--------------|---------|--------|
| **Bluetooth Classic** (cheap blue/black mini adapters, very common) | Works | **Does NOT work.** iOS gives apps no access to Classic Bluetooth serial (RFCOMM). The only exceptions are adapters in Apple's MFi program (e.g. OBDLink MX+, vLinker FS/MS). |
| **Bluetooth LE (BLE / "4.0")** | Works | **Works** |
| **Wi-Fi ELM327** | Works | **Works** (phone joins the adapter's Wi-Fi, so it loses mobile internet while connected) |
| **Dual-mode (Classic + BLE)**, e.g. Vgate iCar Pro BLE | Works | Works (via BLE) |

**Consequences**
- The adapter you already own may be Classic. If so, it will work on Android but never on iPhone.
- For iPhone testing, **buy a BLE adapter** (or a Wi-Fi one). Dual-mode BLE adapters are the most flexible for a developer.
- The app must clearly tell users which adapter types work on their phone. This is the number-one cause of bad reviews in this category, so handle it in onboarding.

### 2.2 iPhone build and signing

| Item | Free (personal use) | Paid ($99/yr) |
|------|---------------------|---------------|
| Install on your own iPhone | Yes, via Xcode + free Apple ID ("Personal Team") | Yes |
| Profile validity | **7 days** — rebuild/reinstall weekly | 1 year |
| Limits | About 3 apps per device, 3 devices, 10 App IDs, some capabilities unavailable | Full |
| TestFlight / App Store | **No** | Yes |
| Requires a Mac with Xcode | **Yes** | Yes |

- **You need a Mac with Xcode** for iPhone builds. Xcode itself is free.
- Alternative for personal use without weekly Xcode work: unofficial re-signing tools such as AltStore or Sideloadly can refresh a free-Apple-ID install, but they are third-party and not for distribution.
- Apple Developer Program: **$99/year**. Google Play: **$25 one time**. Both are needed only when you publish.
- Verify current fees and limits on Apple's and Google's sites before paying.

### 2.3 Android

- Free: Android Studio, USB debugging, install directly. No expiry.
- Classic Bluetooth is supported via a separate plugin (see tech stack), so cheap adapters work on Android.

---

## 3. Technology Choice: Why React Native

| Option | Native feel | One codebase | Skills fit | Verdict |
|--------|-------------|--------------|------------|---------|
| Capacitor (web in a wrapper) | Web-like, hard to make feel truly native | Yes | Great | Rejected: you asked for a direct native feel |
| **React Native + Expo** | **Real native components** (UITabBar, native stack, native alerts/sheets) | **Yes** | Great (TypeScript/React) | **Chosen** |
| Flutter | Draws its own pixels; Cupertino widgets imitate iOS | Yes | New language (Dart) | Strong alternative |
| Fully native (Swift + Kotlin) | Best | **No** (two codebases) | Two new stacks | Rejected: doubles the work |

**Notes**
- Bluetooth needs custom native code, so use **Expo dev builds** (development client), **not Expo Go**.
- Keep all OBD/protocol logic in **pure TypeScript** with no React Native imports, so it is unit-testable on a laptop and reusable.

---

## 4. Architecture

### 4.1 Layers

```
┌────────────────────────────────────────────────────┐
│                     UI (React Native)               │
│ Home · Dashboard · Codes · Garage · Logs · Settings │
└──────────────────────────┬─────────────────────────┘
                           │ state / events (Zustand)
┌──────────────────────────▼─────────────────────────┐
│                  App Services                       │
│ ConnectionService · LiveDataService · DtcService    │
│ ScanService (Quick Scan) · LogService · ReportService│
└──────────────────────────┬─────────────────────────┘
                           │ typed requests
┌──────────────────────────▼─────────────────────────┐
│               OBD Core (pure TypeScript)            │
│ Command queue · Poll scheduler · Mode handlers      │
│ PID registry · DTC decoder · ISO-TP reassembly      │
│ Adapter quirk profiles · Unit conversion            │
└──────────────────────────┬─────────────────────────┘
                           │ ASCII lines
┌──────────────────────────▼─────────────────────────┐
│              ELM327 Protocol Layer                  │
│ Init · AT commands · '>' framing · error parsing    │
└──────────────────────────┬─────────────────────────┘
                           │ bytes
┌──────────────────────────▼─────────────────────────┐
│               Transport (interface)                 │
│ BleTransport │ WifiTcpTransport │ ClassicTransport  │
│ (Android only) │ MockTransport (simulated car)      │
└────────────────────────────────────────────────────┘
```

### 4.2 Transport interface

```ts
interface Transport {
  readonly kind: 'ble' | 'wifi' | 'classic' | 'mock';
  connect(target: AdapterTarget): Promise<void>;
  disconnect(): Promise<void>;
  write(command: string): Promise<void>;        // appends '\r'
  onData(cb: (chunk: string) => void): Unsubscribe;
  onClose(cb: (reason?: string) => void): Unsubscribe;
  isConnected(): boolean;
}
```

Because every transport hides behind this interface, a flaky or abandoned Bluetooth plugin can be swapped without touching the rest of the app.

### 4.3 Tech stack

| Concern | Choice | Notes |
|---------|--------|-------|
| Language | TypeScript (strict) | |
| Framework | React Native + Expo (dev client, CNG/prebuild) | Not Expo Go |
| Navigation | Expo Router or React Navigation (native stack + native bottom tabs) | Gives true iOS push transitions and large titles |
| State | Zustand | Small, simple |
| BLE | `react-native-ble-plx` or `react-native-ble-manager` | **Verify maintenance when you start.** The upstream ble-plx project has been described as slow-moving, and community forks exist for newer RN/Expo versions. BLE-only; no Classic. |
| Wi-Fi adapters | `react-native-tcp-socket` | Typical adapter address is `192.168.0.10:35000` (configurable) |
| Classic Bluetooth (Android only) | `react-native-bluetooth-classic` | Verify it is maintained for your RN version |
| Gauges / graphs | `@shopify/react-native-skia` + `react-native-reanimated` | 60 fps custom gauges, live charts |
| Icons | SF Symbols via `expo-symbols` (iOS), Material fallback (Android) | |
| Haptics | `expo-haptics` | Success/warning/selection feedback |
| Storage | `expo-sqlite` (history, logs, DTC DB) + MMKV or AsyncStorage (settings) | |
| PDF | `expo-print` (HTML → PDF) + `expo-sharing` | Native share sheet |
| Ask AI handoff | React Native `Share` API (text) + `expo-clipboard` + `Linking` | Share sheet for text, clipboard fallback, optional web quick-links |
| Keep awake | `expo-keep-awake` | Dashboard |
| Purchases (later) | RevenueCat or direct StoreKit/Play Billing | Verify current pricing and terms |
| Testing | Jest (core logic), Detox or Maestro (UI flows) | |

Confirm each package's compatibility with your Expo SDK / React Native version before committing. These ecosystems move fast.

---

## 5. Native iPhone Look and Feel (design spec)

### 5.1 Navigation

**Bottom tab bar (5 tabs)** — native tab bar, SF Symbols:

| Tab | Icon idea | Purpose |
|-----|-----------|---------|
| **Home** | `car` / `bolt.car` | Connection status, **Quick Scan**, health summary |
| **Live** | `gauge.with.dots.needle.67percent` | Dashboard of gauges and graphs |
| **Codes** | `exclamationmark.triangle` | Trouble codes, freeze frame, readiness |
| **Logs** | `chart.xyaxis.line` | Trips, sessions, recordings, reports |
| **Settings** | `gearshape` | Adapter, units, appearance, about |

Garage (multiple vehicles) lives as a header menu on Home to keep the tab bar to five.

### 5.2 Visual language

- Large collapsing navigation titles, system font (SF Pro on iOS, Roboto/system on Android), Dynamic Type support.
- Grouped inset lists for settings and details (iOS Settings-app style).
- **Bottom sheets** for connection picker, PID picker, and details (native-feeling `presentation: 'formSheet'` / sheet modals).
- **Action sheets and alerts** for destructive actions (Clear Codes).
- Haptics: light tap on selection, success haptic on scan complete, warning haptic on alerts.
- Dark mode first (good in a car), light mode supported, follows system.
- Large touch targets, glanceable numbers, no clutter. Respect safe areas and the Dynamic Island.
- Smooth, interruptible animations; skeleton states instead of spinners where possible.
- Platform-adaptive: same code, small `Platform.select` tweaks so Android uses system conventions where they matter (back behaviour, ripple).

### 5.3 Home screen (the "simple" part)

```
┌─────────────────────────────┐
│  iCAR                  ⓘ ▾  │  ← large title, Garage menu
│                             │
│  ● Connected · Vgate BLE    │  ← tappable connection chip
│                             │
│  ┌───────────────────────┐  │
│  │      QUICK SCAN       │  │  ← one big primary action
│  └───────────────────────┘  │
│                             │
│  Last scan · Today 9:41     │
│  ✓ No active codes          │
│  ⚠ 2 readiness incomplete   │
│  Battery 12.6 V             │
│                             │
│  Live data  ›   Codes  ›    │
└─────────────────────────────┘
```

**Quick Scan** flow: connect (if needed) → init → detect protocol → read VIN → read stored/pending/permanent codes → read readiness monitors → read battery voltage → show a **Health Summary** card with plain-language status (Good / Attention / Problem) and "Share report" and **"Ask AI"** actions.

### 5.4 Live dashboard (the "power" part)

- Pages the user swipes between (like iOS home screen pages); each page is a configurable grid.
- Widget types: **round gauge**, **bar gauge**, **digital value**, **mini graph**, **multi-PID overlay graph**.
- Edit mode (long-press, wiggle-style): drag to reorder, tap to change PID, resize tiles.
- Threshold colouring (e.g. coolant turns amber/red), optional alert haptic.
- Always-visible refresh-rate indicator (e.g. "8.2 Hz") so users understand adapter limits.
- Record button; recordings land in Logs.
- Keep-awake while this tab is active.

### 5.5 Codes screen

- Segmented control: **Stored · Pending · Permanent**.
- Each row: code, short title, severity chip. Tap → detail sheet: description, possible causes (only if the data source has them), freeze frame, "Copy" and "Share".
- Toolbar action **Clear Codes** → native action sheet with plain-language consequences → pre-clear snapshot saved → clear → re-read → success haptic and result banner.
- Readiness monitors card (I/M status) with a clear "Ready / Not ready" for each monitor.
- **Ask AI** button (toolbar, and inside each code's detail sheet) opens the Ask AI sheet (see section 6.7).

### 5.6 Logs screen

- List of trips and recordings with date, duration, vehicle.
- Detail: scrubbable multi-PID graph, stats (max/min/avg), export CSV or PDF, delete (swipe action).
- **Replay mode:** play a recorded session back through the dashboard.

### 5.7 Settings

Adapter (choose/forget, connection type), units (metric/imperial), appearance, refresh-rate mode, alerts, data (export/clear), debug log, about/privacy/disclaimer, and (later) Pro unlock/restore purchases.

---

## 6. Functional Requirements

### 6.1 Connection and adapters

- FR-1: Discover adapters by connection type available on the platform (BLE scan, saved Wi-Fi profile, Android paired Classic list).
- FR-2: Onboarding screen that explains which adapters work on iPhone vs Android, with a "Test my adapter" flow.
- FR-3: Run the init sequence and detect protocol, adapter version, and clone quirks.
- FR-3a: **Right after init, read the VIN automatically** and show the connected car (make, model, year, VIN) with the connection time on Home before scanning starts.
- FR-4: Auto-reconnect with exponential backoff; manual reconnect; clear status chip.
- FR-5: Remember last adapter per vehicle.
- FR-6: Human-readable errors (ignition off, adapter busy, no ECU response, protocol not found, wrong adapter type for this phone).

### 6.2 Live data

- FR-7: Discover supported PIDs (00/20/40/60/80/A0/C0 bitmasks) and expose only supported ones.
- FR-8: Priority-tiered polling; measured Hz displayed.
- FR-9: User-configurable pages and widgets; persistence per vehicle.
- FR-10: Unit conversion, thresholds, alerts.
- FR-11: Continuous recording to SQLite (crash-safe: write as you go, not at the end).

### 6.3 Diagnostics

- FR-12: Read Modes 03 (stored), 07 (pending), 0A (permanent); MIL status and count from PID 01.
- FR-13: Freeze frame (Mode 02).
- FR-14: Clear DTCs (Mode 04) with confirmation, pre-clear snapshot, and verification re-read.
- FR-15: Readiness monitors from PID 01 (and PID 41 for the current drive cycle).
- FR-16: Optional Mode 06 on-board test results (advanced, phase 3).

### 6.4 Vehicle and garage

- FR-17: Read the VIN automatically after connecting (Mode 09 PID 02), plus calibration IDs where available. Show it on Home and in the vehicle profile. If the car does not report a VIN, show "VIN not available" and offer manual entry, clearly labelled as manual.
- FR-18: Garage with multiple vehicles (name, VIN, notes, preferred adapter, dashboard layout).
- FR-19: Optional online VIN decode (e.g. NHTSA's free vPIC API) to fill make/model/year, clearly optional and cached. The app must still work fully offline.

### 6.5 Tools (power features)

| Tool | What it does | Notes |
|------|--------------|-------|
| Battery / charging test | Watches voltage at rest, during cranking, and while running; reports pass/attention | Uses `ATRV` and/or PID 42; show assumptions |
| Trip computer | Distance, time, average/max speed, fuel use | Fuel from MAF or fuel-rate PIDs when supported; show estimates as estimates |
| Engine-start capture | High-rate logging for the first minute after connection | Cranking voltage and RPM trace |
| Performance timer (0–100 km/h, 0–60 mph) | Timing runs from speed PID | Safety warning: closed roads only; consider launching it later |
| CSV export | Raw samples for spreadsheets | |

### 6.6 Reports

- FR-20: PDF report with the required header below, then DTCs with descriptions, freeze frame, readiness, battery, key live snapshot, optional graph images, and disclaimer.
- FR-21: Share through the native share sheet (Messages, Mail, WhatsApp, Files, AirDrop).
- FR-22: Report templates: **Quick Health**, **Full Diagnostic**, **Trip Summary**.

**Report header (required on every report)**
- **Car:** make, model, year, as confirmed in the vehicle profile.
- **VIN:** as read from the car, or marked "entered manually" if typed in, or "VIN not available".
- **Report date and time:** local time with timezone (for example "13 Oct 2026, 9:41 AM"), stored internally as UTC. If the scan happened earlier than the report was generated, show both.
- Adapter and protocol, app version, and a report ID.
- A **Hide VIN** toggle on the share screen. VIN is included by default in PDF reports (unlike Ask AI, where it is off by default), and the user decides before sharing.

### 6.7 Ask AI: Send Results to Any AI App (new in v2.1)

After a scan, the user can send the results to whichever AI app they already use (ChatGPT, Gemini, Claude, Copilot, etc.) and get a detailed, plain-language explanation. The app builds the prompt; the phone's native share sheet does the delivery.

**Why this approach**
- No API keys, no accounts, no backend, no per-request cost for you.
- Same code on iPhone and Android.
- The user stays in control of what is shared and where it goes.
- Generating the prompt works offline; the AI app needs internet.

**Flow**
1. Entry points: Home health summary, Codes toolbar, and each code's detail sheet.
2. **Ask AI sheet** (native bottom sheet) shows a live preview of the prompt, which the user can edit, plus the toggles below and an optional **Symptoms** box ("rough idle since last week").
3. **Share...** opens the native share sheet; the user taps their AI app and the text arrives ready to send.
4. **Copy** puts the prompt on the clipboard with a success haptic and a toast: "Copied. Paste it into your AI app." This is the fallback for apps that don't accept shared text.
5. Optional quick-link row (ChatGPT, Gemini, Claude) that opens the app or site with the question prefilled where that app supports it. Link support changes and is inconsistent between apps, so verify before launch and always keep Share and Copy as the reliable paths.

**What gets included (toggles)**

| Item | Default |
|------|---------|
| Vehicle make / model / year (if known) | On |
| Trouble codes with descriptions and status | On |
| Freeze-frame values | On |
| Readiness monitors | On |
| Battery voltage | On |
| Live-data snapshot | Off |
| **VIN** | **Off** |
| Mileage (user typed) | Optional |
| Symptoms (user typed) | Optional |

**Prompt template (plain text, no markdown tables, for maximum compatibility)**

```
I scanned my car with an OBD-II scanner. Please help me understand the results.

Vehicle: {year} {make} {model} {engine / fuel type if known}
Mileage: {user-entered or "unknown"}

Check-engine light: {on / off}

Trouble codes:
- {P0301} (stored): {description}
- {P0171} (pending): {description}

Freeze frame for {P0301}: RPM {2150}, coolant {88} {°C}, load {54} %, speed {62} {km/h}, short-term fuel trim {+4} %

Readiness monitors not ready: {list or "none"}
Battery voltage: {12.6} V

Symptoms I have noticed: {user text or "none"}

Please:
1. Explain each code in plain language.
2. List the most likely causes, from most to least common, for this vehicle if you know it.
3. Tell me what to check first, cheapest and easiest first.
4. Say whether it is safe to keep driving and how urgent this is.
5. Give me questions to ask a mechanic.

If you are unsure about anything, say so clearly instead of guessing. Do not tell me to ignore safety-related warnings.
```

The prompt follows the app's language setting and the user's chosen units.

**Rules**
- Always show the exact text before it is shared, and let the user edit it.
- VIN is excluded by default. Location and other personal data are never included.
- The app itself never transmits scan data. The handoff happens through the operating system, and the privacy policy must say so.
- Show a short disclaimer under the buttons: "AI suggestions are not a diagnosis. Check with a qualified mechanic, especially for brakes, airbags, steering, or fuel."
- For safety-critical code families (for example ABS/chassis `C` codes and airbag-related `B` codes), show the app's own "see a professional" banner regardless of what any AI says.
- Keep the prompt short enough for chat inputs: cap the number of codes and freeze-frame values, and leave out the live snapshot unless the user turns it on.

**Implementation notes**
- Build the prompt in pure TypeScript: `buildAiPrompt(scan, options)`, in `src/core` so it is unit-testable. Add snapshot tests for each toggle combination and for both unit systems.
- Share text with React Native's built-in `Share.share({ message })`. Copy with `expo-clipboard`.
- If you probe for installed apps with `canOpenURL` on iOS, declare the schemes in `LSApplicationQueriesSchemes`. The share sheet itself needs no declaration.

**Acceptance criteria**
- Prompt generates in well under a second and shows a preview.
- Share and Copy both work on iPhone and Android.
- VIN is never included unless the user turns it on.
- Tested against at least three different AI apps on each platform.
- Safety banners appear for the defined code families.

**Possible later upgrade (not v1):** a built-in AI chat inside iCAR using an API. This needs a backend or bring-your-own-key, cost controls, and a privacy policy update, so keep it out of the first release.

### 6.8 Vehicle Profile and Car-Based Tool Loading (new in v2.2)

The app loads tools based on the car that is connected. Core tools work on any OBD-II car; make-specific tools appear only when the car and the adapter support them.

**Flow**
1. Connect and initialize the adapter.
2. Read the VIN (Mode 09, PID 02). Decode make, model and year from the VIN offline where possible, with the optional online lookup as a bonus. If the VIN can't be read, ask the user to pick make, model and year.
3. Detect protocol, supported PIDs, and which control units answer.
4. Build a **Vehicle Profile** and show it for confirmation ("BMW 3 Series, 2016. Looks right?") with an Edit option. Save it to the Garage.
5. The **tool registry** evaluates every tool against the profile and the adapter, then loads only the ones that apply.

**Tool registry**

```ts
interface VehicleProfile {
  make?: string; model?: string; year?: number;
  platform?: string;               // e.g. a make-specific series/generation
  vin?: string;
  protocol: string;
  respondingEcus: string[];
  supportedPids: number[];
  adapter: { transport: 'ble' | 'wifi' | 'classic'; capabilities: string[] };
}

type Applicability = { available: boolean; reason?: string };

interface ToolModule {
  id: string;
  title: string;
  risk: 'read' | 'low' | 'high';          // drives confirmation and backup rules
  appliesTo(p: VehicleProfile): Applicability;
  load(): Promise<ToolScreens>;           // lazy-loaded so the app stays light
}
```

**Tool groups**

| Group | Loads when | Examples |
|-------|-----------|----------|
| Core | Any OBD-II car | Live data, codes, freeze frame, readiness, battery test, reports, Ask AI |
| Make pack (BMW first) | Profile make matches and adapter can talk to the car's control units | Service reset, coding |
| Future packs | Added per make later | Make-specific extra PIDs and tools |

**Rules**
- Show only tools that apply. If a tool needs something the user lacks, show it disabled with the reason ("Coding needs a BMW-capable adapter") so they know what to buy or change.
- Every tool has a risk level. `read` tools run freely; anything that writes follows the safety rules in 6.9.
- Packs load lazily. Downloaded content must be **data only**, never executable code, to stay within app store rules (verify current policy before shipping).
- The user can override the detected profile; the override is saved per vehicle.

### 6.9 BMW Tools (Beta, Personal Use First) (new in v2.2)

**Service reset:** list of service items (engine oil, brake pads, brake fluid, vehicle check, coolant) with status, a confirmation step that says the reset should only follow real service, and a service history log.

**Coding:** module picker, searchable feature list, pending-change bar showing current and new values, and Apply to car.

**Safety rules for anything that writes**
- Read and save a **backup** of the module before any change; show Restore at all times.
- Show every pending change as "current → new" and require confirmation.
- Require ignition on, car parked, and a battery charger recommended; refuse to start if voltage is too low.
- Write one module at a time, verify by reading back, and log the result.
- Never offer changes that disable safety systems.

**Technical notes**
- BMW tools use BMW's own diagnostic protocols, not generic OBD-II. The open-source EdiabasLib project is a reference for how the Deep OBD for BMW Android app talks to the car.
- It needs BMW ECU data files (.prg/.grp), which are BMW's proprietary data. Users must supply their own; never bundle them.
- Adapter support varies: some ELM327-based Bluetooth and Wi-Fi adapters, FTDI-based cables, and ENET adapters on newer models. Adapters sold for BMW coding apps (for example the Vgate vLinker BM+) are the safest bet. Verify adapter requirements for the target series before buying.
- Keep this pack behind a feature flag and **out of store builds** until legal review is done.

---

## 7. OBD and ELM327 Technical Details

### 7.1 Communication

- ASCII commands ending `\r`; responses end with the prompt `>`. Frame by waiting for `>`.
- One command in flight at a time (queue + mutex).
- Common replies: `NO DATA`, `UNABLE TO CONNECT`, `CAN ERROR`, `BUS INIT: ...ERROR`, `?`, `STOPPED`, `SEARCHING...`.

### 7.2 Init sequence

| Command | Purpose |
|---------|---------|
| `ATZ` | Reset; wait ~1 s; capture version string |
| `ATE0` | Echo off |
| `ATL0` | Linefeeds off |
| `ATS0` | Spaces off |
| `ATH0` (or `ATH1` for multi-ECU work) | Headers off/on |
| `ATAT1` / `ATAT2` | Adaptive timing (2 = more aggressive, faster) |
| `ATSP0` | Auto protocol |
| `0100` | First real request; triggers protocol search; supported PIDs 01–20 |
| `ATDPN` | Detected protocol number |
| `ATRV` | Battery voltage at the port |

**Quirk profiles:** cheap clones advertised as "v2.1" often ignore or mishandle some commands. Detect via `ATZ`/`ATI` string and behaviour, then apply a profile (retry counts, delays, skip unsupported AT commands, avoid aggressive timing). Treat `?` on optional commands as non-fatal.

### 7.3 Request / response

```
Request:   010C
Response:  410C1AF8        → RPM = (0x1A*256 + 0xF8) / 4 = 1726 rpm
```

- Strip whitespace, `SEARCHING...`, `>`.
- Match the expected header (`41` + PID).
- Multiple ECUs answer on multiple lines; prefer the engine ECU (commonly `7E8` with headers on).
- Multi-frame (CAN ISO-TP) responses for VIN and long code lists arrive as indexed lines (`0:`, `1:`...); reassemble before decoding.

### 7.4 Services

| Mode | Purpose | Release |
|------|---------|---------|
| 01 | Live data | v1 |
| 02 | Freeze frame | v1 |
| 03 | Stored DTCs | v1 |
| 04 | Clear DTCs | v1 (confirmed) |
| 06 | On-board test results | later |
| 07 | Pending DTCs | v1 |
| 09 | Vehicle info (VIN) | v1 |
| 0A | Permanent DTCs | v1 |
| 08 | Control of systems | **never in v1** |
| 22 | Manufacturer-specific enhanced data | later, per make |

### 7.5 PID reference (Mode 01)

A = first data byte, B = second.

| PID | Name | Formula | Unit |
|-----|------|---------|------|
| 00/20/40/60/80/A0/C0 | Supported-PID bitmasks | bit test, MSB = lowest PID | — |
| 01 | Monitor status | MIL = `A & 0x80`; count = `A & 0x7F` | — |
| 04 | Engine load | `A*100/255` | % |
| 05 | Coolant temp | `A-40` | °C |
| 06 / 07 | Short / long fuel trim (bank 1) | `A*100/128 - 100` | % |
| 0B | Intake manifold pressure | `A` | kPa |
| 0C | RPM | `(256A+B)/4` | rpm |
| 0D | Speed | `A` | km/h |
| 0E | Timing advance | `A/2 - 64` | ° |
| 0F | Intake air temp | `A-40` | °C |
| 10 | MAF | `(256A+B)/100` | g/s |
| 11 | Throttle position | `A*100/255` | % |
| 1F | Run time since start | `256A+B` | s |
| 2F | Fuel level | `A*100/255` | % |
| 33 | Barometric pressure | `A` | kPa |
| 42 | Control module voltage | `(256A+B)/1000` | V |
| 46 | Ambient air temp | `A-40` | °C |
| 5C | Oil temp | `A-40` | °C |
| 5E | Engine fuel rate | `(256A+B)/20` | L/h |

Always check supported-PID bitmasks first and hide unsupported PIDs. Verify every formula against SAE J1979 or a public PID table and cover each with a unit test using known sample responses.

### 7.6 DTC decoding

Two bytes per code: top 2 bits → letter (`00 P`, `01 C`, `10 B`, `11 U`), next 2 bits → first digit, remaining 12 bits → 3 hex digits. Skip `00 00` padding. On CAN, the Mode 03/07/0A response commonly carries a count byte after the header; older protocols don't. Handle both and test with captured logs.

```ts
function decodeDtc(b1: number, b2: number): string {
  const letter = ['P', 'C', 'B', 'U'][(b1 & 0xC0) >> 6];
  const d1 = (b1 & 0x30) >> 4;
  const d2 = (b1 & 0x0F).toString(16).toUpperCase();
  const d34 = b2.toString(16).toUpperCase().padStart(2, '0');
  return `${letter}${d1}${d2}${d34}`;
}
```

### 7.7 DTC description data

- Bundle an offline database in SQLite.
- A public open-source DTC database exists on GitHub (roughly 28,000 codes: generic SAE J2012 plus manufacturer-specific for 30+ brands). **Check its license allows commercial use before shipping it in a paid app.** If it doesn't, build your own generic table from public SAE J2012 code names and write your own descriptions.
- Lookup order: make-specific (when VIN gives the make) → generic → "Description not available."
- Severity and "common causes" must come from a reliable source or be written by you. Do not auto-generate causes and present them as fact.

### 7.8 Polling engine

- Tiers: fast (RPM, speed, throttle, load) every cycle; medium (MAF, timing, fuel trims) every ~3rd; slow (temps, fuel level, voltage) every ~10th.
- Poll only PIDs that are both supported and currently visible on screen.
- Pause polling for DTC reads, clears, and user-initiated commands, then resume.
- Per-command timeout with retry and back-off; mark a PID unavailable after repeated failures.
- Try multi-PID requests (up to 6 PIDs in one Mode 01 request) as an optimization after feature detection.
- Measure and display actual Hz. Stop polling when the Live tab isn't visible or the app is backgrounded.

---

## 8. Data Model

```ts
interface Vehicle {
  id: string;
  name: string;
  vin?: string;
  make?: string; model?: string; year?: number;
  preferredAdapterId?: string;
  protocol?: string;
  supportedPids?: number[];
  dashboardLayout?: DashboardPage[];
}

interface Sample { t: number; pid: number; value: number; }

interface Dtc {
  code: string;
  status: 'stored' | 'pending' | 'permanent';
  description?: string;
  severity?: 'info' | 'caution' | 'serious';
}

interface ScanResult {
  id: string;
  vehicleId: string;
  at: number;                // epoch ms (UTC); shown in local time with timezone
  vin?: string;              // VIN as read at scan time, kept even if the vehicle record changes later
  timezone?: string;         // IANA zone name at scan time
  milOn: boolean;
  dtcs: Dtc[];
  freezeFrame?: Record<number, number>;
  readiness?: Record<string, 'ready' | 'not_ready' | 'n/a'>;
  batteryVolts?: number;
  clearedAt?: number;
}

interface Recording {
  id: string; vehicleId: string;
  startedAt: number; endedAt?: number;
  pids: number[];
  // samples stored in a separate SQLite table, written continuously
}
```

```ts
interface AskAiOptions {
  includeVehicle: boolean;      // make / model / year (default true if known)
  includeCodes: boolean;        // default true
  includeFreezeFrame: boolean;  // default true
  includeReadiness: boolean;    // default true
  includeBattery: boolean;      // default true
  includeLiveSnapshot: boolean; // default false
  includeVin: boolean;          // default FALSE
  mileage?: string;             // optional, user typed
  symptoms?: string;            // optional, user typed
  language: string;             // follows app language
  units: 'metric' | 'imperial'; // follows settings
}
```

SQLite tables: `vehicles`, `scans`, `recordings`, `samples`, `dtc_descriptions`, `settings`.

---

## 9. Project Structure

```
icar/
├─ app/                      # Expo Router screens
│  ├─ (tabs)/home.tsx
│  ├─ (tabs)/live.tsx
│  ├─ (tabs)/codes.tsx
│  ├─ (tabs)/logs.tsx
│  ├─ (tabs)/settings.tsx
│  └─ sheets/                # connection picker, pid picker, dtc detail
├─ src/
│  ├─ core/                  # pure TS, no React Native imports
│  │  ├─ elm327/             # init, framing, parsing, quirks
│  │  ├─ obd/                # pid registry, modes, dtc decode, scheduler
│  │  └─ units/
│  ├─ transports/            # ble, wifi, classic, mock
│  ├─ services/              # connection, live, dtc, scan, log, report, askAi
│  ├─ db/                    # sqlite schema + queries + dtc data
│  ├─ ui/                    # components: gauges, charts, tiles, sheets
│  └─ store/                 # zustand stores
├─ assets/dtc/               # bundled DTC data
├─ tests/                    # unit tests with recorded ELM327 logs
└─ app.json                  # permissions, usage strings, plugins
```

---

## 10. Platform Configuration

**iOS (`Info.plist` via Expo config)**
- `NSBluetoothAlwaysUsageDescription` — clear reason string.
- `NSLocalNetworkUsageDescription` — needed for Wi-Fi adapters on the local network.
- Background modes: not required for v1; avoid unless you add background logging.
- `LSApplicationQueriesSchemes`: only needed if you probe for installed AI apps with `canOpenURL`. Not needed for the share sheet or normal web links.

**Android**
- Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`.
- Android 11 and below: `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION` (for BLE scanning).
- Runtime permission flow with a friendly explanation screen.

**Both:** keep-awake on Live tab; handle Bluetooth/Wi-Fi turned off; handle app backgrounding by pausing polling and cleanly reconnecting on resume.

---

## 11. Development Setup

```bash
# 1. Create the app
npx create-expo-app@latest icar
cd icar

# 2. Dev client + core modules
npx expo install expo-dev-client expo-sqlite expo-print expo-sharing \
  expo-keep-awake expo-haptics expo-symbols react-native-reanimated \
  @shopify/react-native-skia

# 3. Bluetooth / Wi-Fi (verify packages first, see section 4.3)
npm install react-native-ble-plx react-native-tcp-socket
npm install react-native-bluetooth-classic        # Android Classic only

# 4. State
npm install zustand

# 5. Generate native projects and run
npx expo prebuild
npx expo run:android --device        # Android phone via USB debugging
npx expo run:ios --device            # iPhone — requires Mac + Xcode + free Apple ID signing
```

- Android: USB debugging, no cost, no expiry.
- iPhone (free): Xcode signs with your Personal Team; trust the profile on the phone (Settings → General → VPN & Device Management); **reinstall every 7 days**.

---

## 12. Testing and Quality

| Level | Approach |
|-------|----------|
| Unit | Every PID formula, DTC decode, bitmask decode, response parser (single/multi-line, multi-ECU, ISO-TP), unit conversions |
| Protocol | `MockTransport` replaying captured ELM327 conversations including errors (`NO DATA`, `?`, `CAN ERROR`, timeouts, dropouts mid-command) |
| Simulator | Open-source ELM327 emulator (e.g. `ELM327-emulator`) to simulate an ECU without a car |
| Real car | Ignition on/engine off first, then running; test on at least two different vehicles and several adapters before selling |
| UI | Maestro or Detox flows for Quick Scan, clear codes, report share |
| Device matrix | A recent iPhone, an older iPhone, a mid-range Android, a low-end Android |
| Field logs | Built-in debug log (raw TX/RX with timestamps) + "export log" so users can send you bug reports |

Record real sessions (with permission) as regression fixtures. Adapter and ECU quirks are the main source of bugs.

---

## 13. Roadmap

| Phase | Deliverable |
|-------|-------------|
| **M0 — Setup** | Confirm adapters owned (Classic vs BLE vs Wi-Fi). Get Mac + Xcode working. Hello-world builds on both phones. |
| **M1 — Connect** | Transport interface, BLE + Mock, ELM327 init, `ATRV` and `0100`, debug log screen |
| **M2 — Core reads** | PID registry, supported-PID discovery, parser with full unit tests |
| **M3 — Live** | Poll scheduler, native-feel dashboard, gauges, Hz indicator, reconnect logic |
| **M4 — Codes** | Modes 03/07/0A, DTC decode, offline descriptions, freeze frame, safe Clear flow |
| **M5 — Home + Quick Scan** | One-tap scan, health summary, readiness monitors, VIN, battery |
| **M6 — Logs + Reports** | Continuous recording, replay, CSV, PDF reports, share sheet |
| **M6.5 — Ask AI** | Prompt builder (pure TS + tests), Ask AI sheet with preview, privacy toggles, symptoms box, share/copy flow, safety banners |
| **M7 — Wi-Fi + Classic** | WifiTcpTransport, ClassicTransport (Android), adapter onboarding |
| **M8 — Polish** | Customizable dashboards, thresholds/alerts, garage, accessibility, dark/light, haptics, empty states |
| **Personal use ships here** | Daily-driver on your own phones |
| **M9 — Beta** | Android internal testing track; TestFlight (needs paid Apple account); 10–30 testers with varied cars and adapters |
| **M10 — Store launch** | Store listings, privacy policy, support page, pricing, analytics-free crash reporting (opt-in) |
| **M8.5 — Vehicle profile + tool registry** | VIN decode, capability probing, profile confirm/edit screen, tools load per car, lazy-loaded packs |
| **M11 — BMW Tools (beta, personal use)** | Service reset first, then backup-first coding; feature-flagged off in store builds until legal review |
| **Later** | Mode 06, make-specific Mode 22 PIDs, CarPlay/Android Auto, widgets, cloud backup (opt-in) |

---

## 14. Selling It: Commercial Plan

### 14.1 Honest market picture

OBD scanner apps are a crowded, mature category. Well-known existing apps include Car Scanner ELM OBD2, OBD Auto Doctor, Torque, OBD Fusion, OBDLink, and Carista and FIXD (which bundle their own adapters). Many are low-priced or free with upgrades. You will not win by matching features alone. You win by being **cleaner, more trustworthy, and better on iPhone**.

### 14.2 Differentiation ideas

1. **Truly native iPhone feel** — most apps in this category look dated.
2. **Quick Scan + plain-language health summary** instead of raw data walls.
3. **Shareable PDF reports** a driver can send to a mechanic or use when buying a used car ("pre-purchase check").
4. **Honest pricing** — one-time unlock, no confusing subscription traps (users in this space already distrust subscriptions).
5. **Adapter onboarding** that prevents the "my Bluetooth adapter doesn't work on iPhone" failure up front.
6. **Reliability** — tested against clone adapters; clear errors instead of silent hangs.
7. **Privacy** — offline-first, no account, no tracking.
8. **Ask AI handoff** — send your scan to the AI app you already use. No AI costs or servers on your side, and nothing leaves the phone unless the user chooses to share it.

### 14.3 Pricing options (decide later with beta data)

| Model | Pros | Cons |
|-------|------|------|
| Free + one-time "Pro" unlock | Low friction, matches user distrust of subscriptions | Lower lifetime revenue per user |
| Free + subscription | Recurring revenue | Backlash risk in this category |
| Paid upfront | Simple | Hurts discovery; users can't try with their adapter first |

A sensible split: **Free** = connect, live basics, read codes. **Pro** = custom dashboards, logging/replay, PDF reports, garage, advanced tools. Keep Clear Codes accessible in free, because paywalling it feels predatory.

### 14.4 Costs to expect

| Item | Cost |
|------|------|
| Apple Developer Program | $99 / year |
| Google Play registration | $25 one time |
| Store commissions | Typically 15–30% depending on program and revenue; check Apple's Small Business Program and Google's current tiers |
| Mac for iOS builds | You need access to one |
| Test adapters | A few good ones (BLE dual-mode, Wi-Fi, one Classic for Android) |
| Purchase tooling (optional) | RevenueCat or build directly on StoreKit/Play Billing; check current pricing |
| Support/website/privacy policy | Low, but required |

### 14.5 Legal and compliance checklist

- **Name:** Confirm that “iCAR” is available for the intended jurisdictions and app stores before launch; keep a backup name.
- **"ELM327":** it is a trademark of Elm Electronics. Use "ELM327-compatible adapters" descriptively and avoid implying endorsement.
- **Data licenses:** DTC database, PID tables, icons, fonts, and every npm dependency need licenses that allow commercial use.
- **Privacy:** publish a privacy policy; fill in Apple's privacy "nutrition label" and Google's Data safety form accurately (local-only data makes this simple).
- **Ask AI:** sharing is user-initiated through the OS share sheet. Show a preview of exactly what will be shared, exclude the VIN by default, never include location, and describe the feature in the privacy policy.
- **Safety disclaimers:** informational only; not a substitute for professional diagnosis; do not operate while driving; clearing codes has consequences. Put them in onboarding, reports, and store descriptions.
- **Apple review:** OBD apps exist on the store, so the category is fine, but expect scrutiny of Bluetooth/local-network usage strings, accurate adapter-compatibility messaging, and any performance-timer feature.
- **Liability:** get proper advice on terms of use and, if revenue grows, a business entity.
- Nothing here is legal advice; confirm with a professional before launch.

### 14.6 Launch checklist

- [ ] Beta with real users across cars and adapters
- [ ] Crash-free sessions at a level you're comfortable with
- [ ] Store screenshots in native iOS style, short demo video
- [ ] Adapter compatibility page on a simple website
- [ ] Support email, in-app "export debug log" button
- [ ] Privacy policy + terms live
- [ ] Pricing and restore-purchases tested in sandbox
- [ ] Accessibility pass (VoiceOver/TalkBack, Dynamic Type, contrast)

---

## 15. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Classic Bluetooth adapter on an iPhone | Onboarding explains compatibility; recommend BLE/Wi-Fi/MFi adapters |
| Bluetooth plugin goes unmaintained or breaks on a new RN version | Transport interface isolates it; pin versions; keep an alternative ready |
| Clone adapters behave inconsistently | Quirk profiles, retries, timeouts, debug log, test on many adapters |
| Slow polling feels laggy | Priority tiers, visible-only polling, adaptive timing, multi-PID requests, show Hz |
| Free iPhone signing expires weekly | Accept for personal use; paid account (or TestFlight) for beta/production |
| User clears codes and loses diagnostic info | Pre-clear snapshot, clear warning, verification |
| Saturated market | Focus on native UX, reports, trust, and pricing honesty |
| DTC/PID data licensing blocks commercial use | Verify licenses early; fall back to self-authored generic table |
| Safety/legal exposure | Disclaimers, no control functions, no coding/tuning in v1, professional legal review before launch |
| Driver distraction | Glanceable UI, disable heavy interactions while moving where feasible, safety messaging |
| AI gives a wrong or overconfident diagnosis | Prompt tells the AI to state uncertainty; in-app disclaimer; the app's own "see a professional" banners for safety-critical codes; sharing is always user-initiated |
| Scope creep | Ship M0–M8 for personal use first; commercial work only after it proves itself |
| Wrong tools shown for a car, or a risky tool run on the wrong profile | Confirm detected car with the user, gate each tool by profile and adapter, show the reason when a tool is unavailable, backup-first for anything that writes |
| BMW data files and coding data are proprietary | Keep BMW Tools out of store builds until legally cleared; users supply their own data files; never bundle BMW files |

---

## 16. Open Questions

1. **Do you have a Mac?** It is required for any iPhone build, including the free 7-day route.
2. **What adapter do you own** (name/model)? Classic, BLE, or Wi-Fi decides your iPhone testing path.
3. Which car(s) will you test on first (make/model/year)?
4. Do you want to buy a BLE or dual-mode adapter now for iPhone testing?
5. Pricing preference for later: one-time unlock, subscription, or free with a tip jar?
6. Name: validate “iCAR” availability before investing in store assets.
7. Should VIN decoding use an optional online lookup, or stay 100% offline in v1?
8. Ask AI: share sheet only, or also quick-link buttons for specific AI apps (ChatGPT, Gemini, Claude)? Quick-links depend on each app's current link support.
9. Which car makes should get tool packs first, beyond the generic tools?
10. For BMW Tools: which series (E, F or G) is your car, and which adapter do you own?

---

## 17. Reference Material

- SAE J1979 (OBD-II services and PIDs); public PID tables (Wikipedia OBD-II PIDs, CSS Electronics OBD2 PID table).
- ELM327 datasheet (Elm Electronics) for the full AT command set.
- AndrOBD (open source Android OBD app) for ELM327 handling patterns; respect its license.
- ELM327-emulator (open-source simulator) for testing without a car.
- Apple Human Interface Guidelines (tab bars, sheets, lists, haptics, typography).
- Expo docs: development builds, config plugins, prebuild.
- Apple and Google developer documentation for current fees, review rules, and privacy forms.

---

*End of document.*
