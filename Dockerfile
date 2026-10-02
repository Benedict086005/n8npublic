# n8n self-hosted image — Supabase (Postgres) as its own database.
#
# NOTE: this branch (general) is testing the first n8n 2.x (2.1.5).
# n8n 2.x needs >= 1 GB RAM — the free-tier 512 MB limit crashes with
# "JavaScript heap out of memory" when the editor loads. Bump the Render
# instance RAM before deploying this.
#
# To revert to the free-tier-safe 1.x line, pin a 1.123.x tag instead.
#
# Database: set via environment variables (render.yaml) to point n8n at a
# Supabase PostgreSQL instance, so workflows, credentials, and the owner
# login survive Render restarts (unlike the ephemeral SQLite filesystem).
# n8n auto-creates its required tables on first startup.

FROM n8nio/n8n:2.1.5

# Base runtime tuning (DB config lives in render.yaml / Render env vars).
ENV N8N_DIAGNOSTICS_ENABLED=false \
    GENERIC_TIMEZONE=UTC

# n8n "node" user owns /home/node (config/certs dir).
RUN mkdir -p /home/node/.n8n

EXPOSE 5678