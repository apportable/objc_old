//
//  associations.mm
//  objc
//
 
#include "objc/runtime.h"
#include "objc_debug.h"
#include "uthash.h"
#include <pthread.h>
#include <unistd.h>
 
typedef void *objcRefLock[10];
objcRefLock _objcReferenceLock;

int (*_objcRefRLock)(objcRefLock *lock) = NULL;
int (*_objcRefRUnlock)(objcRefLock *lock) = NULL;
int (*_objcRefWLock)(objcRefLock *lock) = NULL;
int (*_objcRefWUnlock)(objcRefLock *lock) = NULL;
int (*_objcRefLockFatal)(const char *err) = NULL;

#define HASH_RLOCK() if (_objcRefRLock != NULL && _objcRefLockFatal != NULL && _objcRefRLock(&_objcReferenceLock) != 0) _objcRefLockFatal("can't get rdlock")
#define HASH_RUNLOCK() if (_objcRefRUnlock != NULL) _objcRefRUnlock(&_objcReferenceLock)
#define HASH_WLOCK() if (_objcRefWLock != NULL && _objcRefLockFatal != NULL && _objcRefWLock(&_objcReferenceLock) != 0) _objcRefLockFatal("can't get wrlock")
#define HASH_WUNLOCK() if (_objcRefWUnlock != NULL) _objcRefWUnlock(&_objcReferenceLock)

typedef struct {
    void *key;
    objc_AssociationPolicy policy;
    id value;
    UT_hash_handle hh;
} object_associations;
 
typedef struct {
    id object;
    object_associations *associations;
    UT_hash_handle hh;
} objc_associations;
 
objc_associations *associations = NULL;
 
void _object_set_associative_reference(id object, void *key, id value, uintptr_t policy)
{
    objc_setAssociatedObject(object, key, value, policy);
}
id _object_get_associative_reference(id object, void *key)
{
    return objc_getAssociatedObject(object, key);
}
 
void _object_remove_assocations(id object)
{
    objc_removeAssociatedObjects(object);
}
 
static SEL SEL_release = NULL;
static SEL SEL_retain = NULL;
static SEL SEL_copy = NULL;
 
static inline void initializeSelectors() 
{
	if (SEL_release == NULL)
	{
		SEL_release = sel_registerName("release");
	}
	if (SEL_retain == NULL)
	{
		SEL_retain = sel_registerName("retain");
	}
	if (SEL_copy == NULL)
	{
		SEL_copy = sel_registerName("copy");
	}
}

static id noOp(id self, SEL _cmd, ...) 
{
	return NULL;
}

static IMP getImpOrNoOp(Class cls, SEL cmd) 
{
	if (cls == NULL || cmd == NULL)
	{
		return &noOp;
	}
	else
	{
		IMP imp = class_getMethodImplementation(cls, cmd);
		if (imp == NULL)
		{
			return &noOp;
		}
		else
		{
			return imp;
		}
	}
}

#undef objc_msgSend
#define objc_msgSend(theReceiver, theSelector, ...) \
({\
	id __receiver = theReceiver; \
	SEL op = theSelector; \
	getImpOrNoOp(object_getClass(__receiver), op)(__receiver, op, ##__VA_ARGS__); \
})
 
void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy) 
{
	HASH_WLOCK();
	initializeSelectors();
    objc_associations *object_entry = NULL;
    HASH_FIND_PTR(associations, &object, object_entry);
    if (object_entry == NULL && value != NULL)
    {
        object_entry = (objc_associations *)malloc(sizeof(objc_associations));
        object_entry->object = object;
        object_entry->associations = NULL;
        HASH_ADD_PTR(associations, object, object_entry);
    }
    if (object_entry != NULL) 
    {
        object_associations *association_entry = NULL;
        HASH_FIND_PTR(object_entry->associations, &key, association_entry);
        if (association_entry == NULL && value != NULL)
        {
            association_entry = (object_associations *)malloc(sizeof(object_associations));
            association_entry->key = key;
            association_entry->policy = policy;
            association_entry->value = NULL;
            HASH_ADD_PTR(object_entry->associations, key, association_entry);
        }
        if (association_entry != NULL) 
        {
            switch(policy)
            {
                case OBJC_ASSOCIATION_ASSIGN:
                    association_entry->policy = policy;
                    association_entry->value = value;
                    break;
                case OBJC_ASSOCIATION_RETAIN:
                case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
                    if (association_entry->value != value) 
                    {
                        switch (association_entry->policy) 
                        {
                            case OBJC_ASSOCIATION_RETAIN:
                            case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
                            case OBJC_ASSOCIATION_COPY:
                            case OBJC_ASSOCIATION_COPY_NONATOMIC:
                                objc_msgSend(association_entry->value, SEL_release);
                                break;
                        }
                        if (value != NULL) 
                        {
                            association_entry->value = objc_msgSend(value, SEL_retain);
                        }
                        else 
                        {
                            HASH_DEL(object_entry->associations, association_entry);
                            free(association_entry);
                        }
                    }
                    break;
                case OBJC_ASSOCIATION_COPY:
                case OBJC_ASSOCIATION_COPY_NONATOMIC:
                    if (association_entry->value != value) 
                    {
                        switch (association_entry->policy) 
                        {
                            case OBJC_ASSOCIATION_RETAIN:
                            case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
                            case OBJC_ASSOCIATION_COPY:
                            case OBJC_ASSOCIATION_COPY_NONATOMIC:
                                objc_msgSend(association_entry->value, SEL_release);
                                break;
                        }
                        if (value != NULL) 
                        {
                            association_entry->value = objc_msgSend(value, SEL_copy);
                        }
                        else
                        {
                            HASH_DEL(object_entry->associations, association_entry);
                            free(association_entry);
                        }
                    }
                    break;
            }
        }
    }
    HASH_WUNLOCK();
}
 
id objc_getAssociatedObject(id object, const void *key)
{
    HASH_RLOCK();
    initializeSelectors();
    objc_associations *object_entry = NULL;
    HASH_FIND_PTR(associations, &object, object_entry);
    if (object_entry != NULL) {
        object_associations *association_entry = NULL;
        HASH_FIND_PTR(object_entry->associations, &key, association_entry);
        if (association_entry != NULL)
        {
        	HASH_RUNLOCK();
            return association_entry->value;
        }
    }
    HASH_RUNLOCK();
    return NULL;
}
 
void objc_removeAssociatedObjects(id object)
{
	HASH_WLOCK();
	initializeSelectors();
    objc_associations *object_entry = NULL;
    HASH_FIND_PTR(associations, &object, object_entry);
    if (object_entry != NULL)
    {
        object_associations *association_entry = NULL;
        object_associations *temp = NULL;
        HASH_ITER(hh, object_entry->associations, association_entry, temp)
        {
            HASH_DEL(object_entry->associations, association_entry);
            switch (association_entry->policy)
            {
                case OBJC_ASSOCIATION_RETAIN:
                case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
                case OBJC_ASSOCIATION_COPY:
                case OBJC_ASSOCIATION_COPY_NONATOMIC:
                    objc_msgSend(association_entry->value, SEL_release);
                    break;
            }
            free(association_entry);
        }
        HASH_DEL(associations, object_entry);
        free(object_entry);
    }
    HASH_WUNLOCK();
}
