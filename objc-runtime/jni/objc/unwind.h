#ifndef _UNWIND_H_
#define _UNWIND_H_

#ifdef __arm__
#include "unwind-arm.h"
#else
#include "unwind-itanium.h"
#endif

#endif