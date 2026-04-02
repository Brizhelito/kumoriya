FROM golang:1.25-alpine AS builder
WORKDIR /app

COPY go.mod ./
COPY go.sum* ./
RUN go mod download 2>/dev/null || true

COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/server ./cmd/server

FROM alpine:3.20
RUN addgroup -S app && adduser -S app -G app
USER app
WORKDIR /home/app
COPY --from=builder /bin/server /usr/local/bin/server
EXPOSE 7860
ENTRYPOINT ["/usr/local/bin/server"]
