# 📱 Guide Pemakaian Aplikasi — Tim CAP

**Pendeteksi Wajah, Umur & Ekspresi Real-Time**

Tugas Besar Pengolahan Citra Digital — Tim CAP

---

## 📋 Prerequisites

Sebelum menjalankan aplikasi, pastikan sudah terinstal:

| Komponen | Versi Minimum | Keterangan |
|----------|---------------|------------|
| Flutter SDK | ^3.10.8 | Cek dengan `flutter --version` |
| Dart SDK | ^3.10.8 | Termasuk dalam Flutter SDK |
| Android SDK | API 21+ | Target: API 33 (Android 13) |
| Android Studio / VS Code | Latest | Dengan Flutter plugin |
| Device / Emulator | Android 5.0+ | **Disarankan: device fisik** (kamera) |

> ⚠️ **Penting**: Aplikasi ini memerlukan akses **kamera** untuk fitur deteksi wajah. Emulator Android **tidak mendukung** kamera real-time dengan baik. Gunakan device fisik untuk pengalaman terbaik.

---

## ⚙️ Setup Environment

### 1. Clone Repository

```bash
git clone https://github.com/oguri-cap/pcd-tubes.git
cd pcd-tubes
git checkout brain
```

### 2. Setup File `.env`

Copy file `.env.example` menjadi `.env`:

```bash
cp .env.example .env
```

Edit file `.env` dan isi konfigurasi MongoDB Atlas:

```env
# MongoDB Atlas Configuration
# Dapatkan connection string dari MongoDB Atlas Dashboard
# Organisasi: oguri-cap → Project: pcd
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster-url>/?retryWrites=true&w=majority&appName=<appName>

# Konfigurasi Database
MONGODB_DB_NAME=pcd_tubes_db
MONGODB_COLLECTION_LOGS=detection_logs
MONGODB_COLLECTION_JOURNAL=mood_journal

# Environment
APP_ENV=development
```

> 💡 **Tips**: Jika belum memiliki MongoDB Atlas, aplikasi tetap bisa berjalan **tanpa database** (mode offline). Fitur dashboard dan journal akan menampilkan data lokal saja.

### 3. Konfigurasi MongoDB Atlas

1. Masuk ke [MongoDB Atlas](https://cloud.mongodb.com)
2. Pilih organisasi **oguri-cap** → Project **pcd**
3. Buat cluster (jika belum ada) atau gunakan cluster yang sudah ada
4. Buat database user dengan username & password
5. Whitelist IP address (atau gunakan `0.0.0.0/0` untuk development)
6. Copy connection string ke file `.env`

---

## 🚀 Cara Running

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Jalankan Aplikasi

**Mode Debug** (disarankan untuk development):
```bash
flutter run
```

**Mode Release** (untuk demo/presentasi):
```bash
flutter run --release
```

**Pilih Device**:
```bash
# Lihat device yang tersedia
flutter devices

# Jalankan di device tertentu
flutter run -d <device_id>
```

### 3. Verifikasi

Setelah aplikasi terbuka, pastikan:
- ✅ Bottom navigation bar muncul (4 tab)
- ✅ Tab Detect bisa dibuka
- ✅ Kamera bisa diakses (izinkan permission)
- ✅ Deteksi wajah berfungsi (bounding box muncul)

---

## 🧭 Struktur Navigasi Aplikasi

Aplikasi memiliki **4 tab utama** yang bisa diakses via bottom navigation bar:

| Tab | Ikon | Fungsi |
|-----|------|--------|
| **Detect** | 📷 | Landing page + akses Live Detection & Challenge Mode |
| **Dashboard** | 📊 | Visualisasi statistik emosi & usia |
| **Journal** | 📖 | Catatan mood harian |
| **Challenge** | 🏆 | Gamifikasi ekspresi wajah |

---

## 📖 Cara Penggunaan Fitur

### 1. 📷 Live Detection (Tab Detect)

**Cara menggunakan:**
1. Buka tab **Detect**
2. Tekan tombol **"Mulai Deteksi"**
3. Izinkan akses kamera jika diminta
4. Arahkan kamera ke wajah

**Arti tampilan:**
- **Bounding Box**: kotak di sekitar wajah yang terdeteksi
  - 🟢 Hijau = Senang (Happy)
  - 🔴 Merah = Marah (Angry)
  - 🔵 Biru = Netral (Neutral)
  - 🟠 Oranye = Terkejut (Surprised)
  - 🟣 Ungu = Sedih (Sad)
  - 🟣 Deep Purple = Takut (Fearful)
  - 🟢 Teal = Jijik (Disgusted)
- **Chip Label**: menampilkan `[Usia]th [Ekspresi] [Confidence]%`
  - Contoh: `23th Senang 87%`
- **HUD Atas**: jumlah wajah terdeteksi
- **HUD Bawah**: info detail wajah utama (usia, ekspresi, confidence)

**Catatan:**
- Deteksi berjalan real-time dengan frame skip (1 dari 2 frame)
- Estimasi usia adalah heuristics (10-65 tahun)
- Confidence menunjukkan kepercayaan diri model terhadap ekspresi

### 2. 🏆 Challenge Mode

**Cara bermain:**
1. Buka tab **Detect** → tekan **"Challenge Mode"** atau langsung dari tab **Challenge**
2. Ikuti instruksi: tiru ekspresi yang ditampilkan
3. Pertahankan ekspresi selama **3 detik** (progress bar akan terisi)
4. Jika berhasil → skor bertambah, lanjut ke ronde berikutnya

**Scoring System:**
- Total **5 ronde** per permainan
- Setiap ronde berhasil = **+1 poin**
- Ekspresi yang diuji: Senang, Sedih, Marah, Terkejut, Jijik
- Threshold confidence: **≥65%**

**Tips:**
- Pastikan pencahayaan cukup
- Hadapkan wajah langsung ke kamera
- Ekspresi harus jelas dan konsisten selama 3 detik

### 3. 📊 Dashboard

**Cara membaca:**

- **Summary Cards** (atas):
  - **Total Sesi**: jumlah sesi deteksi yang tercatat
  - **Dominan**: ekspresi paling sering terdeteksi
  - **Rata-rata Usia**: estimasi usia rata-rata

- **Pie Chart**: distribusi persentase setiap ekspresi
  - Warna sesuai kode bounding box
  - Persentase ditampilkan di setiap slice

- **Line Chart** (Tren Emosi):
  - Sumbu X: sesi deteksi (S1, S2, ...)
  - Sumbu Y: jumlah deteksi per ekspresi
  - Garis berwarna per ekspresi
  - Butuh minimal 2 sesi untuk muncul

- **Histori Sesi**: 5 sesi terakhir dengan detail

**Refresh**: Tarik ke bawah (pull-to-refresh) atau tekan ikon refresh di kanan atas.

### 4. 📖 Mood Journal

**Cara menambah entri:**
1. Buka tab **Journal**
2. Tekan tombol **"+"** di kanan atas atau **FAB** di kanan bawah
3. Pilih mood (7 pilihan emoji)
4. Tulis catatan (opsional)
5. Tekan **"Simpan"**

**Fitur:**
- **Auto-suggest mood**: Jika baru melakukan deteksi, mood akan di-suggest otomatis berdasarkan ekspresi terakhir (ditandai badge **"AI"**)
- **Swipe-to-delete**: Geser entri ke kiri untuk menghapus
- **Pull-to-refresh**: Tarik ke bawah untuk refresh dari database

---

## 🔧 Troubleshooting

### Kamera Tidak Terbuka

| Masalah | Solusi |
|---------|--------|
| Permission denied | Buka Settings → Apps → Tim CAP → Permissions → izinkan Camera |
| Kamera hitam/freeze | Restart aplikasi, pastikan tidak ada app lain yang menggunakan kamera |
| Emulator | Gunakan device fisik — emulator tidak mendukung kamera real-time dengan baik |

### Koneksi MongoDB Gagal

| Masalah | Solusi |
|---------|--------|
| Connection timeout | Pastikan koneksi internet stabil |
| Authentication failed | Cek username & password di `.env` |
| IP not whitelisted | Tambahkan IP di MongoDB Atlas → Network Access |
| `.env` tidak ditemukan | Pastikan file `.env` ada di root proyek (bukan `.env.example`) |

> 💡 Aplikasi tetap bisa berjalan tanpa MongoDB — data hanya tersimpan lokal (hilang saat restart).

### Model/Deteksi Gagal

| Masalah | Solusi |
|---------|--------|
| Deteksi sangat lambat | Pastikan menggunakan mode `standard` (bukan `full`) |
| Wajah tidak terdeteksi | Pastikan pencahayaan cukup, jarak wajah 30-100cm dari kamera |
| Ekspresi selalu "Netral" | Coba dengan ekspresi yang lebih dramatis — heuristics butuh fitur jelas |
| App crash saat init | Coba `flutter clean` lalu `flutter pub get` dan jalankan ulang |

### Build/Compile Error

```bash
# Bersihkan cache
flutter clean

# Reinstall dependencies
flutter pub get

# Rebuild
flutter run
```

---

## 👥 Catatan Tim

Proyek ini dikembangkan oleh **Tim CAP** (3 anggota) dengan arsitektur modular berbasis branch:

| Branch | Anggota | Tanggung Jawab |
|--------|---------|----------------|
| `lens` | Rizky Satria Gunawan (241511089) | Frontend: camera stream, bounding box overlay, challenge mode UI |
| `insight` | Hanifidin Ibrahim (241511076) | Frontend: dashboard placeholder, journal placeholder, theming |
| `brain` | Yazid Alrasyid (241511093) | **Fullstack & Backend Core**: integrasi, ML pipeline, state management, data services, dashboard & journal implementasi |

### Arsitektur

```
lib/
├── core/                    # Backend core
│   ├── inference/           # ML pipeline (face detection + heuristics)
│   ├── models/              # Data models (DetectionSession, JournalEntry)
│   └── services/            # Services (Camera, MongoDB)
├── features/                # Feature modules
│   ├── detect/              # Live detection (camera + overlay)
│   ├── dashboard/           # Emotion dashboard (fl_chart)
│   ├── journal/             # Mood journal (CRUD)
│   └── challenge/           # Expression gamification
└── shared/                  # Shared utilities
    ├── constants/            # App-wide constants
    ├── theme/                # Dark theme config
    └── widgets/              # Reusable widgets
```

### Teknologi

- **Flutter** — Cross-platform framework
- **face_detection_tflite** — On-device face detection (BlazeFace/MediaPipe)
- **flutter_riverpod** — State management
- **mongo_dart** — MongoDB Atlas connector
- **fl_chart** — Chart visualization
- **camera** — Camera access

---

*Tim CAP — Tugas Besar Pengolahan Citra Digital*
