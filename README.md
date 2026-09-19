# SkillNest 📚

A premium personal learning library — Flutter app (Material 3).

Save articles, videos, PDFs and notes from anywhere, organize them into
collections, track what you actually finish, and see it all in analytics.

## Run

```bash
cd learning_vault
flutter pub get
flutter run            # pick your device/emulator when prompted
```

Tests & static analysis:

```bash
flutter analyze        # 0 issues
flutter test           # 5 tests pass
```

## Design system

| Token | Value |
|---|---|
| Spacing grid | 8px scale (4/8/16/24/32) — `app_theme.dart → Insets` |
| Card radius | 12px (`Radii.card`), sheets & dialogs 24px |
| Touch targets | ≥44px everywhere (`Touch.min`, padded tap targets) |
| Accent | Calm teal `#0F6E5F` (light) / `#86D3C1` (dark) |
| Typography | Default San Francisco/Roboto stack, tight letter-spacing on titles |
| Themes | Full light + dark via `ThemeMode` (System / Light / Dark in Settings) |

All colors come from a hand-tuned `ColorScheme` (M3) in `lib/app_theme.dart` —
no hard-coded colors in screens except the amber star (favorite).

## Navigation

Bottom bar: **Home · Search · (raised ＋) · Collections · Favorites** —
floating pill bar with a raised central Add button (`root_shell.dart`).
Stacked routes: Add, Inbox, Details, Viewer, Collection Detail, Analytics,
Settings, Trash.

## Screens → files (lib/screens/)

1. `splash.dart` — logo, name, tagline → auto-navigates to Onboarding
2. `onboarding.dart` — Discover / Save / Organize / Learn · Skip · Back · Next · Get Started
3. `home.dart` — avatar + greeting + notifications + search · Continue Learning (horizontal cards) · Progress ring → Analytics · Recent Saves · Inbox card · Quick Add · skeleton loading state
4. `add_resource.dart` — URL / Paste / File / Share tabs · collection picker (+ create) · tag chips · keyboard-aware Save bar · duplicate dialog (Open Existing / Save Anyway / Cancel) · “Saved to Inbox” snackbar with **Undo**
5. `inbox.dart` — search, filter sheet (Status/Type/Collection/Favorites), sort, select mode with bulk Move/Tag/Favorite/Delete, empty states
6. `collections.dart` — 2-column collection cards (emoji, count, progress) + detail screen with Add Resource, status chips (All/Unread/In progress/Completed), sort, rename/delete
7. `search.dart` — live search, recent-search chips + Clear History, full filter sheet (Type/Collection/Tag/Status/Favorite), results with favorite + overflow menu
8. `favorites.dart` — search, sort, unfavorite inline
9. `details.dart` — hero, favorite, ⋮ menu (Move/Tags/Copy URL/Share/Retry metadata/Delete) · Status segmented button · collection row · tags · auto-saved notes · Open CTA
10. `viewer.dart` — calm reading surface, reading-progress bar, favorite/share/download/⋮ · Mark as Completed · Reopen · offline error state
11. `analytics.dart` — time-range chips (7D…All) · collection filter · 8 KPI cards (each opens its related resources) · Activity / Saved-vs-Completed / Sources donut / Collections bars (all hand-painted, no packages) · Most opened / Never opened · Export (JSON/CSV) with loading + success/error
12. `settings.dart` — profile edit · Theme (System/Light/Dark) · notification prefs · Backup & Restore (Export/Import with confirm → loading → success/error) · storage meter · Trash entry · Account & Sync (marked “soon”) · **demo switches: Simulate offline & Simulate export failure** · About
13. `trash.dart` — search, select mode, Restore, Delete permanently, Empty Trash, 30-day retention labels, confirm dialogs

## Component library (lib/widgets/)

- `components.dart` — `LvThumb` (kind+accent thumbnail, skeleton while fetching),
  `ResourceTile` (open/favorite/more, long-press select), `ContinueCard`,
  `CollectionCard`, `StatusChip`, `SectionHeader`, `FilterBadgeIcon`,
  `EmptyState`, `OfflineBanner`, `SkeletonTile`, `LvSheet`/`LvSheetAction`
  (bottom sheets), `LvDialog` (confirm + prompt), `LvSnackbar`, plus shared
  flows: Move-to-collection, Tags editor, Delete-with-undo.
- `charts.dart` — `BarChart`, `GroupedBarChart`, `DonutChart` (CustomPainter).

## States covered

default · pressed (ripple) · selected (checkbox tiles, chips) · disabled
(save button when invalid) · loading (spinners, progress dialog) · skeleton
(Home + fetching metadata rows) · success (snackbars, completed) · error
(backup failure, export failure) · empty (every list) · offline (banner +
viewer error) · keyboard (Add screen save bar follows insets).

## Architecture

- `lib/models.dart` — `ResourceItem`, `CollectionModel`, `TrashEntry`,
  `SearchFilters`, enums.
- `lib/vault.dart` — single `ChangeNotifier` store (`Vault.I`) with seed data,
  queries (search/sort/analytics) and all mutations. Swap with a database
  later — screens only talk to this API.
- Screens never mutate models directly; they call `Vault` methods so every
  workflow (save → inbox → metadata, learn → completed → analytics,
  delete → trash → restore) stays consistent.
