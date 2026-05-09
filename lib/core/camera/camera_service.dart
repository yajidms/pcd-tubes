// KONSEP BAGIAN 3: Arsitektur & Robustness (Lifecycle Safety)
// 1. Lifecycle Safety: Kamera di-dispose otomatis saat app masuk state background / inactive.
// 2. Memory Guard: Membatasi frame buffer max 3. Frame lama langsung dibuang (drop).
// 3. Graceful Fallback: Jika model tflite gagal diload, aplikasi masuk ke mode "no-AI" aktif (hanya tampilkan kamera murni).
// 4. Camera Stream via Flutter Camera Plugin dengan lifecycle-aware controller.

class CameraService {
  // TODO: Setup CameraController dari package 'camera'
  // TODO: Tambahkan AppLifecycleListener atau WidgetsBindingObserver untuk auto-dispose kamera

  void initializeCamera() {
    // init
  }
}

