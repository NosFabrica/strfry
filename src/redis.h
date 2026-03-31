#ifdef __cplusplus
extern "C" {
#endif

int redis_init(const char *host, int port);
void redis_publish(const char *channel, const char *message);
void redis_hset(const char *key, const char *field, const char *value); // new
void redis_rpush(const char *key, const char *value);
void redis_close(void);

#ifdef __cplusplus
}
#endif
