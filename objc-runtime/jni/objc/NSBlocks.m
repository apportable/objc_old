#import "objc/runtime.h"
#import "class.h"
#import "lock.h"
#import "blocks/Block_private.h"
#import "dtable.h"
#include <assert.h>

static struct objc_class __NSBlock;

static struct objc_class *_NSBlock = &__NSBlock;
static struct objc_class _NSBlockMeta;

static struct objc_class _NSConcreteStackBlockMeta;
static struct objc_class _NSConcreteMallocBlockMeta;
static struct objc_class _NSConcreteAutoBlockMeta;
static struct objc_class _NSConcreteFinalizingBlockMeta;
static struct objc_class _NSConcreteGlobalBlockMeta;

static void *_NSBlockCopyNoZone(void *src, SEL _cmd) {
	return _Block_copy(src);
}

static void *_NSBlockCopy(void *src, SEL _cmd, void *zone) {
	return _Block_copy(src);
}

static void _NSBlockRelease(void *src, SEL _cmd) {
	_Block_release(src);
}

static void *_NSBlockRetain(void *src, SEL _cmd) {
	return _Block_retain(src);
}

static id _NSBlockDescription(void *src, SEL _cmd) {
	
	const char *description = _Block_dump(src);
	// return [[[NSString alloc] initWithUTF8String:description] autorelease];
	static Class NSStringClass = NULL;
	static IMP NSStringAlloc = NULL;
	static IMP NSStringInitWithUTF8String = NULL;
	static IMP NSStringAutorelease = NULL;
	if (NSStringClass == NULL)
	{
		NSStringClass = objc_getClass("NSString");
	}
	if (NSStringAlloc == NULL)
	{
		Method m = class_getClassMethod(NSStringClass, sel_registerName("allocWithZone:"));
		NSStringAlloc = method_getImplementation(m);
	}
	if (NSStringInitWithUTF8String == NULL)
	{
		Method m = class_getInstanceMethod(NSStringClass, sel_registerName("initWithUTF8String:"));
		NSStringInitWithUTF8String = method_getImplementation(m);
	}
	if (NSStringAutorelease == NULL)
	{
		Method m = class_getInstanceMethod(NSStringClass, sel_registerName("autorelease"));
		NSStringAutorelease = method_getImplementation(m);
	}
	return NSStringAutorelease(NSStringInitWithUTF8String(NSStringAlloc(NSStringClass, sel_getUid("allocWithZone:"), NULL), sel_getUid("initWithUTF8String:"), description), sel_getUid("autorelease"));
}

static void createNSBlockSubclass(Class superclass, Class newClass, 
		Class metaClass, char *name)
{
	metaClass->info = objc_class_flag_meta;
	metaClass->dtable = uninstalled_dtable;

	newClass->isa = metaClass;
	newClass->super_class = (Class)superclass->name;
	newClass->name = name;
	newClass->info = objc_class_flag_class;
	newClass->dtable = uninstalled_dtable;

	LOCK_RUNTIME_FOR_SCOPE();
	class_table_insert(newClass);
}

#define NEW_CLASS(super, sub) \
	createNSBlockSubclass(super, sub, &sub ## Meta, #sub)

BOOL objc_create_block_classes_as_subclasses_of(Class super)
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		DEBUG_LOG("Initialize block classes!");

		NEW_CLASS(super, _NSBlock);
		class_addMethod(_NSBlock, sel_registerName("release"), (IMP)&_NSBlockRelease, "v@:");
		class_addMethod(_NSBlock, sel_registerName("retain"), (IMP)&_NSBlockRetain, "@@:");
		class_addMethod(_NSBlock, sel_registerName("copy"), (IMP)&_NSBlockCopyNoZone, "@@:");
		class_addMethod(_NSBlock, sel_registerName("copyWithZone:"), (IMP)&_NSBlockCopy, "@@0:^{_NSZone=^?^?^?^?^?^?^?I@^{_NSZone}}");
		class_addMethod(_NSBlock, sel_registerName("description"), (IMP)&_NSBlockDescription, "@@:");
		NEW_CLASS(_NSBlock, _NSConcreteStackBlock);
		NEW_CLASS(_NSBlock, _NSConcreteMallocBlock);
		NEW_CLASS(_NSBlock, _NSConcreteAutoBlock);
		NEW_CLASS(_NSBlock, _NSConcreteFinalizingBlock);
		NEW_CLASS(_NSBlock, _NSConcreteGlobalBlock);
	}

	return YES;
}
