/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * Copyright (c) 1999-2003 Apple Computer, Inc.  All Rights Reserved.
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

// revised comments by Blaine
// revised for android by Philippe Hausler, Apportable Inc 
#import <pthread.h>
#import <objc/runtime.h>
#import <strings.h>
#import <errno.h>
#define require_action_string(cond, dest, act, msg) do { if (!(cond)) { { act; } DEBUG_LOG("%s", msg); goto dest; } } while (0)
#define require_noerr_string(err, dest, msg) do { if (err) { DEBUG_LOG("%s", msg); goto dest; } } while (0)
#define require_string(cond, dest, msg) do { if (!(cond)) { DEBUG_LOG("%s", msg); goto dest; } } while (0)

enum {
    OBJC_SYNC_SUCCESS                 = 0,
    OBJC_SYNC_NOT_OWNING_THREAD_ERROR = -1,
    OBJC_SYNC_TIMED_OUT               = -2,
    OBJC_SYNC_NOT_INITIALIZED         = -3      
};

typedef struct {
    // struct _objc_initializing_classes *initializingClasses; // for +initialize
    struct SyncCache *syncCache;  // for @synchronize
    // struct alt_handler_list *handlerList;  // for exception alt handlers

    // If you add new fields here, don't forget to update 
    // _objc_pthread_destroyspecific()

} _objc_pthread_data;

//
// Allocate a lock only when needed.  Since few locks are needed at any point
// in time, keep them on a single list.
//

static pthread_mutexattr_t	sRecursiveLockAttr;
static bool			sRecursiveLockAttrIntialized = false;

typedef struct SyncData {
    struct SyncData* nextData;
    id               object;
    volatile int     threadCount;  // number of THREADS using this block
    pthread_mutex_t  mutex;
} SyncData;

typedef struct {
    SyncData *data;
    unsigned int lockCount;  // number of times THIS THREAD locked this block
} SyncCacheItem;

typedef struct SyncCache {
    unsigned int allocated;
    unsigned int used;
    SyncCacheItem list[0];
} SyncCache;

/*
  Fast cache: two fixed pthread keys store a single SyncCacheItem. 
  This avoids malloc of the SyncCache for threads that only synchronize 
  a single object at a time.
  SYNC_DATA_DIRECT_KEY  == SyncCacheItem.data
  SYNC_COUNT_DIRECT_KEY == SyncCacheItem.lockCount
 */

typedef struct {
    SyncData *data;
    pthread_mutex_t lock;

    char align[64 - sizeof (pthread_mutex_t) - sizeof (SyncData *)];
} SyncList __attribute__((aligned(64)));
// aligned to put locks on separate cache lines

// Use multiple parallel lists to decrease contention among unrelated objects.
#define COUNT 16
#define HASH(obj) ((((uintptr_t)(obj)) >> 5) & (COUNT - 1))
#define LOCK_FOR_OBJ(obj) sDataLists[HASH(obj)].lock
#define LIST_FOR_OBJ(obj) sDataLists[HASH(obj)].data
static SyncList sDataLists[COUNT];


enum usage { ACQUIRE, RELEASE, CHECK };

static pthread_once_t _objc_pthread_once;
static pthread_key_t _objc_pthread_key;

static void _objc_destroy_key(void *entry)
{
    free(entry);
}

static void _objc_init_key()
{
    pthread_key_create(&_objc_pthread_key, &_objc_destroy_key);
}

static _objc_pthread_data *_objc_fetch_pthread_data(BOOL create)
{
    _objc_pthread_data *data;
    pthread_once(&_objc_pthread_once, &_objc_init_key);
    data = (_objc_pthread_data *)pthread_getspecific(_objc_pthread_key);
    if (!data  &&  create) {
        data = malloc(sizeof(_objc_pthread_data));
        bzero(data, sizeof(_objc_pthread_data));
        pthread_setspecific(_objc_pthread_key, data);
    }

    return data;
}

static SyncCache *fetch_cache(BOOL create)
{
    _objc_pthread_data *data;
    
    data = _objc_fetch_pthread_data(create);
    if (!data) return NULL;

    if (!data->syncCache) {
        if (!create) {
            return NULL;
        } else {
            int count = 4;
            data->syncCache = calloc(1, sizeof(SyncCache) + 
                                     count*sizeof(SyncCacheItem));
            data->syncCache->allocated = count;
        }
    }

    // Make sure there's at least one open slot in the list.
    if (data->syncCache->allocated == data->syncCache->used) {
        data->syncCache->allocated *= 2;
        data->syncCache = 
            realloc(data->syncCache, sizeof(SyncCache) 
                    + data->syncCache->allocated * sizeof(SyncCacheItem));
    }

    return data->syncCache;
}


static void _destroySyncCache(struct SyncCache *cache)
{
    if (cache) free(cache);
}


static int _obj_lock(id object, enum usage why)
{
    pthread_mutex_t *lockp = &LOCK_FOR_OBJ(object);
    SyncData **listp = &LIST_FOR_OBJ(object);
    SyncData* sync = NULL;
    int result = 0;

    // Check per-thread cache of already-owned locks for matching object
    SyncCache *cache = fetch_cache(NO);
    if (cache) {
        unsigned int i;
        for (i = 0; i < cache->used; i++) {
            SyncCacheItem *item = &cache->list[i];
            if (item->data->object != object) continue;

            // Found a match.
            sync = item->data;
            require_action_string(sync->threadCount > 0, cache_done,
                                  sync = NULL, "_obj_lock cache is buggy");
            require_action_string(item->lockCount > 0, cache_done, 
                                  sync = NULL, "_obj_lock cache is buggy");
                
            switch(why) {
            case ACQUIRE:
                result = pthread_mutex_lock(&sync->mutex);
                item->lockCount++;
                break;
            case RELEASE:
                result = pthread_mutex_unlock(&sync->mutex);
                item->lockCount--;
                if (item->lockCount == 0) {
                    // remove from per-thread cache
                    cache->list[i] = cache->list[--cache->used];
                    // atomic because may collide with concurrent ACQUIRE
                    __sync_add_and_fetch(&sync->threadCount, -1);
                }
                break;
            case CHECK:
                // do nothing
                break;
            }

        cache_done:
            return result;
        }
    }

    // Only new ACQUIRE should get here.
    require_action_string(why == ACQUIRE, really_done,
                          result = EPERM, "_obj_lock is buggy");

    // Thread cache didn't find anything.
    // Walk in-use list looking for matching object
    // Spinlock prevents multiple threads from creating multiple 
    // locks for the same new object.
    // We could keep the nodes in some hash table if we find that there are
    // more than 20 or so distinct locks active, but we don't do that now.
    
    pthread_mutex_lock(lockp);

    {
        SyncData* p;
        SyncData* firstUnused = NULL;
        for (p = *listp; p != NULL; p = p->nextData) {
            if ( p->object == object ) {
                sync = p;
                // atomic because may collide with concurrent RELEASE
                __sync_add_and_fetch(&sync->threadCount, +1);
                goto done;
            }
            if ( (firstUnused == NULL) && (p->threadCount == 0) )
                firstUnused = p;
        }
    
        // an unused one was found, use it
        if ( firstUnused != NULL ) {
            sync = firstUnused;
            sync->object = object;
            sync->threadCount = 1;
            goto done;
        }
    }
                            
    // malloc a new SyncData and add to list.
    // XXX calling malloc with a global lock held is bad practice,
    // might be worth releasing the lock, mallocing, and searching again.
    // But since we never free these guys we won't be stuck in malloc very often.
    sync = (SyncData*)calloc(sizeof(SyncData), 1);
    sync->object = object;
    sync->threadCount = 1;
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&sync->mutex, &attr);
    sync->nextData = *listp;
    *listp = sync;
    
 done:
    pthread_mutex_unlock(lockp);

    require_string(sync != NULL, really_done, "_obj_lock is buggy");
    require_action_string(sync->object == object, really_done,
                          result = EPERM, "_obj_lock is buggy");

    // Save in thread cache
    if (!cache) cache = fetch_cache(YES);
    cache->list[cache->used].data = sync;
    cache->list[cache->used].lockCount = 1;
    cache->used++;

    result = pthread_mutex_lock(&sync->mutex);

 really_done:
    return result;
}

#ifndef NDEBUG
static void objc_sync_nil(void)
{
    // used to attach debugger to correct point where the error occurred
}
#endif

// Begin synchronizing on 'obj'. 
// Allocates recursive mutex associated with 'obj' if needed.
// Returns OBJC_SYNC_SUCCESS once lock is acquired.  
int objc_sync_enter(id obj)
{
    int result = OBJC_SYNC_SUCCESS;

    if (obj) {
        result = _obj_lock(obj, ACQUIRE);
        require_noerr_string(result, done, "mutex_lock failed");
    } else {
        // @synchronized(nil) does nothing
#ifndef NDEBUG
        DEBUG_LOG("NIL SYNC DEBUG: @synchronized(nil); set a breakpoint on objc_sync_nil to debug");
        objc_sync_nil();
#endif
    }

done: 
    return result;
}


// End synchronizing on 'obj'. 
// Returns OBJC_SYNC_SUCCESS or OBJC_SYNC_NOT_OWNING_THREAD_ERROR
int objc_sync_exit(id obj)
{
    int result = OBJC_SYNC_SUCCESS;
    
    if (obj) {
        result = _obj_lock(obj, RELEASE);
        require_noerr_string(result, done, "mutex_unlock failed");
    } else {
        // @synchronized(nil) does nothing
    }
    
done:
    if ( result == EPERM )
         result = OBJC_SYNC_NOT_OWNING_THREAD_ERROR;

    return result;
}

