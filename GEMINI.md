# Antigravity AI Project Rules: unicSync (Standalone Desktop App)

## 1. Project Context & Vision
- **Project**: `unicSync` is a standalone, cross-platform desktop application for **Windows** and **Linux**, powered by the **Rust Edge Sync Engine (`rSync`)**.
- **Core Role**: Acts as the centralized desktop UI control hub for synchronizing local PC folders to any cloud storage (AWS S3, Cloudflare R2, Google Drive, WebDAV), storage tiering (Local, Synced, Cloud-Only), zero-knowledge encryption vaults, and live transfer monitoring.
- **Strict Boundary**: `unicSync` is exclusively for **standalone desktop synchronization on Windows and Linux**. Cloud edge pendrives / USB hardware companions are a separate concept and must **never** be mingled with `unicSync`.

---

## 2. Architectural Boundaries (Strictly Enforced)
- **Zero Business Logic Duplication**: The Flutter app is a pure presentation and orchestration layer. All chunking, hashing, encryption, SQLite WAL transactions, and cloud network streaming are handled by the native Rust `sync-agent` engine (`sync-agent` on Linux, `sync-agent.exe` on Windows).
- **Unified Engine Communication**:
  - The Flutter desktop app communicates with the local background `sync-agent` daemon via its high-performance local REST & WebSocket API on `http://127.0.0.1:8484` (or port specified in `engine.port`).
- **Clean Architecture Directory Structure**:
  - `lib/core/engine/`: Cross-platform desktop process lifecycle manager (`EngineManager`).
  - `lib/core/api/`: Network client (`SyncApiClient`).
  - `lib/features/dashboard/`: Real-time bandwidth, transfer stats, active chunk queue.
  - `lib/features/files/`: File browser with tiering badges (💾 Local, ✅ Synced, ☁️ CloudOnly), evict/hydrate actions.
  - `lib/features/profiles/`: Multi-cloud profile wizards (S3, GDrive, WebDAV, Mock).
  - `lib/features/security/`: PIN verification, lockout protection, and E2EE master passphrase vault.
  - `lib/features/settings/`: Watch directory switcher, deletion policies, engine process diagnostics.

---

## 3. Flutter & Dart Coding Standards
1. **Sound Null Safety & Strong Typing**:
   - Never use `dynamic` unless explicitly serializing unknown raw JSON.
   - Use immutable data models (`freezed` or standard immutable `@immutable` classes with `copyWith`).
2. **State Management**:
   - Use **Riverpod (v2.x)** as the primary reactive state management library.
   - Separate UI widgets from business logic providers (`StateNotifier` / `AsyncNotifier`).
3. **Desktop-First Design**:
   - Consistent desktop layout: Navigation rail, resizable data tables, shortcut keys, dark slate palette (`#0F172A`).
   - Identical UI look and feel and user flows across both Windows and Linux.
4. **Resilience & Polling Discipline**:
   - When polling the local `sync-agent` REST API for status updates, use adaptive intervals (1 sec while syncing, 5 sec when idle).

---

## 4. Development Commands & References
- Run `flutter pub get` to install dependencies.
- Run `flutter run -d linux` or `flutter run -d windows` for desktop testing.
- Run `flutter analyze` and `flutter test` before committing.
- Companion Rust backend repository: `../rSync`.
