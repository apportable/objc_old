/*
 * Debug Macros for the objc-runtime
 *
 * Marc Salem, Jan 2012
 * Copyright Apportable Inc.
 */

#ifndef _OBJC_DEBUG_H_
#define _OBJC_DEBUG_H_

#if !defined(DEBUG_LOG)
#if !defined(NDEBUG) && defined(ANDROID)
#include <android/log.h>
#define  DEBUG_LOG(...) __android_log_print(ANDROID_LOG_INFO,"objc",__VA_ARGS__)
#else
#define  DEBUG_LOG(...)
#endif
#endif

#if !defined(DEBUG_BREAK)
#if !defined(NDEBUG) && defined(ANDROID)
#include <android/log.h>
#define DEBUG_BREAK() { ((void)__android_log_print(ANDROID_LOG_WARN, "objc", \
                            "DEBUG_BREAK: Hit breakpoint at %s:%d",          \
                            __FILE__, __LINE__));                            \
                            int *debug_break_crash_var = 0;                  \
                            *debug_break_crash_var = 42;                     \
                      }
#else
#define DEBUG_BREAK(...)
#endif
#endif

#endif