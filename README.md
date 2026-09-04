# Money Plant 🌱

Offline-first expense, income and task tracker. **No cloud database** — the
database *is* a `.xlsx` file per month, sitting in the app's own storage. Open
it in Excel, mail it to yourself, back it up. That's the whole sync story.

Built to feel like a fintech app, not a Material demo: OLED black + neon in
dark mode, soft glass in light mode, Space Grotesk throughout, and a procedural
mascot that gets visibly unhappy as your burn rate climbs.

---

## How it works

| Concern | Choice |
| --- | --- |
| Database | `Expenses_Sep_2026.xlsx` per month, `path_provider` app documents dir |
| CRUD | full — add from the home card, tap a row to edit, swipe to delete (with undo) |
| State | Riverpod 2 + `riverpod_generator` |
| Routing | `go_router`, shell route, fade + rise transitions |
| Charts | `fl_chart` — self-drawing curved area line, interactive doughnut |
| Statement | `pdf` + `printing` → a real bank-statement layout |
| Motion | `flutter_animate` for entrances/stagger, implicit widgets for state |
| Mascot | `CustomPainter` — no Rive/Lottie asset, no binary in the repo |
| Icons | `flutter_launcher_icons` — legacy + adaptive + Android 13 themed |
| APK | GitHub Actions, downloaded as an artifact |

### Sheet layout

Every workbook has one sheet, `Entries`:

| Date | Type | Amount | Category | Description |
| --- | --- | --- | --- | --- |
| `2026-09-04 18:22` | `Outgoing` | `450.0` | `Food` | `Biryani` |

`Type` is `Incoming`, `Outgoing` or `Task`. Task rows carry a zero amount and
are excluded from every total — the same sheet doubles as a to-do log.

A row's **position in the sheet is its primary key** — no extra Id column. That
works because every mutation re-reads the workbook afterwards, so a delete
shifting the rows below it can never leave a stale index in memory. Edit a row
by hand in Excel and the app picks it up on next read.

---

## Layout

```
lib/
├─ main.dart                       app entry, edge-to-edge system chrome
├─ app/
│  ├─ theme.dart                   palette, Space Grotesk, the Glass panel
│  ├─ router.dart                  go_router + custom page transitions
│  └─ shell.dart                   floating pill nav with a sliding capsule
├─ core/
│  └─ entry.dart                   Entry, EntryType, Summary, categories
├─ data/
│  ├─ excel_service.dart           create / read / append / export .xlsx
│  ├─ pdf_statement_service.dart   the premium PDF statement
│  └─ providers.dart               Riverpod graph (codegen)
└─ features/
   ├─ home/
   │  ├─ home_screen.dart          instant-add + mascot + totals + recent
   │  └─ widgets/
   │     ├─ mascot.dart            procedural 3D-ish mascot
   │     └─ quick_add_card.dart    the zero-navigation entry card
   ├─ analytics/analytics_screen.dart
   └─ history/history_screen.dart  month archive + XLSX/PDF export
```

`android/` is **not** committed — it is generated in CI (see below), because it
is Gradle boilerplate that drifts with every Flutter release.

---

## Getting an APK

Push to `main`. That's it.

`.github/workflows/android-build.yml` fetches Flutter, scaffolds `android/`,
generates the launcher icons and the Riverpod providers, runs the tests, builds
`flutter build apk --release`, and uploads it as the **`money-plant-apk`**
artifact on the run page. Download, install, done — nothing to build locally.

## Running it locally (optional)

```bash
flutter create --platforms=android --org com.moneyplant --project-name money_plant .
git checkout -- .                    # keep our files, keep the generated android/
flutter pub get
dart run flutter_launcher_icons
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Re-run `build_runner` whenever `lib/data/providers.dart` changes.

---

## Exports

* **Excel → Downloads.** Copies the month's workbook to
  `/storage/emulated/0/Download`. Android 11+ only allows that with
  *All files access*, so the app asks; if it's refused the file stays in app
  storage and the path is reported instead.
* **Statement → PDF.** Renders the month as a monochrome bank statement
  (masthead, summary card, striped table with colour-coded amounts, closing
  balance block) and opens the system share sheet — which works on every
  Android version without any permission at all.

---

## Known ceilings

* Writes rewrite the whole workbook per entry. Fine for personal volumes,
  wrong past a few thousand rows a month.
* Fonts come from `google_fonts` at runtime; the first launch on a device with
  no network falls back to the system font until it can cache them.
* Editing cannot move an entry to a different month from the UI (there is no
  date picker); the service handles it by delete-then-add if you ever add one.
