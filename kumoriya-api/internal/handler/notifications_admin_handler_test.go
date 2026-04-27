package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/notifications"
)

type fakeSender struct {
	mu   sync.Mutex
	sent []sentArgs
	err  error
}

type sentArgs struct {
	topic string
	msg   notifications.TopicMessage
}

func (f *fakeSender) SendToTopic(_ context.Context, topic string, msg notifications.TopicMessage) (string, error) {
	if f.err != nil {
		return "", f.err
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sent = append(f.sent, sentArgs{topic: topic, msg: msg})
	return "msg-id-1", nil
}

func newApp(h *NotificationsAdminHandler) *fiber.App {
	app := fiber.New()
	app.Post("/internal/notifications/test", h.SendTest)
	return app
}

func doPost(t *testing.T, app *fiber.App, body string, authHeader string) (int, map[string]any) {
	t.Helper()
	req := httptest.NewRequest("POST", "/internal/notifications/test", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &out)
	}
	return resp.StatusCode, out
}

func TestNotificationsAdmin_SendTest_HappyPath(t *testing.T) {
	sender := &fakeSender{}
	h := NewNotificationsAdminHandler(sender, "secret")
	app := newApp(h)

	body := `{"topic":"media_42","title":"Hello","body":"World","data":{"k":"v"}}`
	status, out := doPost(t, app, body, "Bearer secret")
	if status != fiber.StatusOK {
		t.Fatalf("expected 200, got %d (%v)", status, out)
	}
	if out["topic"] != "media_42" || out["message_id"] != "msg-id-1" {
		t.Errorf("unexpected response: %+v", out)
	}
	if got := len(sender.sent); got != 1 {
		t.Fatalf("expected 1 send, got %d", got)
	}
	s := sender.sent[0]
	if s.topic != "media_42" || s.msg.Title != "Hello" || s.msg.Body != "World" || s.msg.Data["k"] != "v" {
		t.Errorf("unexpected send args: %+v", s)
	}
}

func TestNotificationsAdmin_SendTest_RejectsMissingAuth(t *testing.T) {
	h := NewNotificationsAdminHandler(&fakeSender{}, "secret")
	status, _ := doPost(t, newApp(h), `{"topic":"t","title":"a","body":"b"}`, "")
	if status != fiber.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", status)
	}
}

func TestNotificationsAdmin_SendTest_RejectsWrongToken(t *testing.T) {
	h := NewNotificationsAdminHandler(&fakeSender{}, "secret")
	status, _ := doPost(t, newApp(h), `{"topic":"t","title":"a","body":"b"}`, "Bearer wrong")
	if status != fiber.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", status)
	}
}

func TestNotificationsAdmin_SendTest_503WhenTokenMissing(t *testing.T) {
	h := NewNotificationsAdminHandler(&fakeSender{}, "")
	status, out := doPost(t, newApp(h), `{}`, "Bearer anything")
	if status != fiber.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d (%v)", status, out)
	}
}

func TestNotificationsAdmin_SendTest_503WhenSenderMissing(t *testing.T) {
	h := NewNotificationsAdminHandler(nil, "secret")
	status, out := doPost(t, newApp(h), `{}`, "Bearer secret")
	if status != fiber.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d (%v)", status, out)
	}
}

func TestNotificationsAdmin_SendTest_RejectsMissingFields(t *testing.T) {
	h := NewNotificationsAdminHandler(&fakeSender{}, "secret")
	cases := []string{
		`{}`,
		`{"topic":"t"}`,
		`{"topic":"t","title":"x"}`,
		`{"topic":" ","title":"x","body":"y"}`,
		`{"topic":"t","title":" ","body":"y"}`,
	}
	for _, body := range cases {
		status, out := doPost(t, newApp(h), body, "Bearer secret")
		if status != fiber.StatusBadRequest {
			t.Errorf("body %q: expected 400, got %d (%v)", body, status, out)
		}
	}
}

func TestNotificationsAdmin_SendTest_502OnFCMError(t *testing.T) {
	sender := &fakeSender{err: errors.New("fcm down")}
	h := NewNotificationsAdminHandler(sender, "secret")
	body := `{"topic":"media_1","title":"a","body":"b"}`
	status, out := doPost(t, newApp(h), body, "Bearer secret")
	if status != fiber.StatusBadGateway {
		t.Fatalf("expected 502, got %d (%v)", status, out)
	}
}

// Sanity: the bearer comparison must not be a simple substring match —
// "Bearersecret" without the space, "Bearer  secret" with extras, and
// case differences should all be rejected to avoid timing-attack
// surprises if the constant-time compare is bypassed in future edits.
func TestNotificationsAdmin_SendTest_BearerStrictness(t *testing.T) {
	h := NewNotificationsAdminHandler(&fakeSender{}, "secret")
	bad := []string{
		"Bearersecret",
		"bearer secret",
		"Token secret",
		strings.Repeat("Bearer secret", 1) + "extra",
	}
	for _, h2 := range bad {
		status, _ := doPost(t, newApp(NewNotificationsAdminHandler(&fakeSender{}, "secret")), `{"topic":"t","title":"a","body":"b"}`, h2)
		if status != fiber.StatusUnauthorized {
			t.Errorf("auth %q: expected 401, got %d", h2, status)
		}
	}
	_ = h
}
