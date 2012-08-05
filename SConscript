import os
Import('env')

deps = []

sources = [
    'objc-runtime/jni/objc/Protocol2.m',
    'objc-runtime/jni/objc/abi_version.c',
    'objc-runtime/jni/objc/caps.c',
    'objc-runtime/jni/objc/category_loader.c',
    'objc-runtime/jni/objc/class_table.c',
    'objc-runtime/jni/objc/dtable.c',
    'objc-runtime/jni/objc/eh_personality.c',
    'objc-runtime/jni/objc/encoding2.c',
    'objc-runtime/jni/objc/hooks.c',
    'objc-runtime/jni/objc/ivar.c',
    'objc-runtime/jni/objc/legacy_malloc.c',
    'objc-runtime/jni/objc/loader.c',
    'objc-runtime/jni/objc/mutation.m',
    'objc-runtime/jni/objc/properties.m',
    'objc-runtime/jni/objc/protocol.c',
    'objc-runtime/jni/objc/runtime.c',
    'objc-runtime/jni/objc/sarray2.c',
    'objc-runtime/jni/objc/selector_table.c',
    'objc-runtime/jni/objc/sendmsg2.c',
    'objc-runtime/jni/objc/statics_loader.c',
    'objc-runtime/jni/objc/sync.m',
    'objc-runtime/jni/objc/associations.m',
    'objc-runtime/jni/objc/NSBlocks.m',
    'objc-runtime/jni/objc/blocks/runtime.c',
    'objc-runtime/jni/objc/blocks/data.c',
    'objc-runtime/jni/objc/ill_object.c',
]

BuildLibrary(env, sources)
Return('deps')
