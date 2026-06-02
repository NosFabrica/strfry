#!/bin/sh
set -eu

curl -fSs --max-time 5 -o /dev/null http://localhost:7777/ || exit 1

# Mirror strfry.sh's router-launch condition: ROUTER must be a real file
# path OR start with Y/y/1 (boolean-mode toggle). Only then is a
# `strfry router` subprocess expected to be running.
expects_router=0
[ -f "${ROUTER:-}" ] && expects_router=1
case "${ROUTER:-}" in [Yy1]*) expects_router=1 ;; esac

if [ "$expects_router" -eq 1 ]; then
    pgrep -f 'strfry router' > /dev/null || exit 1
fi

exit 0
