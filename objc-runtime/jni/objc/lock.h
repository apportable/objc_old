/**
 * libobjc requires recursive mutexes.  These are delegated to the underlying
 * threading implementation.  This file contains a VERY thin wrapper over the
 * Windows and POSIX mutex APIs.
 */

#ifndef __LIBOBJC_LOCK_H_INCLUDED__
#define __LIBOBJC_LOCK_H_INCLUDED__
#if defined(WIN32) && !defined(WIN32_PTHREADS)
#error WIN32 locking routines are not supported properly without a pthread port
#else

#	include <pthread.h>

typedef pthread_mutex_t mutex_t;
// If this pthread implementation has a static initializer for recursive
// mutexes, use that, otherwise fall back to the portable version
//	ifdef PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
//		define INIT_LOCK(x) do{x = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP;}while(0)
//	elif defined(PTHREAD_RECURSIVE_MUTEX_INITIALIZER)
//		define INIT_LOCK(x) do{x = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;}while(0)
//	else
#		define INIT_LOCK(x) x = (mutex_t)PTHREAD_RECURSIVE_MUTEX_INITIALIZER
//	endif

#	define LOCK(x) pthread_mutex_lock(x)
#	define UNLOCK(x) pthread_mutex_unlock(x)
#	define DESTROY_LOCK(x) pthread_mutex_destroy(x)
#endif

__attribute__((unused)) static void objc_release_lock(void *x)
{
	mutex_t *lock = *(mutex_t**)x;
	UNLOCK(lock);
}
/**
 * Acquires the lock and automatically releases it at the end of the current
 * scope.
 */
#define LOCK_FOR_SCOPE(lock) \
	__attribute__((cleanup(objc_release_lock)))\
	__attribute__((unused)) mutex_t *lock_pointer = lock;\
	LOCK(lock)

/**
 * The global runtime mutex.
 */
extern mutex_t runtime_mutex;

#define LOCK_RUNTIME() LOCK(&runtime_mutex)
#define UNLOCK_RUNTIME() UNLOCK(&runtime_mutex)
#define LOCK_RUNTIME_FOR_SCOPE() LOCK_FOR_SCOPE(&runtime_mutex)

#endif // __LIBOBJC_LOCK_H_INCLUDED__
