LOCAL_PATH := $(call my-dir)

# Build Objective-C Runtime
include $(CLEAR_VARS)
TARGET_ARCH_ABI       ?= armeabi-7a
BUILD            ?= release
TARGET_OS        := android
HOST_OS          ?= Darwin
FRONTEND         ?= clang
CLANG_VERSION    ?= 3.1
ROOTDIR          := $(LOCAL_PATH)
MODULE           := objc
BINDIR           := $(abspath $(ROOTDIR)/../obj/local/$(TARGET_ARCH_ABI)/objs/ )
ANDROID_NDK_ROOT :=/Developer/DestinyCloudFist/crystax-ndk-r7
ANDROID_SDK_ROOT :=/Developer/DestinyCloudFist/android-sdk-mac_x86

LOCAL_ASFLAGS   := -shared -Wl,-Bsymbolic 
LOCAL_LDLIBS    := -llog -L$(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/libs/$(TARGET_ARCH_ABI)/4.4.3/ -lgnustl_shared
LOCAL_LDLIBS    += -Wl,--build-id
LOCAL_MODULE    := objc
#LOCAL_ARM_MODE  := arm
LOCAL_CFLAGS    +=  \
                    -Werror-return-type \
                    -DTYPE_DEPENDENT_DISPATCH \
                    -DGNUSTEP \
                    -D_XOPEN_SOURCE=500 \
                    -D__OBJC_RUNTIME_INTERNAL__=1 \
                    -fblocks \
                    -DMAP_TABLE_NO_LOCK \
                    -DANDROID \

ifeq ($(BUILD), release)
  LOCAL_CFLAGS += \
    -O2 \
    -DNDEBUG \

endif

LOCAL_OBJCFLAGS += -ferror-limit=5 -fblocks -DNS_BLOCKS_AVAILABLE


LOCAL_CFLAGS    +=  \
                    -Iobjc \
                    -Iobjc/Headers \
                    -Iobjc/Headers/Additions \

LOCAL_CFLAGS    +=  \
                    -DANDROID \
                    -fpic \
                    -ffunction-sections \
                    -funwind-tables \
                    -fstack-protector \
                    -fno-short-enums \
                    -fobjc-nonfragile-abi \
                    -fobjc-nonfragile-abi-version=1 \
                    -DHAVE_GCC_VISIBILITY \
                    -g \
                    -fpic \
                    -ffunction-sections \
                    -funwind-tables \
                    -fstack-protector \
                    -fno-short-enums \
                    -D__ANDROID__  \
                    -DAPPORTABLE \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm/usr/include/ \
                    -nostdinc \
                    -I/$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/lib/gcc/arm-linux-androideabi/4.4.3/include/ \



ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
  LOCAL_CFLAGS += \
      -mfloat-abi=softfp
      -march=armv7-a \
      -mfpu=vfp \

  MODULE_ASFLAGS += \
      -mfloat-abi=softfp
      -march=armv7-a  \

else
  COMMON_CCFLAGS += \
      -D__ARM_ARCH_5__ \
      -march=armv5 \
      -msoft-float \

endif


LOCAL_SRC_FILES :=  \
                    NSBlocks.o \
                    Protocol2.o \
                    abi_version.o \
                    blocks_runtime.o \
                    caps.o \
                    category_loader.o \
                    class_table.o \
                    dtable.o \
                    eh_personality.o \
                    encoding2.o \
                    hash_table.o \
                    hooks.o \
                    ivar.o \
                    legacy_malloc.o \
                    loader.o \
                    mutation.o \
                    properties.o \
                    protocol.o \
                    runtime.o \
                    sarray2.o \
                    selector_table.o \
                    sendmsg2.o \
                    statics_loader.o \
                    sync.o \
                    toydispatch.o \
                    associations.o \


# libunwind stubs
LOCAL_SRC_FILES += unwind_stubs.o

OBJECTS:=$(LOCAL_SRC_FILES)

CXX_SYSTEM = -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/include/4.4.3/ \
             -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/libs/$(TARGET_ARCH_ABI)/4.4.3/include/ \
             -isystem $(ANDROID_NDK_ROOT)/sources/crystax/include \

CCLD=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-g++ --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/arch-arm

CC= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm $(CXX_SYSTEM) -ccc-host-triple arm-android-eabi -march=armv5 -D__compiler_offsetof=__builtin_offsetof
CPP= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm  $(CXX_SYSTEM)

CCAS=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-gcc
AS=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-as
LDR=
AR=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-ar

OBJDIR = $(BINDIR)/$(MODULE)
# OUTPUT_OBJECTS = ${OBJECTS:%=$(OBJDIR)/%}

MODULE_CFLAGS := $(COMMON_CFLAGS) $(CFLAGS) $(LOCAL_CFLAGS) 
MODULE_CCFLAGS := $(COMMON_CCFLAGS) $(CCFLAGS) $(LOCAL_CFLAGS) 
MODULE_ASFLAGS := $(COMMON_ASFLAGS) $(ASFLAGS) $(LOCAL_ASFLAGS) 
MODULE_OBJCFLAGS := $(COMMON_OBJCFLAGS) $(LOCAL_OBJCFLAGS)

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.cc
	@echo ".cc" $<
	@mkdir -p `echo $@ | sed s/[^/]*[.]o$$//`
	$(CC) $(MODULE_CCFLAGS) -S $< -o $@.s
	perl fixup_assembly.pl < $@.s > $@.fixed.s
	$(CCAS) $(MODULE_ASFLAGS) -c $@.fixed.s -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.cpp
	@echo ".cpp" $<
	@mkdir -p `echo $@ | sed s/[^/]*[.]o$$//`
	$(CC) $(MODULE_CCFLAGS) -S $< -o $@.s
	perl fixup_assembly.pl < $@.s > $@.fixed.s
	$(CCAS) $(MODULE_ASFLAGS) -c $@.fixed.s -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.c
	@echo ".c" $<
	@mkdir -p `echo $@ | sed s/[^/]*[.]o$$//`
	$(CC) $(MODULE_CFLAGS) $(MODULE_CCFLAGS) -S $< -o $@.s
	perl fixup_assembly.pl < $@.s > $@.fixed.s
	$(CCAS) $(MODULE_ASFLAGS) -c $@.fixed.s -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.m
	@echo ".m" $<
	@mkdir -p `echo $@ | sed s/[^/]*[.]o$$//`
	$(CC) $(MODULE_CFLAGS) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) -S $< -o $@.s
	perl fixup_assembly.pl < $@.s > $@.fixed.s
	$(CCAS) $(MODULE_ASFLAGS) -c $@.fixed.s -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.mm
	@echo ".mm" $<
	@mkdir -p `echo $@ | sed s/[^/]*[.]o$$//`
	@echo $(CC) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) -S $< -o $@.s
	$(CC) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) -S $< -o $@.s
	perl fixup_assembly.pl < $@.s > $@.fixed.s
	$(CCAS) $(MODULE_ASFLAGS) -c $@.fixed.s -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.s
	@echo $<
	@mkdir -p `echo $@ | sed s/[^/]*[.]o$$//`
	$(CC) $(MODULE_ASFLAGS) -c $< -o $@

# $(MODULE): $(OUTPUT_OBJECTS)

include $(BUILD_SHARED_LIBRARY)


