/**
 * toydispatch implements a (tiny) subset of the libdispatch interfaces.  It
 * can produce FIFO work queues, but not concurrent ones (although queues are
 * concurrent with respect to each other, as with libdispatch).  Unlike
 * libdispatch, queues all run on the same system thread.  This is less
 * efficient, so the real libdispatch should be used on platforms where it is
 * available.
 *
 * Toydispatch symbol names are prefixed with toy_ so programs can be linked to
 * both libdispatch and toydispatch.  
 */

/* If the real libdispatch exists, use that instead of the toy one. */
#if !defined(__has_include)
#define __has_include(x) 0
#endif
#if __has_include(<dispatch/dispatch.h>) && !defined(__TOY_DISPATCH__)
#	include <sys/types.h>
#	include <dispatch/dispatch.h>
#else

#include <stdint.h>

#ifdef __BLOCKS__
typedef void (^dispatch_block_t)(void);
#endif

typedef long dispatch_once_t;
typedef uint64_t dispatch_time_t;

#ifdef NSEC_PER_SEC
#undef NSEC_PER_SEC
#endif
#ifdef USEC_PER_SEC
#undef USEC_PER_SEC
#endif
#ifdef NSEC_PER_USEC
#undef NSEC_PER_USEC
#endif
#ifdef NSEC_PER_MSEC
#undef NSEC_PER_MSEC
#endif
#define NSEC_PER_SEC 1000000000ull
#define NSEC_PER_MSEC 1000000ull
#define USEC_PER_SEC 1000000ull
#define NSEC_PER_USEC 1000ull


#define DISPATCH_TIME_NOW 0
#define DISPATCH_TIME_FOREVER (~0ull)

/**
 * Function type for functions that can be added to dispatch queues.
 */
typedef void (*dispatch_function_t)(void *);

typedef struct dispatch_queue * dispatch_queue_t;

#define dispatch_queue_create toy_dispatch_queue_create
/**
 * Create a new queue.  Both parameters are ignored by toydispatch.
 */
dispatch_queue_t dispatch_queue_create(const char *label,
		void *attr);

dispatch_queue_t dispatch_get_main_queue(void);

#define dispatch_async_f toy_dispatch_async_f

/**
 * Add a function to the queue.  
 */

#ifdef __BLOCKS__
void dispatch_async(dispatch_queue_t queue, void (^block)(void));
void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, void (^block)(void));
#endif

void dispatch_async_f(dispatch_queue_t queue, void *context,
		dispatch_function_t work);

#define dispatch_release toy_dispatch_release
void dispatch_release(dispatch_queue_t queue);

#define dispatch_retain toy_dispatch_retain
void dispatch_retain(dispatch_queue_t queue);
#endif

dispatch_time_t dispatch_time(dispatch_time_t base, int64_t offset);

void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);