//go:build integration

// Verifies the FCM sender constructs successfully against a real service
// account key, without sending any actual push.
//
// Run with:
//
//	FIREBASE_SERVICE_ACCOUNT_FILE=/path/to/admin.json \
//	  go test -tags=integration ./internal/notifications/... -count=1 -v
package notifications

import (
	"context"
	"os"
	"testing"
	"time"
)

func TestIntegration_FCMSender_ConstructsFromServiceAccount(t *testing.T) {
	path := os.Getenv("FIREBASE_SERVICE_ACCOUNT_FILE")
	if path == "" {
		t.Skip("FIREBASE_SERVICE_ACCOUNT_FILE not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	sender, err := NewFCMSenderFromCredentialsFile(ctx, path)
	if err != nil {
		t.Fatalf("NewFCMSenderFromCredentialsFile: %v", err)
	}
	if sender == nil || sender.msg == nil {
		t.Fatalf("sender not initialised")
	}
}
