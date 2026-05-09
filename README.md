# Tugas Besar Pengolahan Citra Digital (PCD) - Kelompok 7 (Tim CAP)

## Topik
**Pendeteksi Wajah, Umur & Ekspresi Real-Time**

## Anggota & Penugasan Tim
Proyek ini dikembangkan dengan arsitektur modular yang memisahkan tanggung jawab (Single Responsibility Principle). Berikut adalah pembagian tugas untuk masing-masing anggota:

**1. Rizky Satria Gunawan**
*   **Fokus:** Machine Learning Pipeline & Core Integration
*   **Tugas:**
    *   Integrasi MediaPipe Face Mesh untuk deteksi 468 landmark wajah (on-device).
    *   Pengembangan pipeline ML: Preprocessing (crop ROI, normalize, resize ke 224x224 px) dan Perspective Warp.
    *   Integrasi model inference TFLite dengan sistem Isolate untuk deteksi usia (MobileNetV3) & klasifikasi ekspresi (CNN).
    *   Manajemen logika *bounding box* dan kapabilitas *multi-face* (maksimal 5 wajah).
*   **Direktori Utama:** `lib/core/inference/`, `assets/models/`

**2. Yazid Alrasyid**
*   **Fokus:** Arsitektur Sistem, State Management & Robustness
*   **Tugas:**
    *   Setup *Single Source of Truth* menggunakan Riverpod/BLoC (terpisah dari layer UI).
    *   Manajemen *Lifecycle Safety* kamera (otomatis *dispose* saat background) dan integrasi *Camera Service*.
    *   Optimasi *Memory guard* dan strategi *frame skip logic* untuk menghemat baterai.
    *   Data Persistence: Logika penyimpanan sesi deteksi dengan layanan SQLite lokal.
*   **Direktori Utama:** `lib/core/services/`, implementasi Riverpod pada fitur.

**3. Hanifidin Ibrahim**
*   **Fokus:** Flutter UI, UX Feedback & Fitur Tambahan (Anti-Monoton)
*   **Tugas:**
    *   Desain *Feedback Overlay* (Face Frame dinamis berubah warna, Chip Label pintar, dan animasi).
    *   Pengembangan *Dashboard & Analytics* (Grafik garis ekspresi, *Heatmap Mood*, *Age Distribution chart*).
    *   Pembuatan fitur *Mood Journal* dan *Challenge Mode* gamifikasi.
    *   Konsistensi *User Interface* sesuai prinsip UI/UX yang telah dirancang.
*   **Direktori Utama:** `lib/features/`, `lib/shared/`

---

## Rangkuman Konsep Proyek

### 1. Ideation & Problem-Solution
*   **Masalah Utama:** Banyak sistem antarmuka belum bisa adaptasi konten berdasarkan ekspresi wajah dan usia pengguna secara real-time.
*   **Solusi:** Aplikasi deteksi *on-device inference* untuk multi-tugas sekaligus (Wajah + Usia + Ekspresi).
*   **Keunggulan:** Privasi terjaga, tanpa internet, desain Flutter yang modular dan sesuai prinsip SOLID (Single Responsibility, Open/Closed, Dependency Injection via Riverpod).

### 2. Deep Dive ML Pipeline (Langkah Deteksi)
*   **Face Detection:** MediaPipe Face Mesh (468 landmark titik wajah).
*   **Age Estimation:** MobileNetV3 (output regresi usia 0-100).
*   **Expression Classification:** CNN ringan untuk 7 kelas ekspresi (happy, sad, angry, surprised, fearful, disgusted, neutral).
*   **Runtime:** TensorFlow Lite (.tflite), latensi di bawah 30ms pada device kelas menengah.

### 3. Arsitektur & Robustness
*   **State Management:** State global di *Isolate* terpisah agar UI tetap halus (*thread-safe*).
*   **Data Privasi:** Hanya log *timestamp* dan metadata analitik yang disimpan melalui SQLite lokal (tanpa menyimpan gambar wajah).

### 4. UI & Fitur
*   **Overlay Design:** Analitik di atas kotak wajah yang mulus dan interaktif.
*   **Dashboard Analitik:** Menyediakan kurva statistik aktivitas emosi dan data estimasi usia pengunjung.
*   **Mood Journal & Challenge:** Elemen interaktif agar aplikasi lebih *engaging* dan tidak monoton.
