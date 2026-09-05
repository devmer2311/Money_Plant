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
| State | Riverpod 2, providers written by hand — no `build_runner` step |
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
│  └─ providers.dart               Riverpod graph
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
generates the launcher icons, runs the tests, builds
`flutter build apk --release`, and uploads it as the **`money-plant-apk`**
artifact on the run page. Download, install, done — nothing to build locally.

Every run stamps the APK with the workflow run number as its `versionCode`,
so a newer build is never refused as a downgrade.

## Installing updates without losing the ledger

The ledgers live in the app's private folder. An **update** keeps them; an
**uninstall** deletes them. Android only accepts an update when the new APK
carries the same signature as the installed one — otherwise it demands an
uninstall first, and the workbooks go with it.

A generated `android/` has no release signing config, so Gradle signs release
builds with `~/.android/debug.keystore`, and a CI runner mints a fresh one
every run. Every APK therefore had a different signature. The fix is one
secret: a keystore of our own, dropped into that exact path before the build.

Create it once (any machine with a JDK — Android Studio ships one at
`<studio>/jbr/bin/keytool`). The alias and passwords are not a choice; they
are what Gradle's debug config looks for:

```bash
keytool -genkeypair -v -keystore money-plant.keystore         -storepass android -keypass android -alias androiddebugkey         -keyalg RSA -keysize 2048 -validity 10000         -dname "CN=Money Plant, O=Money Plant, C=IN"

base64 -w0 money-plant.keystore > keystore.b64      # macOS: base64 -i …
gh secret set ANDROID_KEYSTORE_B64 < keystore.b64   # or paste it in Settings
```

Keep `money-plant.keystore` somewhere safe and out of the repo — losing it
means the next APK cannot update the installed one either.

The build warns instead of failing when the secret is missing, so CI keeps
working; the APK simply will not install over an older one.

**The changeover costs one uninstall.** The build already on the phone was
signed with a runner's throwaway key, so the first APK signed with the real
keystore still has to replace it. Export the months you care about first
(Ledger → the `.xlsx` export writes to `Download/`), uninstall, install the
new APK, and every build after that lands as an update.

## Running it locally (optional)

```bash
flutter create --platforms=android --org com.moneyplant --project-name money_plant .
git checkout -- .                    # keep our files, keep the generated android/
flutter pub get
dart run flutter_launcher_icons
flutter run
```

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
