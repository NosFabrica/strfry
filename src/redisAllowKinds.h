#pragma once

#include <cctype>
#include <cstdint>
#include <string>
#include <unordered_set>

#include "golpe.h"

// Event kinds forwarded to the `strfry:events` redis list. Sourced from
// `cfg().redis__kinds` (comma-separated, set in strfry.conf) so forwarding a new
// kind is a config change + neofry restart — no image rebuild. A kind only helps
// if brainstorm_server's process_strfry_event has a matching handler.
//
// Parsed once on first use (function-local static → thread-safe). Changing the
// config value needs a restart (noReload).
inline const std::unordered_set<uint16_t> &redisAllowKinds() {
    static const std::unordered_set<uint16_t> kinds = [] {
        std::unordered_set<uint16_t> out;
        const std::string &csv = cfg().redis__kinds;
        std::string tok;

        auto flush = [&] {
            if (tok.empty()) return;
            try {
                out.insert(static_cast<uint16_t>(std::stoul(tok)));
            } catch (...) {
                LW << "redis__kinds: ignoring invalid entry '" << tok << "'";
            }
            tok.clear();
        };

        for (char c : csv) {
            if (c == ',') flush();
            else if (!std::isspace((unsigned char)c)) tok += c;
        }
        flush();

        LI << "redis__kinds: forwarding " << out.size() << " kind(s) to strfry:events";
        return out;
    }();
    return kinds;
}
