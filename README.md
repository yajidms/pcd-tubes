# Tugas Besar Pengolahan Citra Digital (PCD) - Kelompok 7 (Tim CAP)

## Topik
**Pendeteksi Wajah, Umur & Ekspresi Real-Time**

## Anggota & Penugasan Tim
Proyek ini dikembangkan dengan arsitektur modular yang memisahkan tanggung jawab (Single Responsibility Principle). Pembagian tugas telah disesuaikan dengan pola pengembangan spesifik:

**1. Rizky Satria Gunawan (241511089)**
*   **Fokus:** Frontend (UI & Presentasi Kamera)
*   **Tugas:**
    *   Mengimplementasikan UI *Camera stream* menggunakan *Flutter Camera Plugin*.
    *   Menyambungkan output deteksi (data yang sudah jadi) ke *feedback visual* (menggambar bounding box kotak wajah) secara real-time.
    *   Membangun komponen tampilan untuk *Challenge Mode*.
*   **Direktori Utama:** `lib/features/detect/`, `lib/features/challenge/`

**2. Hanifidin Ibrahim (241511076)**
*   **Fokus:** Frontend (Dashboard, Journal & UI/UX Styling)
*   **Tugas:**
    *   Membangun layout antarmuka visual (UI) untuk halaman *Dashboard & Analytics*.
    *   Mengintegrasikan *data display* untuk visualisasi ke dalam *Recharts-style charts* (grafik garis emosi, pie chart usia).
    *   Membangun halaman UX untuk *Mood Journal*.
    *   Penerapan desain sistem sentral (tema warna, animasi UX) agar konsisten seluruh aplikasi.
*   **Direktori Utama:** `lib/features/dashboard/`, `lib/features/journal/`, `lib/shared/`

**3. Yazid Alrasyid (241511093)**
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

### 4. Flutter UI & Feedback Overlay Design
*   **Face Frame:** Bounding box dinamis berubah warna per ekspresi (hijau = happy, merah = angry, biru = neutral).
*   **Chip Label:** Muncul di atas kotak wajah, contoh: "Pria · 24th · 😊 Happy 92%".
*   **Animasi:** *Fade in/out smooth 200ms* agar tidak mengganggu UX.
*   **Dashboard & Analytics:** 
    *   *Emotion Timeline:* Grafik garis ekspresi dominan per menit (Recharts-style).
    *   *Age Distribution:* Donut chart estimasi rentang usia.
    *   *Heatmap Mood:* Calendar view — dominasi emosi per hari.
*   **Fitur Tambahan (Anti-Monoton):** 
    *   *Mood Journal:* User tulis catatan setelah sesi, dikaitkan dengan ekspresi terdeteksi.
    *   *Challenge Mode:* Kamera meminta user meniru ekspresi tertentu (Gamifikasi).
    *   *Multi-lang:* Label ekspresi tampil dalam Bahasa Indonesia / English.
    *   *Widget Home:* Mini mood status hari ini di layar utama.

### Kekuatan Proyek & Prinsip SOLID
*   *On-device inference* — privasi terjaga tidak butuh internet untuk kamera.
*   Multi-task dalam 1 kamera stream (wajah + usia + ekspresi simultan).
*   Menggunakan Prinsip SOLID (Single Responsibility, Open/Closed, Dependency Injection via Riverpod).
