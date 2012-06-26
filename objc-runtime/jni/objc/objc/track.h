#ifndef _OBJC_TRACK_H_
#define _OBJC_TRACK_H_
#if defined(TRACK_OBJC_ALLOCATIONS)
#include <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

void track_enable(int interval);
void track_disable();
void track_allocation(Class cls);
void track_deallocation(Class cls);

#ifdef __cplusplus
}
#endif

#endif
#endif