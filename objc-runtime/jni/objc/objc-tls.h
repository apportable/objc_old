#include <objc/runtime.h>

typedef struct {
    id reclaim;
} objc_tls;

objc_tls *_objc_tls();