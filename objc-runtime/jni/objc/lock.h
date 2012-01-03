// libobjc requires recursive mutexes.  These are delegated to the underlying
// threading implementation.

#ifndef __LIBOBJC_LOCK_H_INCLUDED__
#define __LIBOBJC_LOCK_H_INCLUDED__

#ifdef WIN32
#	include <windows.h>
typedef HANDLE mutex_t;
#	define INIT_LOCK(x) x = CreateMutex(NULL, FALSE, NULL)
#	define LOCK(x) WaitForSingleObject(x, INFINITE)
#	define UNLOCK(x) ReleaseMutex(x)
#	define DESTROY_LOCK(x) CloseHandle(x)
#else

#	include <pthread.h>

typedef pthread_mutex_t mutex_t;

#	define INIT_LOCK(x) init_recursive_mutex(&(x))

static inline void init_recursive_mutex(pthread_mutex_t *x)
{
	pthread_mutexattr_t recursiveAttributes;
	pthread_mutexattr_init(&recursiveAttributes);
	pthread_mutexattr_settype(&recursiveAttributes, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(x, &recursiveAttributes);
	pthread_mutexattr_destroy(&recursiveAttributes);
}

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
#define LOCK_UNTIL_RETURN(lock) \
	__attribute__((cleanup(objc_release_lock)))\
	__attribute__((unused)) mutex_t *lock_pointer = lock;\
	LOCK(lock)

/**
 * The global runtime mutex.
 */
extern void *__objc_runtime_mutex;

#endif // __LIBOBJC_LOCK_H_INCLUDED__
