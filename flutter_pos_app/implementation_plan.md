# Goal: Redesign Support Screen

We need to bring the **Support** screen in line with the rest of the app’s visual style (subscription, add customers, inventory screens). The redesign will:
- Apply the app’s primary gradient and glass‑morphism card backgrounds.
- Use the defined `AppColors` and `AppTypography` consistently.
- Add subtle shadows and rounded corners for a premium look.
- Refactor repetitive widget code into reusable components.
- Ensure accessibility (contrast, font sizes) and responsiveness across phone, tablet, and desktop.

## User Review Required
- Confirm the preferred gradient style for the header (solid primary gradient vs. a lighter accent gradient).
- Approve the new glass‑morphism card design (blur radius, opacity).
- Approve any additional UI elements (e.g., floating action button for quick ticket creation).

## Open Questions
- Should the **"Open Chat"** button use the accent gradient background instead of a solid fill?
- Do you want a persistent **"Create Ticket"** FAB in the bottom‑right corner on desktop?

## Proposed Changes
---
### Support Screen UI
- Update `_buildHeader` to use a `Container` with `AppColors.primaryGradient` background and a subtle `BackdropFilter` for glass effect.
- Replace existing card containers (`_buildKPICard`, `_buildCategoryCard`, `_buildTicketCard`) with a new `GlassCard` widget that applies:
  - `BoxDecoration` with semi‑transparent white, `borderRadius: 20`, `boxShadow: AppColors.shadowSubtle`.
  - `BackdropFilter` with `sigmaX: 12, sigmaY: 12`.
- Apply consistent padding/margins using derived values from `MediaQuery` for responsive layout.
- Update button styles in `_buildActionButton` to use gradient fills (`AppColors.primaryGradient` for primary actions, `AppColors.accentGradient` for secondary) and adjust text color accordingly.
- Ensure all text uses `AppTypography` variants already defined (e.g., `headlineMedium`, `titleMedium`).
- Add hover effects for desktop using `MouseRegion` and subtle elevation changes.

### New Files / Widgets
- `lib/core/widgets/glass_card.dart` – reusable glass‑morphism card widget.
- `lib/core/widgets/gradient_button.dart` – button that supports gradient backgrounds and hover state.

### Theme Adjustments
- No changes to `app_colors.dart` needed; we will use existing gradients and shadows.
- Verify `app_typography.dart` includes needed font weights; if missing, add `fontWeight: FontWeight.w600` for button labels.

### Verification Plan
- Run the app on emulator/device for phone, tablet, and desktop breakpoints to ensure layout adapts.
- Take screenshots of the redesigned Support screen for each breakpoint.
- Verify that all 60 tickets from the backend are displayed correctly (no UI clipping).
- Run Flutter integration tests for the Support screen to ensure no runtime errors.

---
**Implementation Steps**
1. Create `glass_card.dart` and `gradient_button.dart`.
2. Refactor `support_screen.dart` to use new widgets and gradient header.
3. Adjust imports and remove now‑unused color constants.
4. Update `pubspec.yaml` if additional assets (e.g., custom fonts) are required.
5. Run `flutter pub get` and test.

Please review the plan and provide feedback/approval before we proceed with implementation.
