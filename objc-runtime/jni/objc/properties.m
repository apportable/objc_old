#include "objc/runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "class.h"
#include "properties.h"
#include "objc_debug.h"
#include "uthash.h"
#include <pthread.h>

// Since the compiler now returns extra information in
// the name and attribute labels
struct objc_property_extra {
    objc_property_t property;
    char *name;
    char *attributes;
    UT_hash_handle hh;
};

static struct objc_property_extra* prop_extras = NULL;


typedef pthread_mutex_t objcRefLock;
objcRefLock _objcPropertyLock;

extern int (*_objcRefRLock)(objcRefLock *lock);
extern int (*_objcRefRUnlock)(objcRefLock *lock);
extern int (*_objcRefWLock)(objcRefLock *lock);
extern int (*_objcRefWUnlock)(objcRefLock *lock);
extern int (*_objcRefLockFatal)(const char *err);

#define HASH_RLOCK() if (_objcRefRLock != NULL && _objcRefLockFatal != NULL && _objcRefRLock(&_objcPropertyLock) != 0) _objcRefLockFatal("can't get rdlock")
#define HASH_RUNLOCK() if (_objcRefRUnlock != NULL) _objcRefRUnlock(&_objcPropertyLock)
#define HASH_WLOCK() if (_objcRefWLock != NULL && _objcRefLockFatal != NULL && _objcRefWLock(&_objcPropertyLock) != 0) _objcRefLockFatal("can't get wrlock")
#define HASH_WUNLOCK() if (_objcRefWUnlock != NULL) _objcRefWUnlock(&_objcPropertyLock)

#ifdef __MINGW32__
#include <windows.h>
static unsigned sleep(unsigned seconds)
{
	Sleep(seconds*1000);
	return 0;
}
#endif

// Subset of NSObject interface needed for properties.
@interface NSObject {}
- (id)retain;
- (id)copy;
- (id)autorelease;
- (void)release;
@end

/**
 * Number of spinlocks.  This allocates one page on 32-bit platforms.
 */
#define spinlock_count (1<<10)
const int spinlock_mask = spinlock_count - 1;
/**
 * Integers used as spinlocks for atomic property access.
 */
static int spinlocks[spinlock_count];
/**
 * Get a spin lock from a pointer.  We want to prevent lock contention between
 * properties in the same object - if someone is stupid enough to be using
 * atomic property access, they are probably stupid enough to do it for
 * multiple properties in the same object.  We also want to try to avoid
 * contention between the same property in different objects, so we can't just
 * use the ivar offset.
 */
static inline int *lock_for_pointer(void *ptr)
{
	intptr_t hash = (intptr_t)ptr;
	// Most properties will be pointers, so disregard the lowest few bits
	hash >>= sizeof(void*) == 4 ? 2 : 8;
	intptr_t low = hash & spinlock_mask;
	hash >>= 16;
	hash |= low;
	return spinlocks + (hash & spinlock_mask);
}

inline static void unlock_spinlock(int *spinlock)
{
	*spinlock = 0;
}
inline static void lock_spinlock(int *spinlock)
{
	int count = 0;
	// Set the spin lock value to 1 if it is 0.
	while(!__sync_bool_compare_and_swap(spinlock, 0, 1))
	{
		count++;
		if (0 == count % 10)
		{
			// If it is already 1, let another thread play with the CPU for a
			// bit then try again.
			sleep(0);
		}
	}
}

id objc_getProperty(id obj, SEL _cmd, int offset, BOOL isAtomic)
{
	if (nil == obj) { return nil; }
	char *addr = (char*)obj;
	addr += offset;
	id ret;
	if (isAtomic)
	{
		int *lock = lock_for_pointer(addr);
		lock_spinlock(lock);
		ret = *(id*)addr;
		unlock_spinlock(lock);
	}
	else
	{
		ret = *(id*)addr;
	}
	return ret;
}

void objc_setProperty(id obj, SEL _cmd, int offset, id arg, BOOL isAtomic, BOOL isCopy)
{
	if (nil == obj) { return; }
	if (isCopy)
	{
		arg = [arg copy];
	}
	else
	{
		arg = [arg retain];
	}
	char *addr = (char*)obj;
	addr += offset;
	id old;
	if (isAtomic)
	{
		int *lock = lock_for_pointer(addr);
		lock_spinlock(lock);
		old = *(id*)addr;
		*(id*)addr = arg;
		unlock_spinlock(lock);
	}
	else
	{
		old = *(id*)addr;
		*(id*)addr = arg;
	}
	if(old != NULL && old->isa != NULL && old->isa != 0xdeadface)
		[old release];
}

objc_property_t class_getProperty(Class cls, const char *name)
{
	// Old ABI classes don't have declared properties
	if (Nil == cls || !objc_test_class_flag(cls, objc_class_flag_new_abi))
	{
		return NULL;
	}
	struct objc_property_list *properties = cls->properties;
	while (NULL != properties)
	{
		for (int i=0 ; i<properties->count ; i++)
		{
			objc_property_t p = &properties->properties[i];
			if (strcmp(property_getName(p), name) == 0)
			{
				return p;
			}
		}
		properties = properties->next;
	}

	if(cls->super_class != NULL) {
		return class_getProperty(cls->super_class, name);
	}

	return NULL;
}
objc_property_t* class_copyPropertyList(Class cls, unsigned int *outCount)
{
	if (Nil == cls || !objc_test_class_flag(cls, objc_class_flag_new_abi))
	{
		if (NULL != outCount) { *outCount = 0; }
		return NULL;
	}
	struct objc_property_list *properties = cls->properties;
	unsigned int count = 0;
	for (struct objc_property_list *l=properties ; NULL!=l ; l=l->next)
	{
		count += l->count;
	}
	if (NULL != outCount)
	{
		*outCount = count;
	}
	if (0 == count)
	{
		return NULL;
	}
	objc_property_t *list = calloc(sizeof(objc_property_t), count);
	unsigned int out = 0;
	for (struct objc_property_list *l=properties ; NULL!=l ; l=l->next)
	{
		for (int i=0 ; i<properties->count ; i++)
		{
			list[out++] = &l->properties[i];
		}
	}
	return list;
}
struct objc_property_extra *property_createExtras(objc_property_t property) {

	struct objc_property_extra *entry = (struct objc_property_extra *)malloc(sizeof(struct objc_property_extra));
	entry->property = property;

	// 1. Create the name
	char *c = strchr(property->name, '|');
	entry->name = strndup(property->name, c - property->name);

	// 2. Create the attr string
	// Format of property attributes on iOS

	// T for type name, Example: T@"NSString"
	// & for retain
	// N for nonatomic
	// G for getter, Example: Gval
	// S for setter, Example: SsetVal:
	// V for backing iVar, Example: V_val

	char *attrs = calloc(256, 1);
	
	// Add type information
	attrs = strcat(attrs, "T");
	char *first = strchr(property->name, '|');
	attrs = strncat(attrs, first + 1, strrchr(property->name, '|') - first - 1);

	// & for retain
	if (!(property->attributes & OBJC_PR_assign))
		attrs = strcat(attrs, ",&");

	if (property->attributes & OBJC_PR_nonatomic)
		attrs = strcat(attrs, ",N");

	if (property->attributes & OBJC_PR_getter) {
		attrs = strcat(attrs, ",G");
		attrs = strcat(attrs, property->getter_name);
	}

	if(property->attributes & OBJC_PR_setter) {
		attrs = strcat(attrs, ",S");
		attrs = strcat(attrs, property->setter_name);
	}

	attrs = strcat(attrs, ",V");
	attrs = strcat(attrs, strrchr(property->name, '|') + 1);
	entry->attributes = attrs;

	return entry;
}



const char *property_getName(objc_property_t property)
{
	if(property == NULL) {
		DEBUG_LOG("Property name requested on null property");
		return "";
	}

	struct objc_property_extra* entry = NULL;
	HASH_WLOCK();
	HASH_FIND_PTR(prop_extras, &property, entry);
	if (entry == NULL) {
		entry = property_createExtras(property);
    	HASH_ADD_PTR(prop_extras, property, entry);
	}
	HASH_WUNLOCK();
	return entry->name;
}

const char *property_getAttributes(objc_property_t property)
{
	struct objc_property_extra* entry = NULL;
	HASH_WLOCK();
	HASH_FIND_PTR(prop_extras, &property, entry);
	if (entry == NULL) {
		entry = property_createExtras(property);
    	HASH_ADD_PTR(prop_extras, property, entry);
	}
	HASH_WUNLOCK();
	return entry->attributes;
}

SEL _property_getSetterSelector(objc_property_t property) {
	return sel_registerName(property->setter_name);
}

SEL _property_getGetterSelector(objc_property_t property) {
	return sel_registerName(property->getter_name);
}

const char *_property_getSetterTypes(objc_property_t property) {
	return property->setter_types;
}

const char *_property_getGetterTypes(objc_property_t property) {
	return property->getter_types;
}
