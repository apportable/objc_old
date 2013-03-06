#import <Block.h>
#import <objc/runtime.h>

@class NSString;
@class NSMethodSignature;
#ifdef __LP64__
typedef unsigned long NSUInteger;
#else
typedef unsigned int NSUInteger;
#endif
typedef struct _NSZone NSZone;


@protocol NSObject

- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;

- (Class)superclass;
- (Class)class;
- (id)self;
- (NSZone *)zone;

- (id)performSelector:(SEL)aSelector;
- (id)performSelector:(SEL)aSelector withObject:(id)object;
- (id)performSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;

- (BOOL)isProxy;

- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;

- (BOOL)respondsToSelector:(SEL)aSelector;

- (id)retain;
- (oneway void)release;
- (id)autorelease;
- (NSUInteger)retainCount;

- (NSString *)description;
- (NSString *)debugDescription;

@end

@interface NSObject <NSObject>
{
    Class isa;
}
@end

extern void *_NSConcreteStackBlock[32] __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteStackBlock"), visibility("default")));
extern void *_NSConcreteMallocBlock[32] __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteMallocBlock"), visibility("default")));
extern void *_NSConcreteAutoBlock[32] __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteAutoBlock"), visibility("default")));
extern void *_NSConcreteFinalizingBlock[32] __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteFinalizingBlock"), visibility("default")));
extern void *_NSConcreteGlobalBlock[32] __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteGlobalBlock"), visibility("default")));
extern void *_NSConcreteWeakBlockVariable[32] __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteWeakBlockVariable"), visibility("default")));

@interface NSBlock : NSObject
@end

@implementation NSBlock

- (id)retain
{
    return Block_copy(self);
}

- (id)copy
{
    return Block_copy(self);
}

- (oneway void)release
{
    Block_release(self);
}

@end

@interface NSConcreteStackBlock : NSBlock
@end

@implementation NSConcreteStackBlock
@end

@interface NSConcreteMallocBlock : NSBlock
@end

@implementation NSConcreteMallocBlock
@end

@interface NSConcreteAutoBlock : NSBlock
@end

@implementation NSConcreteAutoBlock
@end

@interface NSConcreteFinalizingBlock : NSBlock
@end

@implementation NSConcreteFinalizingBlock
@end

@interface NSConcreteGlobalBlock : NSBlock
@end

@implementation NSConcreteGlobalBlock
@end

@interface NSConcreteWeakBlockVariable : NSBlock
@end

@implementation NSConcreteWeakBlockVariable
@end
