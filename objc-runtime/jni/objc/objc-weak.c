#include <Block.h>
#include <objc/runtime.h>
#include <objc/objc-arc.h>

// TODO: FIX ME
static BOOL _objc_rootTryRetain(id obj)
{
    return objc_retain(obj) != nil;
}

extern void _NSConcreteMallocBlock;
extern void _NSConcreteStackBlock;
extern void _NSConcreteGlobalBlock;

typedef struct objc_weak_ref
{
    id obj;
    id *ref[4];
    struct objc_weak_ref *next;
} WeakRef;

static int weak_ref_compare(const id obj, const WeakRef weak_ref)
{
    return obj == weak_ref.obj;
}

static uint32_t ptr_hash(const void *ptr)
{
    // Bit-rotate right 4, since the lowest few bits in an object pointer will
    // always be 0, which is not so useful for a hash value
    return ((uintptr_t)ptr >> 4) | ((uintptr_t)ptr << ((sizeof(id) * 8) - 4));
}

static int weak_ref_hash(const WeakRef weak_ref)
{
    return ptr_hash(weak_ref.obj);
}

static int weak_ref_is_null(const WeakRef weak_ref)
{
    return weak_ref.obj == NULL;
}

const static WeakRef NullWeakRef;
#define MAP_TABLE_NAME weak_ref
#define MAP_TABLE_COMPARE_FUNCTION weak_ref_compare
#define MAP_TABLE_HASH_KEY ptr_hash
#define MAP_TABLE_HASH_VALUE weak_ref_hash
#define MAP_TABLE_HASH_VALUE weak_ref_hash
#define MAP_TABLE_VALUE_TYPE struct objc_weak_ref
#define MAP_TABLE_VALUE_NULL weak_ref_is_null
#define MAP_TABLE_VALUE_PLACEHOLDER NullWeakRef
#define MAP_TABLE_ACCESS_BY_REFERENCE 1
#define MAP_TABLE_SINGLE_THREAD 1
#define MAP_TABLE_NO_LOCK 1

#include "hash_table.h"

static weak_ref_table *weakRefs;
mutex_t weakRefLock;

void* block_load_weak(void *block);

id objc_storeWeak(id *addr, id obj)
{
    id old = *addr;
    LOCK_FOR_SCOPE(&weakRefLock);
    if (nil != old)
    {
        WeakRef *oldRef = weak_ref_table_get(weakRefs, old);
        while (NULL != oldRef)
        {
            for (int i=0 ; i<4 ; i++)
            {
                if (oldRef->ref[i] == addr)
                {
                    oldRef->ref[i] = 0;
                    oldRef = 0;
                    break;
                }
            }
            if (oldRef != NULL)
            {
                oldRef = oldRef->next;
            }
        }
    }
    if (nil == obj)
    {
        *addr = obj;
        return nil;
    }
    Class cls = object_getClass(obj);
    if (&_NSConcreteGlobalBlock == cls)
    {
        // If this is a global block, it's never deallocated, so secretly make
        // this a strong reference
        // TODO: We probably also want to do the same for constant strings and
        // classes.
        *addr = obj;
        return obj;
    }
    if (&_NSConcreteMallocBlock == cls)
    {
        obj = block_load_weak(obj);
    }
    else if (!_objc_rootTryRetain(obj))
    {
        obj = nil;
    }

    if (nil != obj)
    {
        WeakRef *ref = weak_ref_table_get(weakRefs, obj);
        while (NULL != ref)
        {
            for (int i=0 ; i<4 ; i++)
            {
                if (0 == ref->ref[i])
                {
                    ref->ref[i] = addr;
                    *addr = obj;
                    return obj;
                }
            }
            if (ref->next == NULL)
            {
                break;
            }
            ref = ref->next;
        }
        if (NULL != ref)
        {
            ref->next = calloc(sizeof(WeakRef), 1);
            ref->next->ref[0] = addr;
        }
        else
        {
            WeakRef newRef = {0};
            newRef.obj = obj;
            newRef.ref[0] = addr;
            weak_ref_insert(weakRefs, newRef);
        }
    }
    *addr = obj;
    return obj;
}

static void zeroRefs(WeakRef *ref, BOOL shouldFree)
{
    if (NULL != ref->next)
    {
        zeroRefs(ref->next, YES);
    }
    for (int i=0 ; i<4 ; i++)
    {
        if (0 != ref->ref[i])
        {
            *ref->ref[i] = 0;
        }
    }
    if (shouldFree)
    {
        free(ref);
    }
    else
    {
        memset(ref, 0, sizeof(WeakRef));
    }
}

void objc_delete_weak_refs(id obj)
{
    LOCK_FOR_SCOPE(&weakRefLock);
    WeakRef *oldRef = weak_ref_table_get(weakRefs, obj);
    if (0 != oldRef)
    {
        zeroRefs(oldRef, NO);
    }
}

id objc_loadWeakRetained(id* addr)
{
    LOCK_FOR_SCOPE(&weakRefLock);
    id obj = *addr;
    if (nil == obj) { return nil; }
    Class cls = object_getClass(obj);
    if (&_NSConcreteMallocBlock == cls)
    {
        obj = objc_retain(block_load_weak(obj));
    }
    else if (!_objc_rootTryRetain(obj))
    {
        obj = nil;
    }

    return obj;
}

id objc_loadWeak(id* object)
{
    return objc_autorelease(objc_loadWeakRetained(object));
}

void objc_copyWeak(id *dest, id *src)
{
    objc_release(objc_initWeak(dest, objc_loadWeakRetained(src)));
}

void objc_moveWeak(id *dest, id *src)
{
    // Don't retain or release.  While the weak ref lock is held, we know that
    // the object can't be deallocated, so we just move the value and update
    // the weak reference table entry to indicate the new address.
    LOCK_FOR_SCOPE(&weakRefLock); 
    *dest = *src;
    *src = nil;
    WeakRef *oldRef = weak_ref_table_get(weakRefs, *dest);
    while (NULL != oldRef)
    {
        for (int i=0 ; i<4 ; i++)
        {
            if (oldRef->ref[i] == src)
            {
                oldRef->ref[i] = dest;
                return;
            }
        }
    }
}

void objc_destroyWeak(id* obj)
{
    objc_storeWeak(obj, nil);
}

id objc_initWeak(id *object, id value)
{
    *object = nil;
    return objc_storeWeak(object, value);
}

static void objc_init_weak() __attribute__((constructor));
static void objc_init_weak()
{
    weak_ref_initialize(&weakRefs, 128);
    INIT_LOCK(weakRefLock);
}
