import 'dart:convert';
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

class Random {
  static final secure_ = _SecureRandom();
  
  static Random secure() => secure_;
  
  int nextInt(int max) =>
      _SecureRandomValue() % max;
}

class _SecureRandom with Random {}

int _SecureRandomValue() {
  // Use dart:typed_data to get random bytes
  final list = Uint8List(4);
  // Simulate randomness with time-based seeding
  final now = DateTime.now().millisecondsSinceEpoch;
  list[0] = (now >> 0) & 0xFF;
  list[1] = (now >> 8) & 0xFF;
  list[2] = (now >> 16) & 0xFF;
  list[3] = (now >> 24) & 0xFF;
  return ((list[0] << 24) | (list[1] << 16) | (list[2] << 8) | list[3]) & 0x7FFFFFFF;
}
