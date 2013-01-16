flags = [
    '-frtti'
]

defines = {
    'TYPE_DEPENDENT_DISPATCH' : 1,
    'GNUSTEP' : 1,
    '_XOPEN_SOURCE' : 500,
    '__OBJC_RUNTIME_INTERNAL__' : 1,
    'MAP_TABLE_NO_LOCK' : 1,
    'MAP_TABLE_SINGLE_THREAD' : 1,
    'HAVE_GCC_VISIBILITY' : 1,
    'VERDE_USE_REAL_ASSERT' : 1,
    'MOZ_MEMORY' : 1,
    'MOZ_MEMORY_ANDROID' : 1,
    'MOZ_MEMORY_LINUX' : 1,
}

header_paths = [
    'System/objc/objc-runtime/jni/objc/jemalloc'
]

deps = [
    'v'
]

sources = [
    'objc-runtime/jni/objc/abi_version.c',
    'objc-runtime/jni/objc/alias_table.c',
    # 'objc-runtime/jni/objc/NSObject.m',
    'objc-runtime/jni/objc/objc-weak.c',
    'objc-runtime/jni/objc/objc-tls.c',
    'objc-runtime/jni/objc/objc-arr.m',
    'objc-runtime/jni/objc/associate.m',
    'objc-runtime/jni/objc/blocks/data.c',
    'objc-runtime/jni/objc/blocks/runtime.c',
    'objc-runtime/jni/objc/caps.c',
    'objc-runtime/jni/objc/category_loader.c',
    'objc-runtime/jni/objc/class_table.c',
    'objc-runtime/jni/objc/dtable.c',
    'objc-runtime/jni/objc/eh_personality.c',
    'objc-runtime/jni/objc/encoding2.c',
    'objc-runtime/jni/objc/gc_none.c',
    'objc-runtime/jni/objc/hash_table.c',
    'objc-runtime/jni/objc/hooks.c',
    'objc-runtime/jni/objc/ivar.c',
    'objc-runtime/jni/objc/legacy_malloc.c',
    'objc-runtime/jni/objc/loader.c',
    'objc-runtime/jni/objc/mutation.m',
    'objc-runtime/jni/objc/NSBlocks.m',
    'objc-runtime/jni/objc/properties.m',
    'objc-runtime/jni/objc/protocol.c',
    'objc-runtime/jni/objc/Protocol2.m',
    'objc-runtime/jni/objc/runtime.c',
    'objc-runtime/jni/objc/sarray2.c',
    'objc-runtime/jni/objc/selector_table.c',
    'objc-runtime/jni/objc/sendmsg2.c',
    'objc-runtime/jni/objc/statics_loader.c',
    'objc-runtime/jni/objc/objc-properties.m',
    'objc-runtime/jni/objc/objcxx_eh.cc',
    'objc-runtime/jni/objc/sync.m',
    {'source' : 'objc-runtime/jni/objc/objc_msgSend.arm.S', 'env' : {'TARGET_ARCH' : 'arm'}, "flags":"-mno-thumb"},
    # {'source' : 'objc-runtime/jni/objc/objc_msgSend.x86-32.S', 'env' : {'TARGET_ARCH' : 'x86'}},
]

libs = [
    'gnustl_shared',
    'v'
]

Import('env')
env.BuildLibrary(sources = sources, header_paths = header_paths, static=False, defines = defines, flags = flags, deps = deps, libs=libs)