#!/bin/bash
# Insert the redis_init() call into the golpe submodule's main.cpp.tt.
#
# The Redis hooks in src/redis.cpp, src/redis.h, and src/WriterPipeline.h
# are committed directly to this repo, but the redis_init() call belongs
# in golpe/main.cpp.tt — which lives in a submodule we don't own. Submodules
# can't carry committed local edits, so we apply the insertion at build time.
#
# Run this AFTER `git submodule update --init` and BEFORE `make setup-golpe`.
# The Docker build invokes it at the right point.
#
# This script validates that each insertion actually landed and exits non-zero
# if not, so any future upstream change to golpe's `loadConfig(...)` signature
# (or main.cpp.tt structure) causes the build to fail loudly instead of
# silently producing a binary whose ETL hook is dormant.
set -e
REPO_DIR="${1:-.}"
TT="$REPO_DIR/golpe/main.cpp.tt"
if [ ! -f "$TT" ]; then
    echo "ERROR: $TT not found. Run \`git submodule update --init\` first." >&2
    exit 1
fi
if grep -q "redis_init" "$TT"; then
    echo "  redis_init already present in $TT (skipping)"
    exit 0
fi
# Add #include "redis.h" at the top of the file, after the first existing
# #include. Uses sed's range form to limit the substitution to one line.
sed -i '0,/#include/{s|#include|#include "redis.h"\n#include|}' "$TT"
# Insert the redis_init() call AFTER loadConfig (inside run(), where cfg()
# is available). Match the prefix `loadConfig(configFile` so this works
# against both upstream's historical 1-arg signature
#     loadConfig(configFile);
# and any future signature that keeps the same prefix, e.g.
#     loadConfig(configFile, parsedSetCli.overrides);
sed -i '/loadConfig(configFile/a\
\
    // Initialize Redis connection for streaming ETL\
    if (redis_init(cfg().redis__host.c_str(), cfg().redis__port) != 0) {\
        LW << "Failed to connect to Redis - streaming ETL disabled";\
    }' "$TT"
# Verify the insertion landed. sed silently no-ops on no-match and exits 0,
# so without this check a signature change in upstream golpe would produce
# a binary with no redis_init() call and no build-time error.
if ! grep -q "redis_init" "$TT"; then
    echo "ERROR: redis_init insertion failed in $TT." >&2
    echo "       sed pattern '/loadConfig(configFile/' did not match." >&2
    echo "       Upstream golpe may have changed its loadConfig signature." >&2
    exit 1
fi
echo "  Added redis.h include and redis_init() call to $TT"