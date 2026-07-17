#pragma once

#include <cstdint>
#include <unordered_set>

// Kinds forwarded to the `strfry:events` redis list
inline const std::unordered_set<uint16_t> REDIS_ALLOW_KINDS = {
    0, 3, 5, 1984, 10000};
