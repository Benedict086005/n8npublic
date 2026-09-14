# Self-hosted n8n on Render (Supabase Postgres database)

Deploy the **official n8n Docker image** as a single Render Web Service that uses a
**Supabase (PostgreSQL) database** for its own storage — so workflows, credentials,
and the owner login **survive Render restarts** (unlike ephemeral SQLite).

- n8n serves its own web UI at the service root URL.
- n8n's own data (workflows, credentials, owner account) lives in Supabase Postgres.
- Tuned to fit Render's **free tier** (512 MB RAM).

## Why n8n 1.x and not 2.x?

I tested both versions under Render's free-tier 512 MB memory limit:

| Version | Result under 512 MB |
|---------|---------------------|
| n8n **2.x** (2.38.3) | ❌ **Out of memory.** The editor crashes with `JavaScript heap out of memory` (Exit 134) when the UI loads — it needs more than 512 MB. |
| n8n **1.x** (1.123.76) | ✅ **Works.** Boots ~175 MB, stable at ~225 MB under editor + webhook load. Verified end-to-end: editor UI loads, owner setup, and a webhook executed successfully. |

So this project is deliberately pinned to **n8n 1.x** to run reliably on the free tier.
If you move to a paid plan with more RAM (e.g. 1–2 GB), you can bump `Dockerfile`'s
`FROM n8nio/n8n:<version>` to a 2.x tag.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Official n8n 1.x image (memory-tuned); DB configured via env vars in `render.yaml`. |
| `render.yaml` | Render Blueprint: single `runtime: docker` web service, free plan, `/healthz` check, Supabase Postgres env vars, secrets. |
| `.env.example` | Template of every env var n8n needs — reference for setting them on Render. |
| `.dockerignore` | Keeps the build context small / avoids shipping junk. |

## One-click deploy

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=<YOUR_GITHUB_REPO>)

1. Push this repo (branch `victoraro`).
2. In Render Dashboard → **New → Blueprint**, select the repo + branch, or use the
   Blueprint URL. Render reads `render.yaml`.
3. After creation, set the `sync: false` secrets in the Environment tab:
   - `DB_POSTGRESDB_PASSWORD` — your Supabase database password
   - `N8N_EDITOR_BASE_URL` — `https://<your-service>.onrender.com`
   - `N8N_WEBHOOK_URL` — `https://<your-service>.onrender.com`
4. First visit to `https://<your-service>.onrender.com` → create the owner account.

## Manual deploy (alternative)

Point Render's "Web Service" at the repo with:
- **Runtime:** Docker
- **Dockerfile:** `./Dockerfile`
- **Health Check Path:** `/healthz`
- **Plan:** Free

Then set the environment variables from `.env.example` (see below).

## Setting env vars on Render

Copy the values from [`.env.example`](./.env.example) into your service's
**Environment** tab on Render, replacing the placeholders. The DB variables must point
at a **Supabase Transaction Pooler** (port `6543`) — see the table below.

## Environment variables

All defaults are already declared in `render.yaml` (or in `.env.example` for manual
deploys). The important ones:

| Variable | Value | Notes |
|----------|-------|-------|
| `PORT` / `N8N_PORT` | `5678` | public + internal listener |
| `DB_TYPE` | `postgresdb` | n8n stores its own data in Postgres |
| `DB_POSTGRESDB_HOST` | `aws-0-<region>.pooler.supabase.com` | **Transaction Pooler host** (IPv4) |
| `DB_POSTGRESDB_PORT` | `6543` | **pooler port** (`5432` only if using direct IPv4) |
| `DB_POSTGRESDB_DATABASE` | `postgres` | database name |
| `DB_POSTGRESDB_USER` | `postgres.<ref>` | pooler user (e.g. `postgres.rkjxpbbsspsaihofrdpe`) |
| `DB_POSTGRESDB_PASSWORD` | *(your password)* | `sync:false` — set on Render |
| `DB_POSTGRESDB_SCHEMA` | `public` | **must stay public** (custom schema = n8n bug) |
| `DB_POSTGRESDB_SSL_ENABLED` | `true` | Supabase requires SSL |
| `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED` | `false` | needed for managed/RDS certs |
| `N8N_EDITOR_BASE_URL` | set to `https://<service>.onrender.com` | `sync:false`, set after deploy |
| `N8N_WEBHOOK_URL` | set to `https://<service>.onrender.com` | for public webhook URLs |
| `NODE_OPTIONS` | `--dns-result-order=ipv4first` | **required** — avoids IPv6 `ENETUNREACH` to Supabase |
| `N8N_ENCRYPTION_KEY` | auto-generated | secrets must stay stable across runs |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | auto-generated | owner auth |
| `N8N_USER_MANAGEMENT_JWT_ENCRYPTION_KEY` | auto-generated | owner auth |

> ⚠️ If you change `N8N_ENCRYPTION_KEY` or the JWT secrets after the owner is set up,
> n8n may be unable to read existing encrypted credentials. Keep them stable.

## Free-tier caveats (important to know)

- **n8n data lives in Supabase, so it survives restarts** (workflows, credentials, owner login).
  Only the *container* is ephemeral; the Postgres data persists in Supabase.
- **Cold starts:** first request after idle takes 30–60 s (free tier spins down after ~15 min idle).
- Do **not** attach a persistent disk on the free plan — Render rejects it (you don't need one,
  since your DB is external on Supabase).

## Getting the Supabase pooler details

1. Open your Supabase project → **Connect** → **Transaction pooler**.
2. Copy the connection parameters:
   - **host:** `aws-0-<region>.pooler.supabase.com`
   - **port:** `6543`
   - **user:** `postgres.<your-project-ref>`
   - **password:** your Supabase database password
3. Use these for `DB_POSTGRESDB_PORT`, `DB_POSTGRESDB_HOST`, and `DB_POSTGRESDB_USER`.

> ⚠️ **Why the pooler and not direct?** Supabase direct connections resolve to IPv6,
> but Render's free tier has no IPv6 support → `connect ENETUNREACH` and a crash loop.
> The Transaction Pooler listens on IPv4, which Render can reach. Also set
> `NODE_OPTIONS=--dns-result-order=ipv4first` to force Node to prefer IPv4.

## Local testing

Copy `.env.example` to `.env`, fill in the pooler values, then run:

```bash
docker build -t n8n .
docker run --rm -p 5678:5678 \
  --env-file .env \
  -e N8N_EDITOR_BASE_URL=http://localhost:5678 \
  -e N8N_WEBHOOK_URL=http://localhost:5678 \
  n8n
# open http://localhost:5678
```

## Troubleshooting

- **`connect ENETUNREACH ... :5432` / crash loop to Supabase:** Supabase direct URLs can
  resolve to IPv6, which Render free tier can't reach. Switch to the **Transaction Pooler**
  (host `...pooler.supabase.com`, port `6543`) and set `NODE_OPTIONS=--dns-result-order=ipv4first`.
- **`duplicate key value violates unique constraint "pg_type_typname_nsp_index"` during
  migrations:** a migration was interrupted (SIGTERM). Usually transient — redeploy and n8n
  recovers and continues the migration chain on its own.
- **"Migrations in progress, please do NOT stop the process":** normal during startup; give
  the deploy time to finish rather than force-stopping it.
- **Container exits with "heap out of memory" / code 134:** you're running on n8n 2.x with
  < 1 GB RAM. Use the pinned 1.x image from this repo (or raise RAM on a paid plan).
- **"Connection terminated"/SSL errors to Supabase:** check `DB_POSTGRESDB_PASSWORD` is set on
  Render, `DB_POSTGRESDB_SSL_ENABLED=true`, and `DB_POSTGRESDB_HOST`/`PORT` match the Supabase
  **Connect → Transaction pooler** modal.
- **n8n can't read tables / sees duplicates in weird schemas:** ensure `DB_POSTGRESDB_SCHEMA`
  is exactly `public`.
- **Webhooks returning 404:** make sure `N8N_WEBHOOK_URL` is set to your public
  `https://<service>.onrender.com` and the workflow is active.
