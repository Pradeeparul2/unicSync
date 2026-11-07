# unicSync — Standalone Desktop Cloud Sync App (Windows & Linux)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20|%20Linux-4CAF50)]()
[![Rust Backend](https://img.shields.io/badge/Powered%20By-rSync%20Engine-DEA584?logo=rust)](../rSync)
[![Documentation](https://img.shields.io/badge/Docs-User%20Guide-38BDF8?logo=githubpages)](docs/index.html)

**`unicSync`** is a standalone, cross-platform desktop application for **Windows** and **Linux** powered by the **Rust Edge Sync Engine (`rSync`)**.

👉 **[Read the Full User Guide & Documentation (GitHub Pages)](docs/index.html)**

It provides an intuitive, high-performance visual dashboard that turns any local PC directory into an **Infinite Cloud Drive** powered by AWS S3, Google Drive, or WebDAV.

---

## 🌟 Key Features

* **⚡ Real-Time Transfer Dashboard**: Visual gauges for active bandwidth, 4-worker chunk parallelism, and real-time upload progress.
* **☁️ Infinite Storage Tiering (LRU Cache Manager)**:
  * Browse files marked with dynamic status badges:
    * 💾 **Local (Buffering)**: Newly written files waiting for cloud ingestion.
    * ✅ **Synced (Cached)**: Safely in cloud and cached locally for instant access.
    * ☁️ **Cloud Only (Dataless Stub)**: Safely in cloud; local payload evicted to free physical PC disk space.
  * Instant **"Free Up Space"** (`evict`) and **"Download to Device"** (`hydrate`) actions.
* **🌍 Multi-Cloud Profile Wizard**: Configure AWS S3, Cloudflare R2, MinIO, Nextcloud (WebDAV), and Google Drive without editing JSON files.
* **🔒 Zero-Knowledge Security Vault**: Manage client-side AES-256-GCM encryption passphrases and decrypt archives offline.
* **🔑 App PIN Lockout**: Secure the local dashboard with a 4-to-8 digit PIN with 5-attempt brute-force lockout.
* **🖥️ Desktop Window & Lifecycle Management**: Sits unobtrusively on Windows and Linux with background daemon persistence.

---

## 🏛️ System Architecture

`unicSync` acts as a pure visual control plane, communicating with the local Rust `sync-agent` backend over HTTP / WebSockets:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                  unicSync (Flutter Desktop UI Client)                      │
│                                                                            │
│   Dashboard Screen   │   File Tier Manager   │   Cloud Profiles Setup      │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │
                         REST API (`/api/status`, `/api/files`)
                         (http://127.0.0.1:8484)
                                      │
                                      ▼
                        [Localhost Desktop Daemon]
                        `sync-agent watch <TARGET_PATH>`
                        (sync-agent on Linux, sync-agent.exe on Windows)
```

---

## 📁 Project Directory Structure

```text
unicSync/
├── GEMINI.md                    # Architectural Rules & Desktop Focus
├── README.md                    # Project Documentation & Architecture
├── docs/                        # GitHub Pages User Guide & Static Site
├── pubspec.yaml                 # Flutter Dependencies & Assets
├── lib/
│   ├── main.dart                # App Entrypoint & Window Initialization
│   ├── core/                    # Core Infrastructure
│   │   ├── api/                 # SyncApiClient (REST communication to rSync)
│   │   ├── engine/              # EngineManager (Cross-platform process lifecycle)
│   │   ├── models/              # FileRecord, SyncStatus, CloudProfile models
│   │   └── theme/               # Dark Slate Design System (#0F172A)
│   └── features/                # Feature Modules
│       ├── dashboard/           # Real-time sync meters & active queue
│       ├── files/               # Infinite Drive file explorer with tiering badges
│       ├── profiles/            # Cloud backend configuration wizard
│       └── settings/            # PIN protection, deletion policy & diagnostics
```

---

## 🚀 Getting Started

### Prerequisites
1. **Flutter SDK** (v3.22+ recommended): [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **rSync Engine**: Compiled from `../rSync` (`make build-release`)

### Running the App
1. Clone / navigate to the repository:
   ```bash
   cd unicSync
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run on your desktop platform:
   ```bash
   # Linux
   flutter run -d linux

   # Windows
   flutter run -d windows
   ```

---

## 📄 License & Community
* Licensed under the [Apache License 2.0](LICENSE.md).
* Please review our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.
* Built with ❤️ by the rSync team.
