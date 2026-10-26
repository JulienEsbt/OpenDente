# Language and appearance

OpenDente 0.8.0 provides French and English UI, an offline guide in both languages, localized notifications and adaptive light/dark colors.

## Choosing a language

Open **Settings → General → Interface language**. Choose **Automatic (Mac language)**, **Français**, or **English**. Automatic uses French for a French primary system language and English otherwise. The choice persists, takes effect immediately and is independent of charge settings. It does not restart the helper or issue a charging command. Native macOS authorization dialogs remain managed by the system.

## Maintaining translations

- UI strings live in `OpenDente/Resources/fr.lproj/Localizable.strings` and `en.lproj/Localizable.strings`.
- The offline guide lives in each language’s `OpenDenteGuide.json`.
- Use `String(localized: "French source text", bundle: L10n.bundle)` for UI text, including dynamic strings and accessibility labels. Keep stable identifiers, preference keys and diagnostic fields unlocalized.
- Preserve typed format arguments in translations. For example, an interpolated integer becomes `%lld`; a string becomes `%@`. Positional arguments such as `%1$lld` allow word order to change. Literal percentages inside interpolated formats are escaped as `%%`.
- `SWIFT_EMIT_LOC_STRINGS` is enabled so Xcode can extract source strings. Keep both language tables complete when adding controls.
- `LocalizedRoot` refreshes presentation on language changes. `LanguageSettings` is separate from `AppSettings`, so switching language does not trigger the charging policy’s settings observer.

The implementation follows Apple’s native [localizable string interpolation](https://developer.apple.com/documentation/Swift/String/LocalizationValue) and [bundle-based localization](https://developer.apple.com/documentation/foundation/localizedstringresource).

## Maintaining appearance

The `BatteryAccent`, `BatteryAction`, `BatteryPositive`, `BatteryPower` and `BatteryWarning` asset colors have light and dark variants. `AppPalette` exposes their semantic roles. Light mode uses darker teal, blue and green; dark mode keeps brighter status accents. Primary buttons use a separate background color so white labels remain readable in both appearances.

Do not hardcode a bright status color as light-mode text. Use labels and symbols as well as color. Power-flow text stays in the primary foreground over a subtle tint, with fully visible arrows.

## Verification

`LanguageSettingsTests` checks language selection, persistence and unchanged battery preferences. `LocalizationAndAppearanceTests` checks localized resources, mixed interpolation types, matching catalog keys/arguments, the English guide and contrast in both appearances. `AppearanceRenderingTests` renders real SwiftUI components with inert test data and verifies rendering issues no charging command. Its optional `OPENDENTE_UI_CAPTURE_DIR` environment variable exports review images; these fixtures are not physical battery measurements or public product screenshots.

Run the native suite with Xcode’s `-testLanguage fr` and `-testLanguage en` options to check both languages. Hardware behavior is tracked separately in [VALIDATION.md](../VALIDATION.md); a presentation update does not establish fresh physical charge, sleep or shutdown evidence.
