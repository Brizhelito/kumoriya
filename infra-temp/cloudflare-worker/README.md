# Temporary Cloudflare Worker (outside kumoriya-api)

This worker is intentionally outside the API repo/folder and is meant to be temporary.

## What it does

- Proxies `api.kumoriya.online/*` to `ORIGIN_BASE_URL` (Hugging Face Space URL)
- Preserves `CF-Connecting-IP` for Fiber
- Adds basic security headers at edge
- Runs cron every 12h to call `GET /health`

## Required Setup

1. In Cloudflare DNS, create proxied CNAME:
   - Name: `api`
   - Target: `<your-space-name>.hf.space`
2. In this folder, set origin URL:
   - Edit `wrangler.toml` -> `ORIGIN_BASE_URL`
3. Deploy Worker:
   - `npm create cloudflare@latest` (if Wrangler not installed)
   - `npx wrangler deploy`

## Notes

- Keep-alive endpoint should remain DB-free.
- Use Cloudflare Rate Limiting Rules for primary edge limits.
