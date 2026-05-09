# Tugas Besar Pengolahan Citra Digital (PCD) - Kelompok 7 (Tim CAP)

## Topik
**Pendeteksi Wajah, Umur & Ekspresi Real-Time**

## Anggota & Penugasan Tim
Proyek ini dikembangkan dengan arsitektur modular yang memisahkan tanggung jawab (Single Responsibility Principle). Pembagian tugas telah disesuaikan dengan pola pengembangan spesifik:

**1. Rizky Satria Gunawan (241511089) - branch lens**
*   **Fokus:** Frontend (UI & Presentasi Kamera)
*   **Tugas:**
    *   Mengimplementasikan UI *Camera stream* menggunakan *Flutter Camera Plugin*.
    *   Menyambungkan output deteksi (data yang sudah jadi) ke *feedback visual* (menggambar bounding box kotak wajah) secara real-time.
    *   Membangun komponen tampilan untuk *Challenge Mode*.
*   **Direktori Utama:** `lib/features/detect/`, `lib/features/challenge/`

**2. Hanifidin Ibrahim (241511076) - branch insight**
*   **Fokus:** Frontend (Dashboard, Journal & UI/UX Styling)
*   **Tugas:**
    *   Membangun layout antarmuka visual (UI) untuk halaman *Dashboard & Analytics*.
    *   Mengintegrasikan *data display* untuk visualisasi ke dalam *Recharts-style charts* (grafik garis emosi, pie chart usia).
    *   Membangun halaman UX untuk *Mood Journal*.
    *   Penerapan desain sistem sentral (tema warna, animasi UX) agar konsisten seluruh aplikasi.
*   **Direktori Utama:** `lib/features/dashboard/`, `lib/features/journal/`, `lib/shared/`

**3. Yazid Alrasyid (241511093) - branch brain**
*   **Fokus:** Fullstack & Backend Core (Integrasi Menyeluruh)
*   **Tugas:**
    *   **Backend & ML Core:** Mengurus seluruh proses berat ML; memuat model TensorFlow Lite (MobileNetV3, CNN ekspresi), proses preprocessing MediaPipe Face Mesh, dan menjalankan algoritma analitik *on-device*.
    *   **State & Isolate:** Mengimplementasikan *Single Source of Truth* melalui arsitektur Riverpod/BLoC dan mengawinkan pengolahan ML menggunakan sistem Threading *Isolate* (agar layar tetap berjalan halus).
    *   **Data & Layanan:** Mengatur penyimpanan database (log analitik sesi dan jurnal pengguna) secara Cloud menggunakan **MongoDB Atlas** (via REST API / Driver), serta menyediakan endpoint service untuk Frontend.
    *   **Fullstack Lead:** Memastikan bahwa pasokan data mentah (API/State) dari layer Backend tereksekusi dengan sempurna di komponen Frontend milik anggota lainnya.
*   **Direktori Utama:** `lib/core/inference/`, `lib/core/services/`, `assets/models/`, serta State/Providers di semua fitur.

---

## Rangkuman Konsep Proyek

### 1. Ideation & Problem-Solution
*   **Problem Utama:** Banyak sistem antarmuka digital belum mampu membaca konteks emosi pengguna secara real-time. Aplikasi konvensional tidak bisa menyesuaikan konten berdasarkan ekspresi wajah atau usia.
*   **Studi Kasus:** Toko ritel, kios interaktif, sistem absensi pintar, mood journaling.
*   **Target Pengguna:** 
    *   **Pendidikan:** Monitor konsentrasi & emosi siswa.
    *   **Healthcare:** Mood tracking untuk kesehatan mental.
    *   **Kiosk publik:** Personalisasi konten berdasarkan usia.
*   **Target Sensorik:** Input kamera depan/belakang (real-time stream). Mendeteksi wajah, landmark, bounding box. Output: usia estimasi, label ekspresi, confidence score.

### 2. Deep Dive ML Pipeline (Langkah Deteksi)
*   **Face Detection:** MediaPipe Face Mesh (468 landmark titik wajah, berjalan on-device).
*   **Preprocessing:** Crop ROI, normalize, resize ke 224x224 px sebelum masuk model. Perspective Warp untuk standarisasi pose wajah frontal.
*   **Age Estimation:** MobileNetV3 *fine-tuned* pada dataset UTKFace (≥20K sample), output regresi 0-100.
*   **Expression Classification:** CNN ringan 7 kelas emosi pada dataset FER-2013 (happy, sad, angry, surprised, fearful, disgusted, neutral).
*   **Rancang Koordinat:** Bounding box wajah dengan *confidence threshold* 0.7. Multi-face support (antrean deteksi maks 5 wajah simultan).
*   **Runtime & Performa:** TensorFlow Lite (.tflite), latensi <30ms per *frame* pada *mid-range device*. Terdapat *frame skip logic* (proses tiap 2 frame untuk hemat baterai).

### 3. Arsitektur & Robustness (Single Source of Truth)
*   **State Management:** State global dikelola via Riverpod / BLoC, terpisah dari UI layer.
*   **Inference:** Model inference di *Isolate* terpisah agar tidak *block main thread*.
*   **Lifecycle Safety:** Kamera *di-dispose* otomatis saat app *background / inactive*. 
*   **Memory Guard:** *Frame buffer max 3*, lama frame dibuang.
*   **Graceful Fallback:** Jika model gagal load, masuk ke mode "no-AI" aktif.
*   **Data Privasi & Cloud Storage:** (Diubah sesuai preferensi tim ke) **MongoDB Atlas**. Setiap sesi deteksi akan dilog ringkasannya ke database cloud. Privasi dijamin: tidak ada gambar wajah yang disimpan, hanya metadata label & timestamp.

### 4. UI & Fitur
*   **Overlay Design:** Analitik di atas kotak wajah yang mulus dan interaktif.
*   **Dashboard Analitik:** Menyediakan kurva statistik aktivitas emosi dan data estimasi usia pengunjung.
*   **Mood Journal & Challenge:** Elemen interaktif agar aplikasi lebih *engaging* dan tidak monoton.

## Environment & Konfigurasi Security
Proyek ini menggunakan file environment variables untuk mengatur string koneksi ke layanan eksternal demi menghindari kebocoran kredensial (terlebih ke MongoDB Atlas).

**Cara Setup:**
1. Gandakan file `.env.example` lalu ubah namanya menjadi `.env`.
2. Buka file `.env` dan masukkan URI dari MongoDB Atlas milik tim (`MONGODB_URI`).
3. Konfigurasi nama database serta nama koleksi (collection) dapat dimodifikasi secara dinamis dari file `.env` tersebut.
4. *Penting:* Jangan pernah melakukan commit file `.env` yang merisi data koneksi *production* ke repository GitLab/GitHub tim.
