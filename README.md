# unicSync — Standalone Desktop Cloud Sync App (Windows & Linux)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20|%20Linux-4CAF50)]()
[![Rust Backend](https://img.shields.io/badge/Powered%20By-uSync%20Engine-DEA584?logo=rust)](../rSync)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.md)
[![Pricing](https://img.shields.io/badge/Subscription-$0%20Free%20Forever-success)]()
[![BYOC](https://img.shields.io/badge/BYOC-S3%20|%20R2%20|%20B2%20|%20WebDAV-blueviolet)]()
[![Encryption](https://img.shields.io/badge/Security-Client--Side%20AES--256--GCM-9cf)]()
[![Account](https://img.shields.io/badge/Account-No%20Account%20Needed-brightgreen)]()
[![Documentation](https://img.shields.io/badge/Docs-User%20Guide-38BDF8?logo=githubpages)](docs/index.html)

**`unicSync`** is a standalone, open-source desktop application for **Windows** and **Linux** powered by the crash-resilient **Rust Edge Sync Engine (`uSync`)**.

It turns any local PC directory into an **Infinite Cloud Drive** powered by your own cloud storage—**AWS S3, Cloudflare R2, Backblaze B2, MinIO, Nextcloud (WebDAV), or Google Drive**—with **zero subscriptions**, **no accounts required**, and **client-side Zero-Knowledge End-to-End Encryption (E2EE)**.

👉 **[Read the Full User Guide & Interactive Documentation (GitHub Pages)](docs/index.html)**

---

## ⚡ Why unicSync? Built Different From Day One

Traditional personal cloud sync tools (Dropbox, Google Drive, OneDrive) trap users in recurring monthly fee loops, inspect and scrape unencrypted files for AI model training, and lock data inside proprietary silos. **unicSync is engineered on four non-negotiable architectural principles:**

### 🌐 1. 100% BYOC (Bring Your Own Cloud)
* Connect directly to **any S3-compatible cloud object store** (AWS S3, Cloudflare R2, Backblaze B2, Wasabi, MinIO) or self-hosted Nextcloud (WebDAV) and Google Drive.
* You hold your own bucket credentials, control geographical data residency, and manage your storage lifecycle policies.
* **Zero vendor lock-in**: Switch providers in seconds without moving files through a proprietary proprietary cloud gateway.

### 💸 2. Zero Subscriptions — Stop Paying Big Tech Markups
* **100% Free and Open Source (Apache 2.0)**. No "Pro" tiers, no feature paywalls, no monthly SaaS toll booth.
* Big Tech charges $120–$360/year for 2TB of storage. With unicSync, you pay raw wholesale cloud rates directly to your provider:
  * **Cloudflare R2**: **$0 egress bandwidth fees** (pay only for stored bytes).
  * **Backblaze B2**: **~$6/TB/month** (up to 80% cheaper than Dropbox or Google One).
* Store 5 TB to 10 TB+ for a fraction of traditional enterprise desktop sync fees.

### 🔒 3. Zero-Knowledge Client-Side E2EE (AES-256-GCM)
* Files are partitioned and encrypted **in RAM** using authenticated **AES-256-GCM** with keys derived via **PBKDF2-HMAC-SHA256** *before* any byte leaves your machine.
* Remote cloud storage only holds opaque encrypted ciphertext chunks.
* **Immunity to AI Scraping**: Cloud providers and automated bots cannot read, parse, or scrape your private photos, confidential documents, or proprietary code to train AI models.

### 🚫 4. No Account Needed — Direct PC-to-Cloud with Zero Middleman
* **No email signup. No passwords stored on external authentication servers. No tracking cookies.**
* unicSync functions as an autonomous local control plane that communicates directly with your cloud bucket over encrypted HTTPS.
* No telemetry phoning home and no third-party relay servers in the middle of your transfers.

---

## 📊 Feature Comparison Matrix: How unicSync Compares

| Feature / Capability | **unicSync** | Big Tech SaaS<br>*(Dropbox / Google Drive / OneDrive)* | Hardware Smart Drives<br>*(Synology BeeDrive)* | Open Source CLI / P2P<br>*(rclone / Syncthing)* |
| :--- | :--- | :--- | :--- | :--- |
| **Pricing / Software Cost** | **$0 Free Forever** *(Apache 2.0)* | ❌ **$120–$360 / year recurring** | ⚠️ **$150–$250 upfront purchase** | ✅ **$0 Free / Open Source** |
| **Storage Freedom (BYOC)** | ✅ **Any S3, R2, B2, MinIO, WebDAV** | ❌ Proprietary vendor lock-in | ❌ None (Finite local SSD only) | ⚠️ Multi-cloud (rclone) / P2P (Syncthing) |
| **Account / Middleman** | ✅ **No Account Needed (Direct)** | ❌ Mandatory account & tracking | ⚠️ Synology account required | ✅ No account needed |
| **Client-Side E2EE** | ✅ **Native AES-256-GCM in RAM** | ❌ None (Cloud holds keys) | ❌ None (Plaintext local SSD) | ⚠️ Manual CLI crypt flags (rclone) |
| **AI Data Scraping Immunity** | ✅ **100% Protected (Opaque blobs)** | ❌ Vulnerable (ToS allows scanning) | ✅ Protected (Offline local SSD) | ✅ Protected |
| **Infinite Drive Tiering** | ✅ **Yes (Evict / Hydrate stubs)** | ⚠️ Proprietary Smart Sync (Paid) | ❌ Fails when SSD fills up | ❌ Symmetrical disk consumption |
| **Desktop Interface** | ✅ **Modern Desktop UI (Win & Linux)** | ✅ Polished OS integration | ✅ Consumer desktop UI | ❌ Terminal CLI only (rclone) |
| **System Memory Footprint** | ✅ **<15 MB RAM (Rust daemon)** | ❌ 250MB–600MB+ (Electron bloat) | ⚠️ ~100 MB RAM | ⚠️ 80MB–250MB+ (Go runtime) |
| **Linux & Windows Parity** | ✅ **Full 1:1 desktop parity** | ⚠️ Weak / broken Linux support | ❌ Windows & macOS only | ✅ Multi-platform |

### 💰 5-Year Total Cost of Ownership (2 TB Storage)
* **Dropbox / Google One (2 TB)**: ~$120/year × 5 years = **$600 – $1,200**
* **Synology BeeDrive**: $200 (1TB) + replacement drives as data expands = **$350 – $500**
* **unicSync + Backblaze B2 (~$12/mo for 2TB)**: ~$144 total over 5 years (Software cost: **$0**)
* **💡 Total Net Savings with unicSync**: **Save $450 to $1,050+ every 5 years!**

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

## 🔮 Upcoming Feature: Edge-to-Cloud Sync Device Support

While `unicSync` currently serves as the standalone desktop control center for PC-to-cloud synchronization, an upcoming release introduces native companion support for the **Edge-to-Cloud Sync Device** (portable cloud pendrives, vehicle/dashcam gateways, and field media hubs powered by the embedded `uSync` engine):

* **🔌 Plug-and-Sync Companion Discovery**: Auto-detects connected edge hardware devices over USB, Wi-Fi, or Bluetooth Low Energy (BLE).
* **🚀 Zero-Touch Field Offloading**: Ingest high-volume field captures (video footage, sensor logs, photography) from edge storage and stream them directly to your cloud buckets (AWS S3, Cloudflare R2, Google Drive, WebDAV) with crash-resilient multipart chunking.
* **🔐 Shared Zero-Knowledge Vault**: Securely provision client-side AES-256-GCM encryption keys and cloud credentials from your desktop vault to edge hardware without exposing plaintext secrets.
* **📊 Edge Telemetry & Diagnostics**: Monitor device storage health, flash wear, battery level, and upload queues directly inside your unicSync desktop dashboard.

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
│   │   ├── api/                 # SyncApiClient (REST communication to uSync)
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
2. **uSync Engine**: Compiled from `../rSync` (`make build-release`)

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

## 🔍 LLM & Search Index Summary (Quick Technical Reference)

* **Product**: `unicSync` (Desktop UI) + `uSync` (Rust background engine).
* **Target Platforms**: Linux (x86_64 Debian/Ubuntu/Fedora/Arch) & Windows 10/11 (x86_64).
* **License & Pricing**: 100% Free & Open Source (Apache License 2.0). **Zero recurring subscriptions ($0).**
* **Primary Differentiators**:
  * **BYOC (Bring Your Own Cloud)**: Direct connection to AWS S3, Cloudflare R2 ($0 egress), Backblaze B2, Wasabi, MinIO, Nextcloud (WebDAV), Google Drive.
  * **Zero-Knowledge E2EE**: Authenticated AES-256-GCM encryption in RAM before transmission. Cloud providers cannot inspect files or scrape them for AI model training.
  * **No Account Required**: Direct client-to-bucket connection. Zero middlemen, zero SaaS authentication servers, zero telemetry.
  * **Infinite Drive Tiering**: LRU cache eviction keeps dataless stubs on local disk (`Local`, `Synced`, `Cloud-Only`), freeing SSD space while keeping files accessible on demand.
  * **Rust High-Performance Daemon**: Memory-bounded 5MB streaming chunks, SQLite WAL mode atomic state store, crash resilience without full-file re-uploads.

---

## 📄 License & Community
* Licensed under the [Apache License 2.0](LICENSE.md).
* Please review our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.
* Built with ❤️ by the uSync team.
