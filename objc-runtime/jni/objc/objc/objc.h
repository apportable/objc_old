#ifndef _OBJC_OBJC_H_
#define _OBJC_OBJC_H_

#include <objc/objc-api.h>

/**
 * Opaque type used for selectors.
 */
#if !defined(__clang__) && !defined(__OBJC_RUNTIME_INTERNAL__)
typedef const struct objc_selector *SEL;
#else
typedef struct objc_selector *SEL;
#endif

/**
 * Opaque type for Objective-C classes.
 */
typedef struct objc_class *Class;

/**
 * Type for Objective-C objects.
 */
typedef struct objc_object
{
    /**
     * Pointer to this object's class.  Accessing this directly is STRONGLY
     * discouraged.  You are recommended to use object_getClass() instead.
     */
#ifndef __OBJC_RUNTIME_INTERNAL__
    __attribute__((deprecated))
#endif
    Class isa;
} *id;

typedef const void* objc_objectptr_t;

#if __has_feature(objc_arc)

#define objc_retainedObject(o) ((__bridge_transfer id)(objc_objectptr_t)(o))
#define objc_unretainedObject(o) ((__bridge id)(objc_objectptr_t)(o))
#define objc_unretainedPointer(o) ((__bridge objc_objectptr_t)(id)(o))

#else

#define __bridge
#define __bridge_retained
#define __bridge_transfer
#define __autoreleasing
#define __strong
#define __unsafe_unretained
#define __weak

#define objc_retainedObject(o) ((id)(objc_objectptr_t)(o))
#define objc_unretainedObject(o) ((id)(objc_objectptr_t)(o))
#define objc_unretainedPointer(o) ((objc_objectptr_t)(id)(o))

#endif

typedef signed char BOOL;

#if __has_feature(objc_bool)
#define YES             __objc_yes
#define NO              __objc_no
#else
#define YES             ((BOOL)1)
#define NO              ((BOOL)0)
#endif

#ifndef Nil
# if __has_feature(cxx_nullptr)
#   define Nil nullptr
# elif __cplusplus
#   define Nil 0
# else
#   define Nil ((void *)0)
# endif
#endif

#ifndef nil
# if __has_feature(cxx_nullptr)
#   define nil nullptr
# elif __cplusplus
#   define nil 0
# else
#   define nil ((void *)0)
# endif
#endif

#endif /*_OBJC_OBJC_H_*/