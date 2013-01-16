#include <stdlib.h>
#include <assert.h>
#import "stdio.h"
#import "objc/runtime.h"
#import "objc/blocks_runtime.h"
#import "nsobject.h"
#import "class.h"
#import "selector.h"
#import "visibility.h"
#import "objc/hooks.h"
#import "objc/objc-arc.h"
#import "objc/blocks_runtime.h"
#import <libv/utstripe.h>
#import <pthread.h>
#import <objc/message.h>

#import <objc/runtime.h>
#import "objc-tls.h"
#import "objc-fastarr.h"

id bypass_msgSend_retain(NSObject *obj) __attribute__ ((weak, alias ("_i_NSObject__retain")));
void bypass_msgSend_release(NSObject *obj) __attribute__ ((weak, alias ("_i_NSObject__release")));
id bypass_msgSend_autorelease(NSObject *obj)  __attribute__ ((weak, alias ("_i_NSObject__autorelease")));

extern Class __NSAutoreleasePool();

enum {
    object_deallocating = 0x04,
};
typedef char object_mark;

typedef struct {
    id object;
    NSZone *zone;
    NSUInteger retained;
    object_mark mark;
    UT_hash_handle hh;
} object_entry;

typedef HASH_STRIPE_T(object_entry);
static HASH_STRIPE(object_entry) objectEntries[HASH_NSTRIPES] = HASH_STRIPE_INITIALIZER;

id _objc_rootRetain(id obj)
{
    assert(obj);

    if (isSmallObject(obj))
    {
        return obj;
    }

    object_entry *entry = NULL;
    HASH_STRIPE_FINDLOCK(objectEntries, &obj, entry);
    if (entry != NULL && !(entry->mark & object_deallocating))
    {
        entry->retained++;
    }
    HASH_STRIPE_UNLOCK(objectEntries, &obj);
    return obj;
}

BOOL _objc_rootTryRetain(id obj)
{
    BOOL retained = NO;
    assert(obj);

    if (isSmallObject(obj))
    {
        return retained;
    }

    object_entry *entry = NULL;
    HASH_STRIPE_FINDLOCK(objectEntries, &obj, entry);
    if (entry != NULL && !(entry->mark & object_deallocating))
    {
        entry->retained++;
        retained = YES;
    }
    HASH_STRIPE_UNLOCK(objectEntries, &obj);
    return retained;
}

BOOL _objc_rootReleaseWasZero(id obj)
{
    BOOL wasZero = NO;
    assert(obj);

    if (isSmallObject(obj))
    {
        return NO;
    }

    object_entry *entry = NULL;
    HASH_STRIPE_FINDLOCK(objectEntries, &obj, entry);
    if (entry != NULL && entry->retained == 0 && !(entry->mark & object_deallocating))
    {
        entry->mark |= object_deallocating;
        wasZero = YES;
    }
    else if (entry != NULL && !(entry->mark & object_deallocating))
    {
        entry->retained--;
        wasZero = NO;
    }
    HASH_STRIPE_UNLOCK(objectEntries, &obj);
    return wasZero;
}

id _objc_rootAutorelease(id obj)
{
    assert(obj);
    
    if (isSmallObject(obj))
    {
        return obj;
    }

    return bypass_msgSend_autorelease(obj);
}

uintptr_t _objc_rootRetainCount(id obj)
{
    object_entry *entry = NULL;
    HASH_STRIPE_FINDLOCK(objectEntries, &obj, entry);
    uintptr_t refCount = UINT_MAX - 1;
    if (entry != NULL)
    {
        refCount = entry->retained;
    }
    HASH_STRIPE_UNLOCK(objectEntries, &obj);
    return refCount + 1;
}

id _objc_rootInit(id obj)
{
    return obj;
}

id _objc_rootAllocWithZone(Class cls, NSZone *zone)
{
    object_entry *entry = (object_entry *)malloc(sizeof(object_entry));
    if (entry == NULL)
    {
        DEBUG_LOG("Malloc failure!");
        return nil;
    }
    entry->object = class_createInstance(cls, 0);
    if (entry->object == nil)
    {
        DEBUG_LOG("Malloc failure!");
        free(entry);
        return nil;
    }
    entry->zone = zone;
    entry->retained = 0;
    entry->mark = 0;
    HASH_STRIPE_ADD_PTR(objectEntries, object, entry);
    return entry->object;
}

id _objc_rootAlloc(Class cls)
{
    return [cls allocWithZone:nil];
}

void _objc_rootDealloc(id obj)
{
    assert(obj);

    if (isSmallObject(obj))
    {
        return;
    }

    object_entry *entry = NULL;

    HASH_STRIPE_FINDLOCK(objectEntries, &obj, entry);
    if (entry != NULL && (entry->mark & object_deallocating))
    {
        HASH_STRIPE_DELUNLOCKED(objectEntries, object, entry);
        free(entry);
    }
    HASH_STRIPE_UNLOCK(objectEntries, &obj);
    // objc_removeAssociatedObjects(obj);
    object_dispose(obj);
}

void _objc_rootFinalize(id obj)
{

}

NSZone *_objc_rootZone(id obj)
{
    return NULL;
}

uintptr_t _objc_rootHash(id obj)
{
    return (uintptr_t)obj;
}

BOOL _objc_rootIsDeallocating(id obj)
{
    BOOL isDeallocating = NO;
    object_entry *entry = NULL;
    HASH_STRIPE_FINDUNLOCKED(objectEntries, &obj, entry);
    if (entry != NULL)
    {
        isDeallocating = entry->mark & object_deallocating;
    }
    return isDeallocating;
}

@implementation NSObject

+ (void)load
{

}

+ (void)initialize
{

}

+ (id)self
{
    return (id)self;
}

- (id)self
{
    return self;
}

+ (Class)class
{
    return self;
}

- (Class)class
{
    return object_getClass(self);
}

+ (Class)superclass
{
    return class_getSuperclass(self);
}

- (Class)superclass
{
    return class_getSuperclass([self class]);
}

+ (BOOL)isMemberOfClass:(Class)cls
{
    return object_getClass((id)self) == cls;
}

- (BOOL)isMemberOfClass:(Class)cls
{
    return [self class] == cls;
}

+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = class_getSuperclass(tcls))
    {
        if (tcls == cls)
        {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)cls
{
    for (Class tcls = [self class]; tcls; tcls = class_getSuperclass(tcls))
    {
        if (tcls == cls)
        {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)isSubclassOfClass:(Class)cls
{
    for (Class tcls = self; tcls; tcls = class_getSuperclass(tcls))
    {
        if (tcls == cls)
        {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)isAncestorOfObject:(NSObject *)obj
{
    for (Class tcls = [obj class]; tcls; tcls = class_getSuperclass(tcls))
    {
        if (tcls == self)
        {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)instancesRespondToSelector:(SEL)sel
{
    if (!sel)
    {
        return NO;
    }
    return class_respondsToSelector(self, sel);
}

+ (BOOL)respondsToSelector:(SEL)sel
{
    if (!sel)
    {
        return NO;
    }
    return class_respondsToSelector(object_getClass((id)self), sel);
}

- (BOOL)respondsToSelector:(SEL)sel
{
    if (!sel)
    {
        return NO;
    }
    return class_respondsToSelector([self class], sel);
}

+ (BOOL)conformsToProtocol:(Protocol *)protocol {
    if (!protocol)
    {
        return NO;
    }
    for (Class tcls = self; tcls; tcls = class_getSuperclass(tcls))
    {
        if (class_conformsToProtocol(tcls, protocol))
    	{
    		return YES;
    	}
    }
    return NO;
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
    if (!protocol)
    {
        return NO;
    }
    for (Class tcls = [self class]; tcls; tcls = class_getSuperclass(tcls))
    {
        if (class_conformsToProtocol(tcls, protocol))
    	{
    		return YES;
    	}
    }
    return NO;
}

+ (NSUInteger)hash
{
    return _objc_rootHash(self);
}

- (NSUInteger)hash
{
    return _objc_rootHash(self);
}

+ (BOOL)isEqual:(id)obj
{
    return obj == (id)self;
}

- (BOOL)isEqual:(id)obj
{
    return obj == self;
}


+ (BOOL)isFault
{
    return NO;
}

- (BOOL)isFault
{
    return NO;
}

+ (BOOL)isProxy
{
    return NO;
}

- (BOOL)isProxy
{
    return NO;
}

+ (BOOL)isBlock 
{
    return NO;
}

- (BOOL)isBlock 
{
    return NO;
}


+ (IMP)instanceMethodForSelector:(SEL)sel
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    IMP i = class_getMethodImplementation(self, sel);
    if (i == NULL)
    {
    	DEBUG_BREAK(); // DONT IGNORE THIS! FIX THE PROBLEM!
    }
    return i;
}

+ (IMP)methodForSelector:(SEL)sel
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    IMP i = class_getMethodImplementation(object_getClass((id)self), sel);
    if (i == NULL)
    {
    	DEBUG_BREAK(); // DONT IGNORE THIS! FIX THE PROBLEM!
    }
    return i;
}

- (IMP)methodForSelector:(SEL)sel
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    IMP i = class_getMethodImplementation([self class], sel);
    if (i == NULL)
    {
    	DEBUG_BREAK(); // DONT IGNORE THIS! FIX THE PROBLEM!
    }
    return i;
}

+ (BOOL)resolveClassMethod:(SEL)sel
{
    return NO;
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    return NO;
}

+ (void)doesNotRecognizeSelector:(SEL)sel
{

}

- (void)doesNotRecognizeSelector:(SEL)sel
{

}

+ (id)performSelector:(SEL)sel
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    return ((id(*)(id, SEL))objc_msgSend)((id)self, sel);
}

+ (id)performSelector:(SEL)sel withObject:(id)obj
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    return ((id(*)(id, SEL, id))objc_msgSend)((id)self, sel, obj);
}

+ (id)performSelector:(SEL)sel withObject:(id)obj1 withObject:(id)obj2
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    return ((id(*)(id, SEL, id, id))objc_msgSend)((id)self, sel, obj1, obj2);
}

- (id)performSelector:(SEL)sel
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    return ((id(*)(id, SEL))objc_msgSend)(self, sel);
}

- (id)performSelector:(SEL)sel withObject:(id)obj
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    return ((id(*)(id, SEL, id))objc_msgSend)(self, sel, obj);
}

- (id)performSelector:(SEL)sel withObject:(id)obj1 withObject:(id)obj2 
{
    if (!sel)
    {
        [self doesNotRecognizeSelector:sel];
    }
    return ((id(*)(id, SEL, id, id))objc_msgSend)(self, sel, obj1, obj2);
}

+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)sel
{
    return nil;
}

+ (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    return nil;
}

+ (void)forwardInvocation:(NSInvocation *)invocation
{
    [self doesNotRecognizeSelector:(invocation ? [invocation selector] : 0)];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [self doesNotRecognizeSelector:(invocation ? [invocation selector] : 0)];
}

+ (id)forwardingTargetForSelector:(SEL)sel
{
    return nil;
}

- (id)forwardingTargetForSelector:(SEL)sel
{
    return nil;
}

+ (NSString *)description
{
    return nil;
}

- (NSString *)description
{
    return nil;
}

+ (NSString *)debugDescription
{
    return [self description];
}

- (NSString *)debugDescription
{
    return [self description];
}

+ (id)new 
{
    return [[self alloc] init];
}

+ (id)retain
{
    return (id)self;
}

- (id)retain __attribute__((aligned(16)))
{
    return _objc_rootRetain(self);
}

+ (BOOL)_tryRetain
{
    return YES;
}

- (BOOL)_tryRetain
{
    return _objc_rootTryRetain(self);
}

+ (BOOL)_isDeallocating
{
    return NO;
}

- (BOOL)_isDeallocating
{
    return _objc_rootIsDeallocating(self);
}

+ (BOOL)allowsWeakReference
{ 
    return YES; 
}

+ (BOOL)retainWeakReference
{ 
    return YES; 
}

- (BOOL)allowsWeakReference
{ 
    return ! [self _isDeallocating]; 
}

- (BOOL)retainWeakReference
{ 
    return [self _tryRetain]; 
}

+ (oneway void)release
{

}

- (oneway void)release __attribute__((aligned(16)))
{
    if (_objc_rootReleaseWasZero(self) == NO)
    {
        return;
    }

    [self dealloc];
}

+ (id)autorelease
{
    return (id)self;
}

- (id)autorelease __attribute__((aligned(16)))
{
    assert(_objc_tls()->reclaim == NULL);

    if (callerAcceptsFastAutorelease(__builtin_return_address(0))) {
        _objc_tls()->reclaim = self;
        return self;
    }

    return [__NSAutoreleasePool() addObject:self];
}

+ (NSUInteger)retainCount
{
    return ULONG_MAX;
}

- (NSUInteger)retainCount
{
    return _objc_rootRetainCount(self);
}

+ (id)alloc
{
    return _objc_rootAlloc(self);
}

+ (id)allocWithZone:(NSZone *)zone
{
    return _objc_rootAllocWithZone(self, zone);
}

+ (id)init
{
    return (id)self;
}

- (id)init
{
    return _objc_rootInit(self);
}

+ (void)dealloc
{

}

- (void)dealloc
{
    _objc_rootDealloc(self);
}

+ (void)finalize 
{

}

- (void)finalize
{
    _objc_rootFinalize(self);
}

+ (NSZone *)zone
{
    return (NSZone *)_objc_rootZone(self);
}

- (NSZone *)zone
{
    return (NSZone *)_objc_rootZone(self);
}

+ (id)copy
{
    return (id)self;
}

+ (id)copyWithZone:(NSZone *)zone
{
    return (id)self;
}

- (id)copy
{
    return [(id)self copyWithZone:NULL];
}

+ (id)mutableCopy
{
    return (id)self;
}

+ (id)mutableCopyWithZone:(NSZone *)zone
{
    return (id)self;
}

- (id)mutableCopy
{
    return [(id)self mutableCopyWithZone:NULL];
}

void _objectIsValid_error_break() {
  return;
}

+ (BOOL)_objectIsValid:(id)object
{
    object_entry *entry = NULL;
    HASH_STRIPE_FIND(objectEntries, &object, entry);
    if (!entry) {
      DEBUG_LOG("object is invalid. set a breakpoint in _objectIsValid_error_break to debug");
      _objectIsValid_error_break();
    }
    return entry != NULL;
}

@end
