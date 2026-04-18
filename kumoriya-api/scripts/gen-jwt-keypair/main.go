// Generates a fresh Ed25519 keypair for the kumoriya-api JWT signer.
//
// Output:
//   JWT_PRIVATE_KEY_HEX      (64-byte hex, goes into kumoriya-api)
//   PARTY_SESSION_PUBLIC_KEY_HEX (32-byte hex, goes into the Cloudflare Worker)
//
// Usage:
//   go run ./scripts/gen-jwt-keypair
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
)

func main() {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		fmt.Fprintf(os.Stderr, "generate keypair: %v\n", err)
		os.Exit(1)
	}

	privHex := hex.EncodeToString(priv) // 64 bytes = 128 hex chars
	pubHex := hex.EncodeToString(pub)   // 32 bytes = 64 hex chars

	// Sanity check: in Go's ed25519.PrivateKey, the last 32 bytes are the
	// public key. This keeps parity with shell-only tricks like
	// `echo -n $PRIV | tail -c 64`.
	if privHex[len(privHex)-64:] != pubHex {
		fmt.Fprintln(os.Stderr, "internal error: public key suffix mismatch")
		os.Exit(2)
	}

	fmt.Println("# Keep the private hex SECRET. Anyone with it can forge tokens.")
	fmt.Println("#")
	fmt.Println("# kumoriya-api (.env / HF Space secret):")
	fmt.Printf("JWT_PRIVATE_KEY_HEX=%s\n", privHex)
	fmt.Println()
	fmt.Println("# Cloudflare Worker (wrangler secret put PARTY_SESSION_PUBLIC_KEY_HEX):")
	fmt.Printf("PARTY_SESSION_PUBLIC_KEY_HEX=%s\n", pubHex)
}
