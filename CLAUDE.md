# strfry / neofry (our fork)

This is **our fork of the upstream [strfry](https://github.com/hoytech/strfry) Nostr relay** (C++).
It does two jobs in the Brainstorm workspace:

1. ships the **unmodified upstream strfry** image (a plain relay), and
2. ships **`neofry`** — upstream strfry **plus our mods**, the one that feeds events into Brainstorm.

> Upstream strfry's own features (relay, `strfry router`, `strfry stream`, negentropy sync, write policies, LMDB) are documented in [`README.md`](README.md) (largely the upstream readme). **This file only documents what is OURS.** Don't re-document upstream here.

## Branches

| Branch| Role |
| - | - |
| **`neofry`** | **Default branch** (`origin/HEAD → origin/neofry`). Upstream `master` + our required mods. **Source of truth for this repo.** |
| `master` | Pristine mirror of upstream `hoytech/strfry@master`. Synced automatically (below). Do not put our mods here. |

Our entire delta is `git diff origin/master..neofry` (~20 files). See [Our mods](#our-mods) below.

## Sync workflow (keeping up with upstream)

[`.github/workflows/neofry-sync.yml`](.github/workflows/neofry-sync.yml) runs **weekly (Mon 13:00 UTC)** + on demand:

1. **`sync-upstream`** — fast-forwards `master` from `upstream/master` (`hoytech/strfry`) and pushes. FF-only; if `master` diverged it skips (never rewrites).
2. **`check-upstream`** — finds the latest upstream release tag (`X.Y.Z`); if it is **not** an ancestor of `neofry`, flags `new_release=true`.
3. **`open-issue`** — opens a `neofry-rebase` reminder issue (deduped by label) with the exact `git rebase <tag>` recipe.

**Mods are carried as commits on top, so updating = rebasing `neofry` onto the new upstream tag.** Keep our delta small and rebase-friendly. The recipe (from the issue body):

```bash
git fetch origin && git fetch upstream
git checkout neofry && git rebase <tag>
git push origin neofry --force-with-lease
```

## Our mods

Grounded in `git diff origin/master..neofry`. The point of neofry is to **push selected events into Redis** so `brainstorm_server` can consume them.

### Redis event firehose (the core mod)

- **[`src/redis.cpp`](src/redis.cpp) / [`src/redis.h`](src/redis.h)** (new) — thin hiredis wrapper: `redis_init`, `redis_publish`, `redis_hset`, `redis_rpush`, `redis_close`. Single global synchronous connection. `redis.h` is a C-ABI header (`extern "C"`) — keep C++ types out of it.
- **[`src/redisAllowKinds.h`](src/redisAllowKinds.h)** (new) — the single definition of `REDIS_ALLOW_KINDS`, included by both write paths.
- **[`src/onAppStartup.cpp`](src/onAppStartup.cpp)** — on boot, `redis_init(cfg().redis__host, cfg().redis__port)`. **Hard fail (throws) if Redis is unreachable** — neofry will not start without Redis. Writes a `strfry:startup` hash heartbeat.
- **[`src/WriterPipeline.h`](src/WriterPipeline.h)** + **[`src/apps/relay/RelayWriter.cpp`](src/apps/relay/RelayWriter.cpp)** — after a _newly written_ event commits, if its kind is in `REDIS_ALLOW_KINDS` (see [`redisAllowKinds.h`](src/redisAllowKinds.h)) it gets `RPUSH`ed (raw JSON) onto the Redis list **`strfry:events`**. Only `Written` status (not duplicate/replaced) is forwarded.
  - kinds: **0** profile metadata, **3** contacts/follows, **10000** mute list, **1984** reports — exactly the graph/profile inputs Brainstorm needs — plus **5** NIP-09 deletions.
  - **Kind 5 is the deletion signal, and it is the _only_ signal.** A kind-5 that deletes a referenced event does so in `writeEvents()`, which runs **before** the redis-push loop (`txn.commit()` precedes it), and the deleted event emits **no** redis message of its own — only the kind-5 arrives. So a consumer can never read the event that was deleted; it must recompute the author's surviving state from the relay. See `brainstorm_server`'s `process_event_kind_5`.
  - `brainstorm_server` consumes `strfry:events` (see its `app/message_queue_tasks/message_queue_consumer.py`).
- **[`golpe.yaml`](golpe.yaml)** — adds config keys **`redis__host`** (default `redis_strfry`) and **`redis__port`** (default `6379`).

## Releasing the neofry image

[`neofry-build.yml`](.github/workflows/neofry-build.yml) builds `Dockerfile.neofry` and pushes `:latest` + `:neofry-<NEOFRY_VER>-strfry-<STRFRY_VER>` to `ghcr.io/nosfabrica/neofry`. It fires **only on a `neofry-*` tag** (or manual `workflow_dispatch`) — pushing/merging to the `neofry` branch does **not** build. A tag is the one and only release trigger.

Merge the branch into `neofry` **first**, then tag that commit so the tag lives on `neofry`:

```bash
git tag neofry-1.1.0 origin/neofry    # tag the merged tip
git push origin neofry-1.1.0          # builds + push
```

`NEOFRY_VER` is the highest `neofry-*` tag, so bump it every release. Merge mods to `neofry`, never `master`.

## Gotchas

- **neofry hard-requires Redis at startup** — [`onAppStartup.cpp`](src/onAppStartup.cpp) throws if it can't connect. In compose/k8s, Redis must come up first (`depends_on: redis_strfry`).
- **Only `REDIS_ALLOW_KINDS = {0,3,5,1984,10000}` are forwarded** to `strfry:events`. Defined once in [`redisAllowKinds.h`](src/redisAllowKinds.h).
- **Don't add mods to `master`** — all our changes live on `neofry`.
- **Keep the delta rebase-friendly** — every mod is replayed onto each new upstream tag. Avoid touching upstream files more than necessary.
