# KrishiNetra UI Polish / Runtime Fix

This build fixes the scan-page Material/layout crash and refreshes the scan and government-schemes screens.

## Main changes
- Scan screen now has a clean responsive card layout.
- All scan controls are under an explicit Material surface.
- Nutrient fields switch from 2x2 to stacked layout on narrow screens.
- Photo upload preview is polished and responsive.
- Fertilizer history is kept optional and connected to the existing analysis flow.
- Government schemes use a responsive 1/2/3-column card grid.
- Scheme details expand/collapse smoothly instead of showing a long wall of text.
- Dashboard page changes use a short animated transition.
- Existing backend/AI/service calls are preserved.

## Run

```powershell
flutter clean
flutter pub get
flutter run -d chrome
```


## Runtime layout stability fix

The dashboard grid now uses a responsive Wrap with bounded card widths instead of stretching Rows through an unbounded scroll view. Scheme cards have a fixed height and no Expanded child. This prevents the Chrome runtime layout assertion that caused the main content area to disappear while the sidebar remained visible.
