//
//  track.m
//  objc
//
 
#include "objc/runtime.h"
#include "objc_debug.h"
#include "uthash.h"
#include <pthread.h>
#include <unistd.h>


typedef struct {
    Class cls;
    int count;
    UT_hash_handle hh;
} objc_allocations;

static objc_allocations *allocations = NULL;
static pthread_mutex_t allocationLock = PTHREAD_MUTEX_INITIALIZER;
static int track_enabled = 1;
static int track_interval = 5000;

static void log_allocations()
{
	static int idx = 0;
	if (track_interval > 0 && track_enabled != 0)
	{
		idx = (idx + 1) % track_interval;
		if (idx == 0)
		{
			objc_allocations *entry, *tmp;
			DEBUG_LOG("===================ALLOCATIONS===================");
			HASH_ITER(hh, allocations, entry, tmp) 
			{
				if (entry->cls == (Class)0xdeadface)
				{
					DEBUG_LOG("DEADFACE'd objects: %d", entry->count);
				}
				else
				{
					DEBUG_LOG("%s %d", class_getName(entry->cls), entry->count);
				}
			}
			DEBUG_LOG("=================================================");
		}
	}
}

void track_enable(int interval)
{
	track_enabled = 1;
	track_interval = interval;
}

void track_disable()
{
	track_enabled = 0;
}

void track_allocation(Class cls)
{
	pthread_mutex_lock(&allocationLock);
	objc_allocations *entry = NULL;
	HASH_FIND_PTR(allocations, &cls, entry);
	if (entry == NULL)
	{
		entry = malloc(sizeof(objc_allocations));
		entry->cls = cls;
		entry->count = 0;
		HASH_ADD_PTR(allocations, cls, entry);
	}
	entry->count = entry->count + 1;
	log_allocations();
	pthread_mutex_unlock(&allocationLock);
}

void track_deallocation(Class cls)
{
	pthread_mutex_lock(&allocationLock);
	objc_allocations *entry = NULL;
	HASH_FIND_PTR(allocations, &cls, entry);
	if (entry != NULL)
	{
		entry->count = entry->count - 1;
	}
	log_allocations();
	pthread_mutex_unlock(&allocationLock);
}
