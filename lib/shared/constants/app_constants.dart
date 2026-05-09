// KONSEP BAGIAN 2: Rancang Koordinat & Robustness Parameter
// Variabel krusial untuk Single Source of Truth

class AppConstants {
  // Bounding box wajah -> akan dikonfirmasi jika confidence > 0.7
  static const double faceConfidenceThreshold = 0.7;

  // Multi-face support -> proses antrean maksimal 5 wajah terdeteksi sekaligus
  static const int maxFacesDetected = 5;

  // Frame skip logic -> memproses inferensi tiap 2 frame untuk manajemen daya / hemat baterai
  static const int frameSkipRate = 2;

  // Animasi standard
  static const int animationDurationMs = 200;
}

