#include "objc/runtime.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "class.h"
#include "properties.h"
#include "objc_debug.h"

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
			if (strcmp(p->name, name) == 0)
			{
				return p;
			}
		}
		properties = properties->next;
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

const char *property_getName(objc_property_t property)
{
	return property->name;
}

const char *property_getAttributes(objc_property_t property)
{
	// Format of property attributes on iOS

	// T for type name, Example: T@"NSString"
	// & for retain
	// N for nonatomic
	// G for getter, Example: Gval
	// S for setter, Example: SsetVal:
	// V for backing iVar, Example: V_val

	/*
	char *attrs = "";
	if (property->attributes & OBJC_PR_noattr)
	{
		return "";
	}   

	if (property->attributes & OBJC_PR_readonly)
	{
		attrs = "readonly";
	}  

	if (property->attributes & OBJC_PR_getter)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"getter=");
		attrs = strcat(property->getter_name);
	}   

	if (property->attributes & OBJC_PR_assign)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"assign");
	}   

	if (property->attributes & OBJC_PR_readwrite)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"readwrite");
	} 

	if (property->attributes & OBJC_PR_retain)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"retain");
	}   

	if (property->attributes & OBJC_PR_copy)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"copy");
	}   

	if (property->attributes & OBJC_PR_nonatomic)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"nonatomic");
	} 

	if (property->attributes & OBJC_PR_setter)
	{
		if (strlen(attrs) > 0)
			attrs = strcat(attrs, ",");
		attrs = strcat(attrs,"setter=");
		attrs = strcat(property->setter_name);
	}
*/
	DEBUG_LOG("Unimplemented property accessor");
	return "";   
}