---
title: Go Fiber Microservice
sdk: docker
app_port: 7860
---

Go/Fiber microservice scaffold.

## Local Run

```bash
go mod tidy
go run ./cmd/server
```

## Health

`GET /health` — always available, does not need DB.
