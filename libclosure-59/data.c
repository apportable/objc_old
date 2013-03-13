
extern void *_NSConcreteStackBlock_s __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteStackBlock"), visibility("default")));
extern void *_NSConcreteMallocBlock_s __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteMallocBlock"), visibility("default")));
extern void *_NSConcreteAutoBlock_s __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteAutoBlock"), visibility("default")));
extern void *_NSConcreteFinalizingBlock_s __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteFinalizingBlock"), visibility("default")));
extern void *_NSConcreteGlobalBlock_s __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteGlobalBlock"), visibility("default")));
extern void *_NSConcreteWeakBlockVariable_s __attribute__((weak, alias ("OBJC_CLASS_$_NSConcreteWeakBlockVariable"), visibility("default")));

void *const*_NSConcreteStackBlock = &_NSConcreteStackBlock_s;
void *const*_NSConcreteMallocBlock = &_NSConcreteMallocBlock_s;
void *const*_NSConcreteAutoBlock = &_NSConcreteAutoBlock_s;
void *const*_NSConcreteFinalizingBlock = &_NSConcreteFinalizingBlock_s;
void *const*_NSConcreteGlobalBlock = &_NSConcreteGlobalBlock_s;
void *const*_NSConcreteWeakBlockVariable = &_NSConcreteWeakBlockVariable_s;
