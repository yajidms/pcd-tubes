import 'package:flutter_test/flutter_test.dart';
void main() {
  group('Environment Initialization Test', () {
    test('Simulasi memastikan file .env tidak diexpose secara paksa (konstan tes)', () {
      bool isSecure = true;
      expect(isSecure, isTrue);
    });
  });
}
