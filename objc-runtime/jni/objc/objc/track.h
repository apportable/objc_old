#ifndef _OBJC_TRACK_H_
#define _OBJC_TRACK_H_

#include <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

void track_enable(void);
void track_disable(void);

/* Causes track_breakpoint() to be called if number of allocations for
 * the class exceeds specified count. If class is NULL count is matched
 * agains all allocations.
 */
void track_break_on_allocations(size_t count, Class cls);
void track_breakpoint(void);

void track_allocation(Class cls);
void track_deallocation(Class cls);
void track_swizzle(Class cls_from, Class cls_to);

/* Logs current allocations.
 */
void track_log(void);

/* Each invocation logs delta allocations since the last calls.
 */
void track_snapshot(void);

/* Clears allocations and snapshots.
 */
void track_clear(void);

/* Clears snapshots, as if track_snapshot() was never called.
 */
void track_clear_snapshots(void);

#ifdef __cplusplus
}
#endif

#endif // _OBJC_TRACK_H_
