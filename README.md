<div align="center">

# OpenDente · Personal Edition

**Native battery care for the Mac you use every day.**

Charge limits, a resume threshold, temporary modes and clear feedback — in the menu bar.

[English](README.md) · [Français](README.fr.md)

![Platform: macOS](https://img.shields.io/badge/platform-macOS-24292f?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-299da4)
![Status: experimental](https://img.shields.io/badge/status-experimental-d49a43)

</div>

OpenDente Personal is a community fork of [killerk3emstar/OpenDente](https://github.com/killerk3emstar/OpenDente), developed by [JulienEsbt](https://github.com/JulienEsbt). It keeps the original SwiftUI app and adds French controls, everyday profiles, a temporary storage mode, MagSafe signals and an experimental native macOS backend for a Mac where the original SMC charging keys are unavailable.

<p align="center">
  <img src="docs/images/menu-bar.jpg" width="300" alt="OpenDente menu bar panel with an 80 percent limit, a resume threshold and temporary charge modes">
  &nbsp;
  <img src="docs/images/charging.jpg" width="460" alt="Native charge settings with an 80 percent ceiling, automatic return to the ceiling and resumption below 75 percent">
</p>
<p align="center"><sub>Real captures of the installed app. The interface is currently in French; this README is available in both languages.</sub></p>

> [!IMPORTANT]
> **Experimental software, tested on one hardware configuration.** The native backend uses private Apple interfaces and has been exercised on a MacBook Air M3 with macOS 27.2. It is not a universal compatibility claim or an instantaneous thermal cutoff. The current build is locally signed and is not notarized. Read [compatibility and limitations](#compatibility-and-limitations) before enabling charge control.

## What you can do

| Mode or control | Everyday behavior |
|---|---|
| **Charge limit** | Choose a daily ceiling. The native backend accepts 20–100%; values below Apple's public 80–100% range are experimental. |
| **Resume threshold** | Wait for a natural drop below the lower threshold, then charge back to the ceiling. The app does not force repeated discharge cycles. |
| **Return to the ceiling** | Opt in to bringing an already high battery level down to your ceiling while connected to power, then hold. |
| **Charge to 100% once** | Temporarily request a full charge without replacing your daily settings. Thermal pauses retain priority. |
| **Prepare for storage at 50%** | Use a separate temporary target: discharge toward 50% when above it, charge toward it when below. Shut down manually when ready. |
| **Additional thermal pause** | Request a pause above a chosen battery temperature. Resume after cooling by 2°C and at least five minutes without exceeding the threshold. |
| **MagSafe signals** | Choose fixed colors, slow blinking or alternation for charging, holding, discharge, thermal pause and one-off full charge. |
| **Quiet background operation** | Start at login without opening a window. Click the menu bar icon when needed; closing a window keeps the app running. |

Battery temperature, capacity, cycles, power, current and adapter information remain available, alongside a simple power-flow display, configurable notifications, a searchable offline guide and a local diagnostic export. Missing measurements stay missing.

## A closer look

<details>
<summary><strong>Thermal controls, MagSafe signals and the offline guide</strong></summary>

<p align="center">
  <img src="docs/images/thermal.jpg" width="420" alt="Additional thermal pause and background-operation settings">
  <img src="docs/images/magsafe.jpg" width="420" alt="Six customizable MagSafe signals and ten-second previews">
</p>
<p align="center">
  <img src="docs/images/guide.jpg" width="560" alt="Searchable offline guide showing the storage mode and everyday charge controls">
</p>

Captures are unmodified app-window screenshots. [Capture notes](docs/images/README.md) record their version and scope.

</details>

## Compatibility and limitations

| Area | Current scope |
|---|---|
| Build target | macOS 14 or later; Apple Silicon is the project focus. Intel execution has not been tested. |
| Hardware validation | MacBook Air M3, 16 GB, macOS 27.2; MagSafe charging. |
| Original SMC backend | Preserved for machines exposing compatible keys; this fork does not claim fresh validation across those models. |
| Native backend | Private PowerUI interfaces, detected at runtime. Unavailable controls remain unavailable. |
| USB-C Power Delivery | Designed to regulate the internal battery independently of the charging port; no physical USB-C test is claimed. |
| Distribution | Source build and local signing; no notarized public installer is supplied here. |

**The requested state and the measured state are different.** A native command can take about a minute to take effect. macOS may occasionally charge to 100% to maintain its state-of-charge estimate. A requested pause or a green LED does not prove that battery current has stopped.

While the Mac is asleep, macOS retains the last native charge target; the app does not continuously sample temperature or animate the LED. Controls resume after wake. Idle-sleep prevention is optional and does not block manual sleep or lid-close sleep.

Quitting asks the helper to restore the saved Apple settings and system LED behavior. For an 80% system fallback, quit OpenDente, set Apple's charge limit to 80% with Optimized Battery Charging enabled, then relaunch it. **Apple's setting and this native backend use the same mechanism, not two independent charge gates.** A sleep test is not a full-shutdown test.

The 40°C internal-temperature default is an app precaution, not a battery-sensor threshold prescribed by Apple. This is an additional, deferred pause; Apple's own hardware and system protections remain in place.

## Build and run

You need full **Xcode**, **XcodeGen**, and a signing identity with a certificate and private key for both the app and helper. A bare ad hoc signature is rejected by the helper. Use your own identity; no private key is included in this repository.

```sh
git clone https://github.com/JulienEsbt/OpenDente.git
cd OpenDente
git switch feature/personal-battery-care
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

bash scripts/build-local.sh "Apple Development: YOUR NAME (CERTIFICATE ID)" "TEAM_ID"
```

The command above selects this edition on `feature/personal-battery-care`. Once it has been merged, `main` can be used instead.

The script generates the Xcode project, runs the native tests, builds a signed Debug app and checks that app and helper use the same certificate. It does **not** launch the app or register its privileged service.

1. Copy `build/DerivedData/Build/Products/Debug/OpenDente.app` into **Applications**. Keep one installed copy.
2. Open it from Applications, then click its menu bar icon.
3. Review **Général** for the helper status and enable **Ouvrir à la connexion** for quiet login startup. macOS may require local approval for the signed service.
4. In **Charge**, review your limits and explicitly enable the native backend if it is offered. Use only one active battery-control app.

For a Release build, open the generated project in Xcode, select your signing team for both targets and build the Release configuration. [Detailed local build and signing notes](README-PERSONAL.md) cover the implementation and validation workflow.

## Validation you can inspect

**Version 0.6.2: 380 native XCTest cases passed on arm64.** The unchanged helper has 36 complementary recovery, lifecycle and watchdog scenarios recorded in the validation report. Universal Release compilation covers arm64 and x86_64; only arm64 execution is claimed.

Physical checks include stopping and resuming charging in a small test band, discharge toward a lower native target on MagSafe, restoration on quit, relaunch, sleep/wake and owner-confirmed MagSafe colors and patterns. Complete 80→75→80 cycles, deliberate overheating, physical USB-C charging and a full shutdown are not claimed as completed tests.

```sh
# Native tests: inert hardware boundaries, no helper registration
xcodegen generate
xcodebuild test -project OpenDente.xcodeproj -scheme OpenDente \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO

# Complementary helper scenarios and native helper type checking
python3 tests/helper/run_tests.py
```

Test counts are local validation results, not a CI badge or a claim of superiority over another app. [Full validation record](VALIDATION.md) · [Helper-test scope](tests/helper/README.md)

## How it is built

```text
SwiftUI menu bar app
  ├─ BatteryService: measurements from IOKit / IORegistry / SMC
  ├─ ChargingManager: daily policy, temporary intents and observed state
  └─ Certificate-authenticated XPC
       └─ Privileged helper
            ├─ Original SMC control, when available
            ├─ Experimental native PowerUI target
            └─ Recovery journal and watchdog
```

The app reads and presents measurements; the signed helper performs privileged operations. The helper checks the app identifier and matching signing certificate. Restrictive changes are journaled before writing, and failed restoration retains recovery state for another attempt.

There is no telemetry, analytics, account or update server added to the app. Diagnostic exports are local and optional; review identifiers and logs before posting a report publicly.

## AlDente, Apple and next steps

OpenDente already covers the everyday controls: ceiling, resume threshold, return to the ceiling, one-off full charge, thermal pause, MagSafe feedback and measurements. It does not have AlDente's scheduling, Shortcuts integration or validated multi-user workflow. The mechanisms and sleep behavior differ, so feature names alone do not establish parity.

The most useful follow-ups are **Shortcuts actions**, **optional scheduling**, and **broader hardware and session testing**. A forced monthly deep-discharge calibration is not included as routine battery maintenance. Apple's own native limit can occasionally request 100% for its gauge; that is a different mechanism.

[Feature comparison and priorities](docs/FEATURE-COMPARISON.md) · [Comparatif français](COMPARATIF.md) · [AlDente's published features](https://apphousekitchen.com/fr/aldente/fonctionnalites/)

For battery-care context: [Apple charge limits](https://support.apple.com/en-us/102338), [Apple lithium-ion cycles](https://www.apple.com/batteries/why-lithium-ion/) and [storage guidance](https://www.apple.com/batteries/maximizing-performance/). No particular lifespan gain is promised.

## Contributing and credits

Build and test a focused change, describe your Mac and macOS version, and distinguish observed hardware behavior from simulated tests. For compatibility issues, include the active backend and measured behavior; redact diagnostic identifiers before sharing. See the [specification](SPEC-PERSONAL.md), [user guide](GUIDE-UTILISATION.md) and [changelog](CHANGELOG-PERSONAL.md).

This remains a fork of **[killerk3emstar/OpenDente](https://github.com/killerk3emstar/OpenDente)**. Charge limiting, sailing mode, SMC controls, measurements, notifications and the original app architecture came from that project. Its history, license and credits are preserved; the [historical upstream README](docs/UPSTREAM-README.md) remains available.

Additional acknowledgements: [Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit), [SMCKit](https://github.com/beltex/SMCKit), [actuallymentor/battery](https://github.com/actuallymentor/battery), [batt](https://github.com/charlie0129/batt), and [Ampere / AZ Code Lab](https://github.com/az-code-lab/ampere) for the adapted native mechanism.

**GPL-3.0.** See [LICENSE](LICENSE) and [third-party notices](THIRD-PARTY-NOTICES.md), including the MIT attribution for the adapted Ampere code. This project is not affiliated with Apple or AppHouseKitchen.
