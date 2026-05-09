# Pendeteksi Wajah, Umur & Ekspresi Real-Time

**Tugas Besar Pengolahan Citra Digital (PCD)**
**Kelompok 7 - Tim: CAP**
**Anggota Tim:**
1. Rizky Satria Gunawan
2. Yazid Alrasyid
3. Hanifidin Ibrahim

---

## 1. Ideation & Problem-Solution
- **Problem utama:** Banyak sistem antarmuka digital belum mampu membaca konteks emosi pengguna secara real-time.
- **Target Pengguna:** Pendidikan (monitor konsentrasi), Healthcare (mood tracking), Kiosk publik (personalisasi).
- **Target Sensorik:** Kamera depan/belakang HP (real-time stream).
- **Output:** Usia estimasi, label ekspresi, confidence score.

## 2. Deep Dive ML Pipeline
- **Face Detection:** MediaPipe Face Mesh (468 landmark), on-device, pre-processing (crop ROI, normalize, resize 224x224).
- **Age Estimation:** MobileNetV3 fine-tuned (dataset UTKFace), regresi 0-100.
- **Expression Classification:** CNN ringan 7 kelas (FER-2013: happy, sad, angry, surprised, fearful, disgusted, neutral).
- **Runtime:** TensorFlow Lite (.tflite), inferensi <30ms per frame.
- **Rancang Koordinat:** Bounding box -> threshold 0.7, multi-face (max 5), frame skip logic.

## 3. Arsitektur & Robustness
- **Framework:** Flutter
- **Single Source of Truth:** State via Riverpod/BLoC.
- **Concurrency:** Model inference di Isolate terpisah agar tidak memblokir main thread.
- **Lifecycle Safety:** Kamera otomatis di-dispose saat di background, memory guard (max 3 frame buffer).
- **Data Persistence:** Log deteksi -> SQLite (lokal), privasi data terjamin (hanya metadata disave).

## 4. Flutter UI & Feedback Overlay
- **Face Frame:** Bounding box dinamis berubah warna per ekspresi.
- **Chip Label:** Animasi di atas head frame (contoh: "Pria ~24th - 😊 Happy 92%").
- **Dashboard & Analytics:** Emotion Timeline, Age Distribution, Heatmap Mood.
- **Fitur Tambahan:** Mood Journal, Challenge Mode (gamifikasi tiru ekspresi).

## Peta Struktur Folder
- `lib/core/` — model inference dan layanan kamera.
- `lib/features/` — module fitur: deteksi, dashboard, jurnal, challenge.
- `lib/shared/` — UI modular: widget overlay, tema desain, kostanta system/UI.
- `assets/models/` — tempat menyimpan file `.tflite` untuk model deteksi.

