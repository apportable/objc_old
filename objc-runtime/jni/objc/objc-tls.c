#include <pthread.h>
#include "objc-tls.h"

static pthread_key_t tls_key;

static void objc_tls_destructor(void *ctx)
{
    if (ctx != NULL)
    {
        free(ctx);
    }
}

objc_tls *_objc_tls()
{
    objc_tls *tls = pthread_getspecific(tls_key);
    if (tls == NULL)
    {
        tls = malloc(sizeof(objc_tls));
        tls->reclaim = nil;
        pthread_setspecific(tls_key, tls);
    }
    return tls;
}

static void objc_init_tls() __attribute__((constructor(0)));
static void objc_init_tls()
{
    pthread_key_create(&tls_key, &objc_tls_destructor);
}