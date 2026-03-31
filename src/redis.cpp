#include <hiredis/hiredis.h>
#include "redis.h"
#include <cstdio>
#include <cstdlib>

static redisContext *redis = nullptr;

int redis_init(const char *host, int port) {
    redis = redisConnect(host, port);
    if (!redis || redis->err) {
        if (redis) {
            fprintf(stderr, "Redis error: %s\n", redis->errstr);
            redisFree(redis);
        } else {
            fprintf(stderr, "Redis allocation error\n");
        }
        return -1;
    }
    return 0;
}

void redis_publish(const char *channel, const char *message) {
    if (!redis) return;
    redisReply *reply = (redisReply *)redisCommand(redis, "PUBLISH %s %s", channel, message);
    if (reply) freeReplyObject(reply);
}

// --- New hash helper ---
void redis_hset(const char *key, const char *field, const char *value) {
    if (!redis) return;
    redisReply *reply = (redisReply *)redisCommand(redis, "HSET %s %s %s", key, field, value);
    if (reply) freeReplyObject(reply);
}

void redis_rpush(const char *key, const char *value) {
    if (!redis) return;

    redisReply *reply = (redisReply *)redisCommand(
        redis,
        "RPUSH %s %s",
        key,
        value
    );

    if (reply) {
        freeReplyObject(reply);
    }
}

void redis_close(void) {
    if (redis) {
        redisFree(redis);
        redis = nullptr;
    }
}
