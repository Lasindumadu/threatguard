# ThreatGuard UI/UX Reference Pack

A self-contained visual reference pack for modernizing the appearance of an existing Flutter security app. It includes background artwork, design tokens, decorative animation, reusable glass panels/buttons, and a UI-only dashboard example.

## Included
- `assets/images/`: three original abstract cybersecurity backgrounds plus a shield SVG source.
- `docs/threatguard_visual_design_board.png`: generated visual reference board.
- `lib/ui_reference/theme/threatguard_ui_tokens.dart`: color, gradient, radius tokens.
- `lib/ui_reference/motion/threatguard_motion.dart`: reusable motion timings and fade/slide helper.
- `lib/ui_reference/widgets/`: glass panel, gradient button, pulsing shield.
- `lib/ui_reference/screens/threatguard_dashboard_visual_reference.dart`: decorative dashboard example; sample metrics are placeholders.
- `docs/INTEGRATION_PROMPT.md`: safe prompt for an AI coding agent to integrate the design into the existing project.

## How to use
1. Extract this ZIP.
2. Copy selected files into your ThreatGuard repository only after reviewing them.
3. Copy the `assets/images` files to your project's assets directory if you want to use the backgrounds.
4. If using the JPEGs, merge the asset path into your existing `pubspec.yaml` assets section; do not replace the entire file.
5. Open `docs/INTEGRATION_PROMPT.md` and give its contents to your coding AI along with this pack.
6. Ask the AI to audit existing files first and integrate patterns incrementally.

## Important
- This pack is a reference, not a replacement for your app.
- It does not implement security functionality or detection logic.
- The dashboard example contains illustrative placeholder numbers and text. Never show those as actual security results.
- The code uses modern Flutter APIs such as `Color.withValues`, so verify compatibility with the Flutter SDK in your project before integration.
- No additional Flutter packages are required for the provided Dart components. The SVG file is included as source/reference only and is not loaded by the example screen.
