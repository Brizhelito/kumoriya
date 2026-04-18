// Package notifications implements the airing-episode push pipeline.
//
// Pipeline:
//  1. Worker polls the AniList calendar cache every N minutes.
//  2. For each media that has a just-aired episode, it tries to claim the
//     "(media, episode)" slot in Redis via SETNX. First claimer wins.
//  3. On win, the worker dispatches a single FCM message to topic
//     `media_{anilist_id}`. Clients subscribed to that topic receive the
//     push even when the app is closed.
//
// Dedup is the *only* reason Redis is on the critical path: without it,
// a server restart in the same airing window would re-notify users.
package notifications

import (
	"context"
	"fmt"
	"time"
)

// Deduper prevents double-notification across restarts.
type Deduper interface {
	// Claim returns true if this call is the first to claim (mediaID, episode).
	// TTL controls how long the claim remains active — beyond TTL another
	// claim is allowed (long enough that late retries cannot double-notify,
	// short enough that re-notifying after N days becomes possible).
	Claim(ctx context.Context, mediaID int, episode int, ttl time.Duration) (bool, error)
}

// RedisSetNXClient is the Redis surface the Deduper uses. It matches
// *redis.Client so the real client satisfies it without adapters.
type RedisSetNXClient interface {
	SetNXWithTTL(ctx context.Context, key, value string, ttl time.Duration) (bool, error)
}

// RedisDeduper implements Deduper on top of Upstash Redis REST.
type RedisDeduper struct {
	rdb RedisSetNXClient
}

// NewRedisDeduper builds a RedisDeduper.
func NewRedisDeduper(rdb RedisSetNXClient) *RedisDeduper {
	return &RedisDeduper{rdb: rdb}
}

// Claim attempts to reserve (mediaID, episode) for notification.
func (d *RedisDeduper) Claim(ctx context.Context, mediaID, episode int, ttl time.Duration) (bool, error) {
	key := fmt.Sprintf("notif:sent:media:%d:ep:%d", mediaID, episode)
	now := fmt.Sprintf("%d", time.Now().Unix())
	return d.rdb.SetNXWithTTL(ctx, key, now, ttl)
}
