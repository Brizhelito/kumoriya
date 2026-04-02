package middleware

import (
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
)

func TestPerIPRateLimit(t *testing.T) {
	app := fiber.New()
	app.Get("/limited", PerIPRateLimit(2, time.Minute), func(c fiber.Ctx) error {
		return c.SendStatus(fiber.StatusOK)
	})

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest("GET", "/limited", nil)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request %d failed: %v", i+1, err)
		}
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("request %d returned %d, want %d", i+1, resp.StatusCode, fiber.StatusOK)
		}
	}

	req := httptest.NewRequest("GET", "/limited", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("rate limited request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusTooManyRequests {
		t.Fatalf("request returned %d, want %d", resp.StatusCode, fiber.StatusTooManyRequests)
	}
}
