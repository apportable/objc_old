#include <objc/runtime.h>

@class NSString, NSMethodSignature;

#ifdef __LP64__
typedef unsigned long NSUInteger;
#else
typedef unsigned int NSUInteger;
#endif

struct _NSZone
{
  /* Functions for zone. */
  void *(*malloc)(struct _NSZone *zone, size_t size);
  void *(*realloc)(struct _NSZone *zone, void *ptr, size_t size);
  void (*free)(struct _NSZone *zone, void *ptr);
  void (*recycle)(struct _NSZone *zone);
  BOOL (*check)(struct _NSZone *zone);
  BOOL (*lookup)(struct _NSZone *zone, void *ptr);
  struct NSZoneStats (*stats)(struct _NSZone *zone);
  
  size_t gran; // Zone granularity
#if defined(__has_feature) && __has_feature(objc_arc)
  void *name;
  void *next;
#else
  NSString *name; // Name of zone (default is 'nil')
  struct _NSZone *next;
#endif
};

typedef struct _NSZone NSZone;

@interface NSInvocation
- (SEL)selector;
@end

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

__attribute__((objc_root_class)) @interface NSObject <NSObject>
{
    Class isa;
}
@end
