/*
 * Debug Macros for the objc-runtime
 *
 * Marc Salem, Jan 2012
 * Copyright Apportable Inc.
 */

#ifndef _OBJC_DEBUG_H_
#define _OBJC_DEBUG_H_

#ifdef ANDROID
#include <android/log.h>
#endif

#if !defined(DEBUG_LOG)
#if !defined(NDEBUG) && defined(ANDROID)
#include <android/log.h>
#define DEBUG_LOG__(file, line, format, ...) \
    __android_log_print(ANDROID_LOG_INFO, "CoreFoundation", file " %s " #line ": " format "%s", __FUNCTION__, ##__VA_ARGS__);
#define DEBUG_LOG_(file, line, format, ...) DEBUG_LOG__(file, line, format, __VA_ARGS__)
#define DEBUG_LOG(format, ...) DEBUG_LOG_(__FILE__, __LINE__, format, ##__VA_ARGS__, "")
#else
#define  DEBUG_LOG(...)
#endif
#endif

#define RELEASE_LOG(format, ...) \
    __android_log_print(ANDROID_LOG_WARN, "objc", \
        "%s:%d: %s(): " format, \
        __FILE__, __LINE__, __FUNCTION__, ##__VA_ARGS__)

#if !defined(DEBUG_BREAK)
#if !defined(NDEBUG) && defined(ANDROID)
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
