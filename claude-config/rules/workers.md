---
paths:
  - "workers/**/*.js"
  - "workers/**/*.toml"
  - "wrangler.toml"
---

# Cloudflare Workers Rules

## Deployment model
If your workers are git-connected (Cloudflare Workers Builds), pushing the default branch auto-deploys - no
manual paste. Otherwise deploy with `wrangler deploy`.

- **Bindings** (KV, D1, R2, Durable Objects, queues) MUST be declared in `wrangler.toml` - wrangler wipes any
  dashboard-only bindings on deploy. Add the binding to `wrangler.toml` BEFORE you push/deploy.
- **Secrets** stay in the Cloudflare dashboard (or `wrangler secret put`) - wrangler never wipes secrets. Never
  commit them to a file.
- **Auth:** let `wrangler` resolve the account from your OAuth login (`wrangler login`). Don't hardcode an
  account id / `CLOUDFLARE_ACCOUNT_ID` unless you specifically need to.

## Live-consumer safety (HARD)
- A deploy restarts the worker (and any Durable Objects) - don't deploy while live clients are mid-session if a
  reconnect blip matters.
- Keep every deploy backward-compatible: a worker often serves a mix of client versions at once. Make changes
  additive / capability-gated; never assume the matching client already shipped.

## Your worker registry (optional)
Keep a table here of each worker, its Cloudflare name, and the bindings its `wrangler.toml` must include - so the
pre-push check is simply "does wrangler.toml include every binding this worker needs?"
