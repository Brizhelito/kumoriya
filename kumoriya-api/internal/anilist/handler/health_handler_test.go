package handler

import (
	"encoding/json"
	"io"
	"net/http/httptest"
	"testing"
)

func TestHealth_IsReachable_EmptyCacheReportsTrue(t *testing.T) {
	if !isReachable(0, 0) {
		t.Errorf("empty cache must report reachable=true (no negative signal yet)")
	}
}

func TestHealth_IsReachable_FullOutageReportsFalse(t *testing.T) {
	if isReachable(10, 10) {
		t.Errorf("100%% outage must report reachable=false")
	}
	if isReachable(10, 6) {
		t.Errorf("60%% outage must report reachable=false")
	}
	if isReachable(10, 5) {
		t.Errorf("50%% outage must report reachable=false (strict-less guard)")
	}
}

func TestHealth_IsReachable_PartialOutageReportsTrue(t *testing.T) {
	if !isReachable(10, 4) {
		t.Errorf("40%% outage must still report reachable=true (other buckets fine)")
	}
	if !isReachable(10, 0) {
		t.Errorf("zero outage must report reachable=true")
	}
}

// Smoke test: the handler returns valid JSON with the documented shape
// when wired against a real (cold) HomeService. We don't drive the
// service into outage here — the unit tests above cover the heuristic
// — but we do verify the response body contract.
func TestHealth_Get_ReturnsContractShape(t *testing.T) {
	app, _ := newHealthTestApp()

	resp, err := app.Test(httptest.NewRequest("GET", "/v1/anilist/health", nil))
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("status=%d, want 200", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)

	var got HealthResponse
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("invalid JSON: %v\nbody=%s", err, body)
	}
	if got.CheckedAt == "" {
		t.Errorf("checked_at must be populated")
	}
	if got.Buckets == nil {
		t.Errorf("buckets must be populated (even when empty inside)")
	}
	// Cold cache → reachable=true is the documented contract.
	if !got.AnilistReachable {
		t.Errorf("cold cache must report anilist_reachable=true")
	}
}
