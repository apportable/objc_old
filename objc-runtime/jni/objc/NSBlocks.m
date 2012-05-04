#import "objc/runtime.h"
#import "class.h"
#import "lock.h"
#import "blocks/Block_private.h"
#import "dtable.h"
#include "objc_debug.h"
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
	return _Block_copy(src);
}

static void createNSBlockSubclass(Class superclass, Class newClass, 
		Class metaClass, char *name)
{
	metaClass->info = objc_class_flag_meta;
	metaClass->super_class = superclass;
	metaClass->name = strdup(name);
	metaClass->info = objc_class_flag_meta | objc_class_flag_resolved;
	metaClass->dtable = __objc_uninstalled_dtable;

	newClass->isa = metaClass;
	newClass->super_class = superclass;
	newClass->name = strdup(name);
	newClass->info = objc_class_flag_class | objc_class_flag_resolved;
	newClass->dtable = __objc_uninstalled_dtable;

	class_table_insert(newClass);
}

#define NEW_CLASS(super, sub) \
	createNSBlockSubclass(super, sub, &sub ## Meta, #sub)

BOOL objc_create_block_classes_as_subclasses_of(Class super)
{
	DEBUG_LOG("Initialize block classes!");

	NEW_CLASS(super, _NSBlock);
	class_addMethod(_NSBlock, sel_registerName("release"), (IMP)&_NSBlockRelease, "v@:");
	class_addMethod(_NSBlock, sel_registerName("retain"), (IMP)&_NSBlockRetain, "@@:");
	class_addMethod(_NSBlock, sel_registerName("copy"), (IMP)&_NSBlockCopyNoZone, "@@:");
	class_addMethod(_NSBlock, sel_registerName("copyWithZone:"), (IMP)&_NSBlockCopy, "@@0:^{_NSZone=^?^?^?^?^?^?^?I@^{_NSZone}}");

	NEW_CLASS(_NSBlock, _NSConcreteStackBlock);
	NEW_CLASS(_NSBlock, _NSConcreteMallocBlock);
	NEW_CLASS(_NSBlock, _NSConcreteAutoBlock);
	NEW_CLASS(_NSBlock, _NSConcreteFinalizingBlock);
	NEW_CLASS(_NSBlock, _NSConcreteGlobalBlock);

	return YES;
}
