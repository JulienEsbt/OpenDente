# OpenDente Personal and AlDente

Reviewed on **26 October 2026**, including the [official AlDente 1.40 release notes](https://github.com/AppHouseKitchen/AlDente-Battery_Care_and_Monitoring/releases/tag/1.40), against [AppHouseKitchen's feature documentation](https://apphousekitchen.com/fr/aldente/fonctionnalites/). AlDente entries describe the vendor's published behavior, not a side-by-side hardware test. OpenDente entries describe the native backend on the tested M3 Mac; the original SMC backend has a different scope.

[English README](../README.md) · [Comparatif français](../COMPARATIF.md)

## Feature map

| Feature | OpenDente Personal 0.7.2, native backend | AlDente's published offer |
|---|---|---|
| Charge limit | Available; deferred native target, measured state shown separately | Free / Pro |
| Lower resume threshold / sailing mode | Available; natural drop, then a charge cycle up to the ceiling | Pro |
| Automatic discharge toward the ceiling | Available as an explicit persistent opt-in | Pro |
| Manual discharge | Temporary storage target at 50%, or opt-in return to the chosen ceiling; arbitrary SMC discharge is not claimed on this Mac | Free / Pro |
| One-off full charge | Available; thermal pause retains priority | Pro |
| Thermal protection | Additional deferred pause while awake; not an immediate hardware cutoff | Pro |
| MagSafe LED | Fixed colors, slow blinking, alternating colors and previews; system control during sleep | Pro; MagSafe 3 discharge blinking is also offered |
| Prevent sleep until the limit | Optional idle-sleep assertion; manual and lid-close sleep remain possible | Pro |
| On-demand wake control independent of charging | Not implemented; the existing option covers charging toward the ceiling | Pro, new in 1.40, with a timer and low-battery release |
| After macOS calibration | Return-to-ceiling already handles an elevated level while awake; no complete calibration workflow | Pro: return to ceiling or continue calibration, new choice in 1.40 |
| Dedicated stop-on-sleep option | Last native target remains with macOS; no continuous app thermal polling during sleep | Pro |
| Stop charging when the app quits | Restores the saved Apple policy; no separate indefinite app-owned stop setting | Pro |
| Live menu bar status | Available | Pro |
| Power flow | Simple power display; no animated Sankey visualization | Pro |
| Hardware battery percentage | Informational measurement when available; native regulation uses the macOS percentage | Pro; current documentation also uses macOS percentage for control |
| Fast user switching | Not validated; no multi-session arbitration guarantee | Free / Pro |
| Scheduling | Not implemented | Pro; chosen weekdays and next-run display in 1.40 |
| Apple Shortcuts | Not implemented | Pro |
| Guided calibration | Not implemented | Pro |

OpenDente also provides a dedicated temporary storage mode around 50%, an offline French guide and local diagnostic export. A feature count does not establish equivalent behavior, lower power use, better reliability or a longer battery lifespan.

## What would be useful next?

| Priority | Candidate | Why it could help | Scope before delivery |
|---|---|---|---|
| 1 | **Shortcuts actions** for ceiling, one-off full charge and storage | Reuse existing modes from a keyboard shortcut or another workflow | Keep opt-in and thermal priority; report rejected actions and unavailable controls |
| 2 | **Optional scheduling** for a one-off full charge | Useful before a planned day away from power | Define missed-task handling and sleep behavior; do not promise an exact departure-time percentage |
| 3 | **Broader compatibility and user-session tests** | Most important for adoption beyond the original machine | More Mac models and macOS versions, other USB-C supplies, shutdown and account switching; the M3/20 W USB-C test does not establish universal support |
| 4 | **Public distribution** with notarized releases | Easier installation for other users | Separate signing/notarization and release-validation work; no public installer is advertised yet |

Timed wake control could also help with long-running work, with a low-battery release. It is a convenience separate from battery care. Compressed diagnostics and last-full-charge information are lower-priority refinements.

These are proposals, not hidden switches or implemented capabilities. They are not required to use the current daily ceiling and temporary modes on the tested machine.

## Features that should not be copied automatically

**Routine deep-discharge calibration.** AlDente publishes its own calibration schedule. That is not an Apple recommendation for every Mac battery. [Apple explains cumulative charge cycles](https://www.apple.com/batteries/why-lithium-ion/) and does not require a full discharge before charging. Its [native charge-limit documentation](https://support.apple.com/en-us/102338) already describes occasional full charges for gauge accuracy. OpenDente does not impose monthly deep cycles or disable its extra thermal pause to perform one.

**An internal-temperature threshold inferred from room temperature.** The app's internal battery reading is distinct from [Apple's ambient operating range](https://support.apple.com/en-us/102336). The 40°C default is identified as an app precaution, not an Apple-prescribed sensor value.

**Continuous control while powered off or in true sleep.** The app cannot keep running when the Mac is off. The native target can remain in system management during sleep, while custom decisions resume after wake. [Validation scope](../VALIDATION.md) records what was actually observed.

## What came from the original OpenDente?

The original app already had charge limiting, sailing mode, thermal logic, SMC discharge, one-off full charge, MagSafe control, battery measurements, local diagnostics and notifications. This fork adds French presentation, profiles, native PowerUI control on the tested Mac, separated temporary modes, storage preparation, configurable native light patterns, recovery/authentication fixes, quiet startup and the diagnostic correction.

Sources: [upstream at the audited revision](https://github.com/killerk3emstar/OpenDente/tree/06c5a8199f5c0657374e667073b3aa6a75f50df8), [AlDente feature page](https://apphousekitchen.com/fr/aldente/fonctionnalites/) and the linked Apple documentation. AlDente support and availability depend on model and version. OpenDente is an independent GPL-3.0 fork, not an Apple or AppHouseKitchen product.
