# n8n self-hosted image — Supabase (Postgres) as its own database.
#
# IMPORTANT: pinned to n8n 1.x on purpose. n8n 2.x exceeds Render's free-tier
# 512MB RAM limit and crashes with "JavaScript heap out of memory" when the
# editor loads. n8n 1.x runs comfortably (~225MB) under the 512MB cap.
#
# Database: set via environment variables (render.yaml) to point n8n at a
# Supabase PostgreSQL instance, so workflows, credentials, and the owner
# login survive Render restarts (unlike the ephemeral SQLite filesystem).
# n8n auto-creates its required tables on first startup.

FROM n8nio/n8n:1.123.76

# Base runtime tuning (DB config lives in render.yaml / Render env vars).
ENV N8N_DIAGNOSTICS_ENABLED=false \
    GENERIC_TIMEZONE=UTC

# n8n "node" user owns /home/node (config/certs dir).
RUN mkdir -p /home/node/.n8n

EXPOSE 5678
