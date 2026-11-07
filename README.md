# unicSync — Cross-Platform Flutter Companion for rSync

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20Windows%20|%20Linux%20|%20Android%20|%20iOS-4CAF50)]()
[![Rust Backend](https://img.shields.io/badge/Powered%20By-rSync%20Engine-DEA584?logo=rust)](../rSync)

**`unicSync`** is the official cross-platform Flutter companion application for the **Rust Edge Sync Engine (`rSync`)** and the **Autonomous USB-C Smart Drive**. 

It provides an intuitive, high-performance visual dashboard that turns ordinary thumb drives and local directories into an **Infinite Cloud Drive** powered by AWS S3, Google Drive, or WebDAV.

---

## 🌟 Key Features

* **⚡ Real-Time Transfer Dashboard**: Visual gauges for active bandwidth, 4-worker chunk parallelism, and real-time upload progress.
* **☁️ Infinite Storage Tiering (LRU Cache Manager)**:
  * Browse files marked with dynamic status badges:
    * 💾 **Local (Buffering)**: Newly written files waiting for cloud ingestion.
    * ✅ **Synced (Cached)**: Safely in cloud and cached locally for instant access.
    * ☁️ **Cloud Only (Dataless Stub)**: Safely in cloud; local payload evicted to free physical USB space.
  * Instant **"Free Up Space"** (`evict`) and **"Download to Device"** (`hydrate`) actions.
* **🌍 Multi-Cloud Profile Wizard**: Configure AWS S3, Cloudflare R2, MinIO, Nextcloud (WebDAV), and Google Drive without editing JSON files.
* **🔒 Zero-Knowledge Security Vault**: Manage client-side AES-256-GCM encryption passphrases and decrypt archives offline.
* **🔑 Device PIN Lockout**: Secure the embedded dashboard with a 4-to-8 digit PIN with 5-attempt brute-force lockout.
* **🔌 USB-C Smart Drive Auto-Discovery**: Automatically senses when the physical `rSync` Smart Drive is plugged into your phone or PC over USB-C.
* **🖥️ Desktop System Tray / Menu Bar**: Sits unobtrusively in macOS Menu Bar and Windows System Tray with animated sync badges.

---

## 🏛️ System Architecture

`unicSync` acts as a pure visual control plane, communicating seamlessly with the Rust `sync-agent` backend over HTTP / WebSockets:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       unicSync (Flutter UI Client)                         │
│                                                                            │
│   Dashboard Screen   │   File Tier Manager   │   Cloud Profiles Setup      │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │
                         REST API (`/api/v1`)
                                      │
         ┌────────────────────────────┴────────────────────────────┐
         │                                                         │
         ▼                                                         ▼
[Localhost Desktop Daemon]                        [Autonomous USB-C Smart Drive]
`sync-agent watch /Volumes/USB`                   `rSync` Embedded Linux (RV1103)
`http://127.0.0.1:8080`                           `http://192.168.7.2:8080` (over USB)
```

---

## 📁 Project Directory Structure

```text
unicSync/
├── GEMINI.md                    # AI Assistant Rules & Architectural Boundaries
├── README.md                    # Project Documentation & Architecture
├── pubspec.yaml                 # Flutter Dependencies & Assets
├── lib/
│   ├── main.dart                # App Entrypoint & Window/Tray Initialization
│   ├── core/                    # Core Infrastructure
│   │   ├── api/                 # SyncApiClient (REST communication to rSync)
│   │   ├── constants/           # Colors, Strings, Dimensions
│   │   ├── models/              # FileRecord, SyncStatus, CloudProfile models
│   │   └── theme/               # Dark & Light Design System
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
2. **rSync Engine**: Compiled from `../rSync` (`cargo build --release -p sync-agent`)

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
   # macOS
   flutter run -d macos

   # Linux
   flutter run -d linux

   # Windows
   flutter run -d windows
   ```
4. Run on connected mobile device:
   ```bash
   flutter run -d android
   # or
   flutter run -d ios
   ```

---

## 📄 License
Licensed under Apache 2.0. Built with ❤️ by the rSync team.
