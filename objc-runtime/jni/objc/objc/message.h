#include <objc/objc.h>
#include <objc/runtime.h>


#ifndef __LIBOBJC_MESSAGE_H_INCLUDED__
#define __LIBOBJC_MESSAGE_H_INCLUDED__

#ifdef __cplusplus
extern "C" {
#endif

// These are Clang built-in's
id objc_msgSend(id self, SEL op, ...);
id objc_msgSend_stret(id self, SEL op, ...);

#ifdef __cplusplus
}
#endif


#endif //__LIBOBJC_MESSAGE_H_INCLUDED__
