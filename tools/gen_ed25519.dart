import 'dart:math';
import 'dart:typed_data';

/// Generate a random Ed25519 private key and print it as hex.
void main() {
  // Ed25519 private keys are 32 bytes of random data
  final random = Random.secure();
  final keyBytes = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    keyBytes[i] = random.nextInt(256);
  }

  // Convert to hex string
  final hex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  print(hex);
}
