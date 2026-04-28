package handler

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/anilist/service"
)

// fakeGraphQLClient stands in for the real GraphQL client during health
// handler tests. It always returns a controlled error so the cache
// never fills — we only care about the handler's contract shape and
// the isReachable heuristic, not about live AniList traffic.
type fakeGraphQLClient struct{}

func (fakeGraphQLClient) Execute(_ context.Context, _ string, _ map[string]interface{}) (json.RawMessage, error) {
	return nil, errors.New("not used in health tests")
}

func newHealthTestApp() (*fiber.App, *service.HomeService) {
	svc := service.NewHomeService(fakeGraphQLClient{}, service.DefaultConfig())
	app := fiber.New()
	NewHealthHandler(svc).Register(app)
	return app, svc
}
