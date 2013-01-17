#import <objc/runtime.h>
#import <assert.h>
#import <Block.h>
#import "class.h"
#import "objc-tls.h"
#import "objc-fastarr.h"

Class __NSAutoreleasePool()
{
    static Class AutoreleasePool;
    if (Nil == AutoreleasePool)
    {
        AutoreleasePool = objc_getRequiredClass("NSAutoreleasePool");
        // Force an initialize via class accessor
        [AutoreleasePool class];
    }
    return AutoreleasePool;
}

id objc_autoreleaseReturnValue(id obj)
{
    assert(_objc_tls()->reclaim == NULL);

    if (callerAcceptsFastAutorelease(__builtin_return_address(0)))
    {
        _objc_tls()->reclaim = obj;
        return obj;
    }

    return objc_autorelease(obj);
}

id objc_retainAutoreleaseReturnValue(id obj)
{
    return objc_autoreleaseReturnValue(objc_retain(obj));
}

id objc_retainAutoreleasedReturnValue(id obj)
{
    if (obj == _objc_tls()->reclaim)
    {
        _objc_tls()->reclaim = NULL;
        return obj;
    }
    return objc_retain(obj);
}

id objc_storeStrong(id *location, id obj)
{
    id prev = *location;
    if (obj == prev)
    {
        return obj;
    }
    objc_retain(obj);
    *location = obj;
    objc_release(prev);
    return obj;
}

id objc_retainAutorelease(id obj)
{
    if (obj == nil || isSmallObject(obj))
    {
        return obj;
    }
    return objc_autorelease(objc_retain(obj));
}

__attribute__((aligned(16))) void objc_release(id obj)
{
    if (obj == nil || isSmallObject(obj))
    {
        return;
    }
    [obj release];
}

__attribute__((aligned(16))) id objc_retain(id obj)
{
    if (obj == nil || isSmallObject(obj))
    {
        return obj;
    }
    // TODO: add customRR flag to clang codegen
    return [obj retain];
}

void *objc_retainBlock(void *block)
{
    return _Block_copy(block);
}

__attribute__((aligned(16))) id objc_autorelease(id obj)
{
    if (obj == nil || isSmallObject(obj))
    {
        return obj;
    }
    // TODO: add customRR flag to clang codegen
    return [obj autorelease];
}

BOOL objc_should_deallocate(id object)
{
    return YES;
}

id objc_retain_autorelease(id obj)
{
    return objc_autorelease(objc_retain(obj));
}

void *objc_autoreleasePoolPush(void)
{
    return [__NSAutoreleasePool() new];
}

void objc_autoreleasePoolPop(void *pool)
{
    [_objc_tls()->reclaim release];
    [(id)pool drain];
}
