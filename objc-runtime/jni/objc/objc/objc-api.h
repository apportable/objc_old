/*
 * Portions of this file is obtained from the Apple objc-runtime
 *
 * Copyright (c) 1999-2006 Apple Inc.  All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
// Copyright 1988-1996 NeXT Software, Inc.

#ifndef _OBJC_OBJC_API_H_
#define _OBJC_OBJC_API_H_

#include <objc/runtime.h>

#ifndef __has_feature
#   define __has_feature(x) 0
#endif

#ifndef __has_extension
#   define __has_extension __has_feature
#endif

/* OBJC_ARC_UNAVAILABLE: unavailable with -fobjc-arc */
#if !defined(OBJC_ARC_UNAVAILABLE)
#   if __has_feature(objc_arr)
#       if __has_extension(attribute_unavailable_with_message)
#           define OBJC_ARC_UNAVAILABLE __attribute__((unavailable("not available in automatic reference counting mode")))
#       else
#           define OBJC_ARC_UNAVAILABLE __attribute__((unavailable))
#       endif
#   else
#       define OBJC_ARC_UNAVAILABLE
#   endif
#endif


#if !defined(OBJC_EXTERN)
#   if defined(__cplusplus)
#       define OBJC_EXTERN extern "C" 
#   else
#       define OBJC_EXTERN extern
#   endif
#endif

#if !defined(OBJC_VISIBLE)
#   if TARGET_OS_WIN32
#       if defined(BUILDING_OBJC)
#           define OBJC_VISIBLE __declspec(dllexport)
#       else
#           define OBJC_VISIBLE __declspec(dllimport)
#       endif
#   else
#       define OBJC_VISIBLE  __attribute__((visibility("default")))
#   endif
#endif

#if !defined(OBJC_EXPORT)
#   define OBJC_EXPORT  OBJC_EXTERN OBJC_VISIBLE
#endif

#if !defined(OBJC_IMPORT)
#   define OBJC_IMPORT extern
#endif

#ifndef __DARWIN_NULL
#define __DARWIN_NULL NULL
#endif

#if !defined(OBJC_INLINE)
#   define OBJC_INLINE inline
#endif

#endif /*_OBJC_OBJC_API_H_*/