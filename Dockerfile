# n8n self-hosted image — Supabase (Postgres) as its own database.
#
# NOTE: this branch (general) tracks n8n 2.x. Requires a Render instance with
# >= 1 GB RAM — n8n 2.x exceeds the free-tier 512MB limit and crashes with
# "JavaScript heap out of memory" when the editor loads.
#
# The victoraro branch keeps n8n 1.x for the free-tier instance.
#
# Database: set via environment variables (render.yaml) to point n8n at a
# Supabase PostgreSQL instance, so workflows, credentials, and the owner
# login survive Render restarts (unlike the ephemeral SQLite filesystem).
# n8n auto-creates its required tables on first startup.

FROM n8nio/n8n:2.41.4

# Base runtime tuning (DB config lives in render.yaml / Render env vars).
ENV N8N_DIAGNOSTICS_ENABLED=false \
    GENERIC_TIMEZONE=UTC

# n8n "node" user owns /home/node (config/certs dir).
RUN mkdir -p /home/node/.n8n

EXPOSE 5678