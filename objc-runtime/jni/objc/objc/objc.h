#include <objc/runtime.h>

#if !__has_feature(objc_arr)
#define __weak
#define __strong
#define __unsafe_unretained
#define __autoreleasing
#endif
