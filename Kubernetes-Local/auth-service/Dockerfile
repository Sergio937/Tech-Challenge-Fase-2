# ------------------------
# 1) Build stage
# ------------------------
FROM golang:1.21 AS builder

WORKDIR /app

# Copia o projeto inteiro (incluindo go.mod quebrado)
COPY . .

# Limpa e ajusta dependências
RUN go mod tidy

# Compila o binário estaticamente
RUN CGO_ENABLED=0 GOOS=linux go build -o auth-service .

# ------------------------
# 2) Final minimal image
# ------------------------
FROM alpine:3.19

WORKDIR /app


# Instala curl e cria usuário restrito sem shell de login
RUN apk add --no-cache curl \
    && addgroup -S appgroup \
    && adduser -S -G appgroup -h /app -s /sbin/nologin appuser

# Troca para usuário restrito
USER appuser

COPY --from=builder /app/auth-service /app/auth-service

EXPOSE 8001

ENV PORT=8001

# ================
# HEALTHCHECK
# ================
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -fs http://127.0.0.1:8001/health || exit 1

CMD ["/app/auth-service"]
