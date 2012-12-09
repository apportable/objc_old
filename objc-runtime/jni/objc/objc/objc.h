#ifndef _OBJC_OBJC_H_
#define _OBJC_OBJC_H_

#include <objc/objc-api.h>

#if !__has_feature(objc_arc)
  #define __bridge
  #define __bridge_retained
  #define __bridge_transfer
  #define __autoreleasing
  #define __strong
  #define __unsafe_unretained
  #define __weak
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