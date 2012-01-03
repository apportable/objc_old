#include "../objc/runtime.h"
#import "malloc.h"
#import "object.h"
#import "thread.h"
#import "trace.h"
#import "cycle.h"
#import "visit.h"
#import "workqueue.h"
#import "static.h"
#include <stdlib.h>
#include <stdio.h>

/**
 * Pointer comparison.  Needed for the hash table.
 */
static int pointer_compare(const void *a, const void *b)
{
	return a == b;
}
static int pointer_hash(const void *obj)
{
	intptr_t ptr = (intptr_t)obj;
	return (ptr >> 8) | (ptr << 8);
}
#define MAP_TABLE_NAME known_object 
#define MAP_TABLE_COMPARE_FUNCTION pointer_compare
#define MAP_TABLE_HASH_KEY pointer_hash
#define MAP_TABLE_HASH_VALUE pointer_hash
#include "../hash_table.h"

@interface GCObject
- (void)finalize;
@end

static void* malloc_zone_alloc(void *zone, size_t bytes)
{
	return calloc(1, bytes);
}

void *(*gc_alloc_with_zone)(void *zone, size_t bytes) = malloc_zone_alloc;

static void malloc_zone_free(void *zone, void *mem)
{
	free(mem);
}

void (*gc_free_with_zone)(void *zone, void *mem) = malloc_zone_free;

/**
 * Macro for calculating the size of a header structure, including padding
 * required for alignment.
 */
#define headerSize(header)\
({\
	size_t headerSize = sizeof(struct header);\
	/* Everything else expects the isa pointer to be correctly aligned and all\
	 * subsequent ivars will be placed with the assumption that they have the\
	 * correct alignment, so make sure this is really the case. */\
	if (headerSize % __alignof(void*))\
	{\
		headerSize += headerSize % __alignof(void*);\
	}\
	headerSize;\
})

id GCAllocateObjectWithZone(Class cls, void *zone, size_t extraBytes)
{
	// Allocate space for the header and ivars.
	size_t allocSize = headerSize(gc_object_header) + class_getInstanceSize(cls);
	// And for the extra space that we were asked for.
	allocSize += extraBytes;
	struct gc_object_header *region = gc_alloc_with_zone(zone, allocSize);
	region->zone = zone;
	id obj = (id)((char*)region + headerSize(gc_object_header));
	obj->isa = cls;
	// Reference count is 0, so set visited to prevent it from being collected
	// immediately
	GCSetFlag(obj, GCFlagVisited);
	// Mark as free or in use.
	GCSetColourOfObject(obj, GCColourBlack);
	// Add to traced map later, if it hasn't been retained
	GCAddObject(obj);
	return obj;
}

void *GCAllocateBufferWithZone(void *zone, size_t size, BOOL scan)
{
	size_t allocSize = headerSize(gc_buffer_header) + size;
	struct gc_buffer_header *region = gc_alloc_with_zone(zone, allocSize);
	region->size = size;
	region->object_header.zone = zone;
	char *buffer = ((char*)region) + headerSize(gc_buffer_header);
	if (scan)
	{
		GCAddBufferForTracing(region);
	}
	// Reference count is 0, so set visited to prevent it from being collected
	// immediately
	GCSetFlag((id)buffer, GCFlagVisited);
	GCSetFlag((id)buffer, GCFlagNotObject);
	// Mark as free or in use.
	GCSetColourOfObject((id)buffer, GCColourBlack);
	// Add to traced map later, if it hasn't been retained
	GCAddObject((id)buffer);
	return buffer;
}

static void freeObject(id object)
{
	void * addr;
	if (GCTestFlag(object, GCFlagNotObject))
	{
		fprintf(stderr, "Freeing bufer %x\n", (int)object);
		addr = GCHeaderForBuffer(object);
	}
	else
	{
		addr = GCHeaderForObject(object);
	}
	fprintf(stderr, "Freeing %x\n", (int)object);
	gc_free_with_zone(GCHeaderForObject(object)->zone, addr);
}

void GCWeakRelease(id anObject)
{
	if (!GCObjectIsDynamic(anObject)) { return; }
	long count = GCDecrementWeakCount(anObject);
	// If the object has been finalized and this is the last weak ref, free it.
	if (count == 0 && GCColourOfObject(anObject) == GCColourOrange)
	{
		freeObject(anObject);
	}
}
id GCWeakRetain(id anObject)
{
	if (!GCObjectIsDynamic(anObject)) { return anObject; }
	// If this object has already been finalized, return nil.
	if (GCColourOfObject(anObject) == GCColourOrange)
	{
		return nil;
	}
	GCIncrementWeakCount(anObject);
	return anObject;
}
// NOTE: Weak read should add the object for tracing.

void GCAddObjectForTracing(id object);

static BOOL foundRedObjects;

static void releaseObjects(id object, void *context, BOOL isWeak)
{
	//fprintf(stderr, "Releasing %x\n", (int)object);
	if (isWeak)
	{
		GCWeakRelease(object);
	}
	else
	{
		GCColour colour = GCColourOfObject(object);
		// If we're freeing a cycle, mark this object as orange, finalize it,
		// then tell the tracing code to really delete it later
		if (colour == GCColourRed)
		{
			foundRedObjects = YES;
			GCSetColourOfObject(object, GCColourOrange);
			[object finalize];
		}
		else if (colour != GCColourOrange)
		{
			GCRelease(object);
		}
		//fprintf(stderr, "Object has refcount %d\n", (int)GCGetRetainCount(object));
		if (GCGetRetainCount(object) <= 0)
		{
			GCAddObjectForTracing(object);
		}
	}
}

/**
 * Finalizes an object and frees it if its weak reference count is 0.
 *
 * This version must only be called from the GC thread.
 */
void GCFreeObjectUnsafe(id object)
{
	if (!GCObjectIsDynamic(object)) { return; }

	//fprintf(stderr, "Going to Free object %x\n", (int)(object));

	foundRedObjects = NO;
	if (GCColourOrange != GCSetColourOfObject(object, GCColourOrange))
	{
		// If this is really an object, kill all of its references and then
		// finalize it.
		if (!GCTestFlag(object, GCFlagNotObject))
		{
			if (0)
			GCVisitChildren(object, releaseObjects, NULL, YES);
			[object finalize];
		}
		// FIXME: Implement this.
		//GCRemoveRegionFromTracingUnsafe(region);
	}
	if (GCGetWeakRefCount(object) == 0)
	{
		//fprintf(stderr, "Freeing object %x\n", (int)(object));
		freeObject(object);
	}
	if (foundRedObjects)
	{
		GCRunTracerIfNeeded(NO);
	}
}

void GCFreeObject(id object)
{
	GCPerform((void(*)(void*))GCFreeObjectUnsafe, object);
}
