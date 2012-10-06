flags = [

]

defines = {
    'MAP_TABLE_SINGLE_THREAD' : 1,
    'MAP_TABLE_NO_LOCK' : 1,
    'VERDE_USE_REAL_ASSERT' : 1,
    'MOZ_MEMORY' : 1,
    'MOZ_MEMORY_ANDROID' : 1,
    'MOZ_MEMORY_LINUX' : 1,
}

header_paths = [
    'System/objc/objc-runtime/jni/objc/jemalloc'
]

deps = [

]

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
    'objc-runtime/jni/objc/unwind_stubs.m',
    'objc-runtime/jni/objc/jemalloc/jemalloc.c',
    'objc-runtime/jni/objc/jemalloc/extra_malloc.c',
    {'source' : 'objc-runtime/jni/objc/extra/ffs.c', 'env' : {'TARGET_ARCH' : 'x86', 'TARGET_OS' : 'android'}},
    {'source' : 'objc-runtime/jni/objc/extra/atexit.c', 'env' : {'TARGET_ARCH' : 'x86', 'TARGET_OS' : 'android'}},
]

Import('env')
BuildLibrary(env, sources = sources, header_paths = header_paths, static=False, defines = defines, flags = flags, deps = deps)
