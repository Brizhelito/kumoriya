#!/usr/bin/env python3
"""Generate Ed25519 64-byte private key (seed+pub) in hex for JWT_PRIVATE_KEY_HEX.

Go's ed25519.PrivateKeySize is 64 bytes: 32-byte seed || 32-byte public key.
"""

try:
    from cryptography.hazmat.primitives.asymmetric import ed25519
    from cryptography.hazmat.primitives import serialization

    private_key = ed25519.Ed25519PrivateKey.generate()

    # 32-byte seed
    seed = private_key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption()
    )

    # 32-byte public key
    pub = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )

    # Go expects seed || pub = 64 bytes
    full_key = seed + pub
    print(full_key.hex())
except ImportError:
    # Fallback using PyNaCl or raw Ed25519 from hashlib
    import hashlib, os
    seed = os.urandom(32)
    # Ed25519 public key derivation via SHA-512 clamping
    h = hashlib.sha512(seed).digest()
    # We can't correctly derive the public point without a real library.
    # Install cryptography: pip install cryptography
    raise SystemExit("Install 'cryptography' package: pip install cryptography")
