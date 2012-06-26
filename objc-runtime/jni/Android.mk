LOCAL_PATH := $(call my-dir)

# Build Objective-C Runtime
include $(CLEAR_VARS)
TARGET_ARCH_ABI  ?= armeabi-7a
BUILD            ?= release
TARGET_OS        := android
HOST_OS          ?= Darwin
FRONTEND         ?= clang
CLANG_VERSION    ?= 3.1
ROOTDIR          ?= $(LOCAL_PATH)
MODULE           := objc
MODULE_DST       := obj/local/$(TARGET_ARCH_ABI)/objs/objc
ifeq ("$(BINDIR)","")
    BINDIR       := $(abspath $(ROOTDIR)/../obj/local/$(TARGET_ARCH_ABI)/objs/ )
else
    BINDIR       := $(abspath $(BINDIR) )
endif
ANDROID_NDK_ROOT :=/Developer/DestinyCloudFist/crystax-ndk-r7
ANDROID_SDK_ROOT :=/Developer/DestinyCloudFist/android-sdk-mac_x86
TRACK_OBJC_ALLOCATIONS ?= no
EFENCE ?= no

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
                    -DMAP_TABLE_SINGLE_THREAD \

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
                    -fobjc-nonfragile-abi-version=2 \
                    -DHAVE_GCC_VISIBILITY \
                    -g \
                    -fpic \
                    -ffunction-sections \
                    -funwind-tables \
                    -fstack-protector \
                    -fno-short-enums \
                    -D__ANDROID__  \
                    -DAPPORTABLE \

ifeq ($(TARGET_ARCH_ABI),x86)
LOCAL_CFLAGS    +=  \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-14/arch-x86/usr/include/ \
                    -nostdinc \
                    -I/$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/lib/gcc/i686-android-linux/4.4.3/include/ \

else
LOCAL_CFLAGS    +=  \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm/usr/include/ \
                    -nostdinc \
                    -I/$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/lib/gcc/arm-linux-androideabi/4.4.3/include/ \

endif


ifeq ($(TRACK_OBJC_ALLOCATIONS),yes)
  LOCAL_CFLAGS += \
    -DTRACK_OBJC_ALLOCATIONS=1 \

endif


ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
  LOCAL_CFLAGS += \
      -mfloat-abi=softfp
      -march=armv7-a \
      -mfpu=vfp \

  MODULE_ASFLAGS += \
      -mfloat-abi=softfp
      -march=armv7-a  \

else
  ifeq ($(TARGET_ARCH_ABI),x86)
    COMMON_CCFLAGS += \
        -march=i386 \

  else
    COMMON_CCFLAGS += \
        -D__ARM_ARCH_5__ \
        -D__ARM__ \
        -march=armv5 \
        -msoft-float \

  endif

endif


LOCAL_SRC_FILES :=  \
                    Protocol2.o \
                    abi_version.o \
                    caps.o \
                    category_loader.o \
                    class_table.o \
                    dtable.o \
                    eh_personality.o \
                    encoding2.o \
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
                    associations.o \
                    NSBlocks.o \
                    blocks/runtime.o \
                    blocks/data.o \

ifeq ($(EFENCE),yes)
LOCAL_SRC_FILES += \
                    efence.o \
                    page.o \
                    print.o \

endif

# libunwind stubs
LOCAL_SRC_FILES += unwind_stubs.o

OBJECTS:=$(LOCAL_SRC_FILES)

CXX_SYSTEM = -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/include/4.4.3/ \
             -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/libs/$(TARGET_ARCH_ABI)/4.4.3/include/ \
             -isystem $(ANDROID_NDK_ROOT)/sources/crystax/include \

ifeq ($(TARGET_ARCH_ABI),x86)
  CCLD=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-g++ --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/arch-x86

  CC= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-x86 $(CXX_SYSTEM) -ccc-host-triple i686-android-linux -march=i386 -D__compiler_offsetof=__builtin_offsetof
  CPP= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-x86 $(CXX_SYSTEM)

  CCAS=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-gcc
  AS=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-as
  LDR=
  AR=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-ar

else
  CCLD=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-g++ --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/arch-arm

  CC= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm $(CXX_SYSTEM) -ccc-host-triple arm-android-eabi -march=armv5 -D__compiler_offsetof=__builtin_offsetof
  CPP= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm $(CXX_SYSTEM)

  CCAS=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-gcc
  AS=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-as
  LDR=
  AR=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-ar
  
endif

OBJDIR = $(BINDIR)/$(MODULE_DST)
# OUTPUT_OBJECTS = ${OBJECTS:%=$(OBJDIR)/%}

MODULE_CFLAGS := $(COMMON_CFLAGS) $(CFLAGS) $(LOCAL_CFLAGS) 
MODULE_CCFLAGS := $(COMMON_CCFLAGS) $(CCFLAGS) $(LOCAL_CFLAGS) 
MODULE_ASFLAGS := $(COMMON_ASFLAGS) $(ASFLAGS) $(LOCAL_ASFLAGS) 
MODULE_OBJCFLAGS := $(COMMON_OBJCFLAGS) $(LOCAL_OBJCFLAGS)

# pull in dependency info for *existing* .o files
-include $(subst .o,.out.d,$(shell find $(OBJDIR) -name "*.o" ))

.SECONDARY: ;

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.mm .SECONDARY
	@echo Compiling .mm $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.cc .SECONDARY
	@echo Compiling .cc $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ -x objective-c++ -fblocks $(MODULE_CCFLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.cpp .SECONDARY
	@echo Compiling .cpp $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ -x objective-c++ -fblocks $(MODULE_CCFLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.c .SECONDARY
	@echo Compiling .c $<
	mkdir -p $(dir $@)
	$(CC) -MD -MT $@ $(MODULE_CFLAGS) -fblocks $(MODULE_CCFLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.m .SECONDARY
	@echo Compiling .m $<
	mkdir -p $(dir $@)
	$(CC) -MD -MT $@ $(MODULE_CFLAGS) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.fixed.s: $(OBJDIR)/%.out.s .SECONDARY
	@echo fixing $<
	@perl fixup_assembly.pl < $< > $@

$(OBJDIR)/%.o: $(OBJDIR)/%.fixed.s
	@echo assembling $<
	@$(CCAS) $(MODULE_ASFLAGS) -c $< -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.s
	@echo Assembling $<
	mkdir -p $(dir $@)
	@$(CC) $(MODULE_ASFLAGS) -c $< -o $@


include $(BUILD_SHARED_LIBRARY)


