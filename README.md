# Vault Notes v2 — Firebase edition

Full rebuild after the project audit. Local encrypted SQLite is replaced by **Cloud Firestore** with **Google sign-in**, which works on the platforms you're actually running (web, Windows via web, Android, iOS) and gives you sync + backup for free.

---

## 1. Audit findings — why the app showed a blank screen

| # | Finding | Severity |
|---|---------|----------|
| 1 | `main()` awaited `VaultDatabase.open()` **before** `runApp()`. Any failure meant no frame was ever drawn → blank white screen with zero feedback. | Critical (root cause) |
| 2 | `sqflite_sqlcipher` has **no web or Windows implementation** (Android/iOS/macOS only). On `flutter run -d chrome` / `-d windows`, `open()` throws — the uncaught async error visible in your terminal (`dart-sdk/lib/_internal/js_dev_runtime/...`). | Critical |
| 3 | `local_auth` has no web support; `flutter_secure_storage` behaves differently on web (no real keystore). More failures waiting on non-mobile platforms. | High |
| 4 | No error boundaries anywhere — every failure path was invisible. | High |
| 5 | Nested folder confusion (`vault_notes/vault_notes`) meant commands sometimes ran from the wrong root (your Claude Code session already caught this one). | Medium |
| 6 | No Firebase layer existed at all: no `firebase_options.dart`, no services, no rules — expected, since v1 was local-only. | N/A (by design in v1) |

**How v2 fixes it:** `runApp()` is called immediately; Firebase initializes *inside* the widget tree through a `FutureProvider`, so startup has three visible states — spinner, readable error screen with retry, or the app. The storage layer is Firestore, which runs everywhere Flutter does. It is now structurally impossible for this app to render nothing.

---

## 2. Setup (do these in order)

### a) Create the local project shell
```bash
flutter create vault_notes --org com.vrutsa --platforms android,ios,web
# copy this package's lib/, pubspec.yaml, firestore.rules,
# firestore.indexes.json, firebase.json into it (overwrite lib/ and pubspec.yaml)
cd vault_notes
flutter pub get
```

### b) Connect Firebase (generates the platform files for you)
```bash
npm install -g firebase-tools          # if not installed
firebase login

dart pub global activate flutterfire_cli
flutterfire configure
```
Pick/create your Firebase project and select android, ios, web. This **overwrites `lib/firebase_options.dart` with your real keys** and creates `android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist` automatically. These files contain project-specific secrets generated from your account — that's why they ship here only as placeholders.

### c) Enable Google sign-in
Firebase Console → **Authentication → Sign-in method → Google → Enable** (set the support email).

### d) Create Firestore + deploy rules & indexes
Firebase Console → **Firestore Database → Create database** (production mode), then from the project root:
```bash
firebase deploy --only firestore
```
(This pushes `firestore.rules` and `firestore.indexes.json`.)

### e) Run
```bash
flutter run -d chrome        # recommended for development
flutter run -d <android-device>
```

---

## 3. Platform support (honest version)

| Platform | Status |
|---|---|
| **Web (Chrome/Edge)** | ✅ Fully supported — Google popup sign-in |
| **Android / iOS** | ✅ Fully supported — `signInWithProvider` browser flow, no google_sign_in plugin needed |
| **Windows desktop** | ⚠️ `firebase_auth`/`cloud_firestore` Windows support is still beta and Google OAuth is limited there. **Run `flutter run -d chrome` on your Windows machine instead** — same OS, no plugin gaps. Installable as a PWA if you want an "app" feel. |

---

## 4. Architecture

```
lib/
  main.dart                    # runApp first; init + auth gates with visible states
  firebase_options.dart        # PLACEHOLDER — replaced by `flutterfire configure`
  providers.dart               # Riverpod: auth stream, notes stream, filters, actions, theme
  models/note.dart             # NoteType, templates, Note (Firestore-native maps)
  services/auth_service.dart   # Google sign-in (web popup / mobile provider flow)
  services/note_repository.dart# ONLY class touching Firestore
  utils/password_generator.dart
  screens/sign_in.dart
  screens/home.dart            # search, chips, staggered grid, realtime stream states
  screens/editor.dart          # per-type fields, secrets, checklist, custom rows, generator
  screens/trash.dart           # archive + trash, restore, delete forever, empty trash
firestore.rules                # per-user isolation
firestore.indexes.json         # composite index: deleted ASC + updatedAt ASC (trash purge query)
firebase.json                  # rules/indexes deploy config
```

Data model: `users/{uid}/notes/{noteId}` — fields, tags, checklist items and custom rows are stored as native Firestore maps/lists (no JSON strings).

## 5. CRUD verification map (task 8)

- **Create / Update** — `NoteActions.upsert` → `repo.upsert` (`set()` full overwrite), realtime UI update via snapshot stream
- **Read** — `notesStreamProvider` (`snapshots()`), newest-first, offline cache included by Firestore for free
- **Delete (soft)** — `moveToTrash` sets `deleted: true`
- **Restore** — `restore` clears the flag
- **Delete permanently** — `deleteForever`, plus `emptyTrash` (batched)
- **Auto-purge** — `purgeOldTrash` on home load removes trash >30 days old (uses the composite index)
- **Search** — in-memory across title/content/tags/every field (right call at personal scale; no index cost)
- **Password generation** — `Random.secure()`, per-class guarantees, length 8–40

## 6. Notes & next steps

- Passwords are stored as regular Firestore data protected by auth + rules (Google-Keep trust level). If you want real end-to-end encryption later, encrypt the `fields` map client-side with WebCrypto/cryptography-package AES-GCM before writing — the repository layer is the single choke point where that slots in.
- Firestore free tier (Spark) is more than enough for personal use.
