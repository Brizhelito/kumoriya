package notifications

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// Sender is the minimum surface the airing worker needs from Firebase.
// Defined locally so tests can inject fakes without pulling the FCM SDK.
type Sender interface {
	// SendToTopic fans out a message to all devices subscribed to the
	// topic. Returns the message ID assigned by FCM on success.
	SendToTopic(ctx context.Context, topic string, msg TopicMessage) (string, error)
}

// TopicMessage is the payload sent to an FCM topic.
//
// Fields are intentionally minimal: title + body for the visible
// notification, Data for deep-link routing on tap. Priority is always
// "high" for airing notifications (user-actionable, time-sensitive).
type TopicMessage struct {
	Title string
	Body  string
	// Data is attached as FCM data payload; values must be strings.
	Data map[string]string
}

// FCMSender wraps firebase.google.com/go/v4 messaging.
type FCMSender struct {
	msg *messaging.Client
}

// NewFCMSenderFromCredentialsFile builds an FCMSender from a service
// account JSON file on disk.
func NewFCMSenderFromCredentialsFile(ctx context.Context, path string) (*FCMSender, error) {
	opt := option.WithCredentialsFile(path)
	return newFCMSender(ctx, opt)
}

// NewFCMSenderFromCredentialsJSON builds an FCMSender from a service
// account JSON payload (used when the JSON is injected as an env var
// secret, as is the case in Hugging Face Spaces).
func NewFCMSenderFromCredentialsJSON(ctx context.Context, credsJSON []byte) (*FCMSender, error) {
	if !looksLikeServiceAccountJSON(credsJSON) {
		return nil, errors.New("fcm: FIREBASE_SERVICE_ACCOUNT_JSON does not look like a service account key")
	}
	opt := option.WithCredentialsJSON(credsJSON)
	return newFCMSender(ctx, opt)
}

func newFCMSender(ctx context.Context, opt option.ClientOption) (*FCMSender, error) {
	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		return nil, fmt.Errorf("fcm: init app: %w", err)
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("fcm: init messaging: %w", err)
	}
	return &FCMSender{msg: client}, nil
}

// SendToTopic dispatches a topic message with high priority + data payload.
func (s *FCMSender) SendToTopic(ctx context.Context, topic string, m TopicMessage) (string, error) {
	if s == nil || s.msg == nil {
		return "", errors.New("fcm: sender not initialised")
	}
	return s.msg.Send(ctx, &messaging.Message{
		Topic: topic,
		Notification: &messaging.Notification{
			Title: m.Title,
			Body:  m.Body,
		},
		Data: m.Data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ChannelID: "kumoriya_new_episodes",
			},
		},
	})
}

// LoadServiceAccountJSON resolves Firebase credentials from one of:
//   - FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON content, for HF Spaces)
//   - FIREBASE_SERVICE_ACCOUNT_FILE (path to JSON file, for local dev)
//
// Returns (nil, nil) if neither is set — callers treat that as "FCM
// disabled" rather than a fatal error.
func LoadServiceAccountJSON() (content []byte, sourcePath string, err error) {
	if raw := strings.TrimSpace(os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON")); raw != "" {
		return []byte(raw), "", nil
	}
	if path := strings.TrimSpace(os.Getenv("FIREBASE_SERVICE_ACCOUNT_FILE")); path != "" {
		raw, rerr := os.ReadFile(path)
		if rerr != nil {
			return nil, path, fmt.Errorf("fcm: read credentials file %q: %w", path, rerr)
		}
		return raw, path, nil
	}
	return nil, "", nil
}

func looksLikeServiceAccountJSON(b []byte) bool {
	var probe struct {
		Type        string `json:"type"`
		ProjectID   string `json:"project_id"`
		ClientEmail string `json:"client_email"`
		PrivateKey  string `json:"private_key"`
	}
	if err := json.Unmarshal(b, &probe); err != nil {
		return false
	}
	return probe.Type == "service_account" &&
		probe.ProjectID != "" &&
		probe.ClientEmail != "" &&
		probe.PrivateKey != ""
}
