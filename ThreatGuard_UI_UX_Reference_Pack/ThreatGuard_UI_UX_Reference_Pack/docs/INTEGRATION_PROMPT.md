# ThreatGuard UI/UX Reference Pack — Integration Prompt

Use the files in this pack as a **visual and component reference** for the existing ThreatGuard Flutter application.

## Hard constraints
- This is a UI/UX-only improvement. Do not add, remove, or change detection logic, security decisions, threat classifications, data models, repositories, storage, permissions, networking, or business behavior.
- Do not replace real values with demo values from `ThreatGuardDashboardVisualReference`.
- Do not rewrite `main.dart`, change architecture, add packages, upgrade dependencies, or restructure folders unless I explicitly approve.
- Inspect the existing theme, navigation, motion helpers, accessibility settings, and screen implementations before editing.
- Integrate selectively into the existing codebase. Do not copy this reference screen over a production screen wholesale.
- Preserve all existing features and routes. Keep all user-facing text in English.
- Respect the existing Reduce animations setting and light/dark theme behavior.
- Keep the current threat-detection results and status-bar behavior accurate.

## Visual direction
Use a premium cybersecurity aesthetic: deep navy surfaces, cyan/teal highlights, restrained blue-violet gradients, subtle luminous edges, layered surfaces, consistent spacing, readable typography, meaningful status colors, polished icons, and smooth 160–420 ms transitions. Avoid excessive glow, clutter, tiny text, and animation that distracts from threat information.

## Assets and files
- `assets/images/cyber_navy_wave.jpg`, `cyber_teal_glow.jpg`, and `cyber_violet_glow.jpg` are background artwork.
- `assets/images/shield_emblem.svg` is a vector source reference. Do not use it through `Image.asset` unless the project already supports SVG; do not add a dependency solely for this asset.
- `docs/threatguard_visual_design_board.png` is a visual inspiration board, not an in-app background.
- `lib/ui_reference/` contains namespaced example tokens, widgets, motion, and a UI-only dashboard reference. Adapt only the useful patterns to the project's established conventions.

## Required workflow
1. Audit the current files and identify which existing screens/components already provide similar behavior.
2. Propose a small file-by-file integration plan before editing.
3. Make appearance-only changes in small, reviewable steps.
4. Add image assets to `pubspec.yaml` only if needed, preserving all existing declarations.
5. Run `flutter analyze` and the relevant existing tests.
6. Report exact files changed, actual command results, and any remaining visual limitations. Never claim tests passed unless the commands really passed.
