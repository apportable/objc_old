LOCAL_PATH := $(call my-dir)

ANALYZE          ?= no
ANALYZE_OUTPUT   ?=/dev/null

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

ifeq ($(ANDROID_NDK_R8B),yes)
ANDROID_NDK_ROOT ?=/Developer/DestinyCloudFist/android-ndk-r8b
ifeq ($(TARGET_ARCH_ABI),armeabi-7a)
TARGET_TRIPLE 	 := arm-linux-androideabi
ANDROID_ARCH_DIR := arch-arm
GCC_INC_DIR		 := arm-linux-androideabi/4.6.x-google/include
GCC_LIB_DIR 	 := arm-linux-androideabi/4.6.x-google/armv7-a
ARCH_FLAGS 		 := -ccc-host-triple arm-android-eabi-v7a -march=armv7-a
else 
ifeq ($(TARGET_ARCH_ABI),armeabi)
TARGET_TRIPLE 	 := arm-linux-androideabi
ANDROID_ARCH_DIR := arch-arm
GCC_INC_DIR 	 := arm-linux-androideabi/4.6.x-google/include
GCC_LIB_DIR 	 := arm-linux-androideabi/4.6.x-google
ARCH_FLAGS 		 := -ccc-host-triple arm-android-eabi -march=armv5
else
TARGET_TRIPLE 	 := i686-linux-android
ANDROID_ARCH_DIR := arch-x86
GCC_INC_DIR 	 := i686-linux-android/4.6.x-google/include
GCC_LIB_DIR 	 := i686-linux-android/4.6.x-google
ARCH_FLAGS 		 := -ccc-host-triple i686-android-linux -march=i686
endif
endif
LIBCPP_VERSION 	 ?= /4.6
TOOLCHAIN_TARGET_VERSION ?= arm-linux-androideabi-4.6
LEGACY_GCC_VERSION := 
else
ANDROID_NDK_ROOT :=/Developer/DestinyCloudFist/android-ndk-r8
ifeq ($(TARGET_ARCH_ABI),armeabi-7a)
TARGET_TRIPLE 	 := arm-linux-androideabi
ANDROID_ARCH_DIR := arch-arm
GCC_INC_DIR		 := arm-linux-androideabi/4.4.3/include
GCC_LIB_DIR		 := arm-linux-androideabi/4.4.3/armv7-a
ARCH_FLAGS 		 := -ccc-host-triple arm-android-eabi-v7a -march=armv7-a
else
TARGET_TRIPLE 	 := arm-linux-androideabi
ANDROID_ARCH_DIR := arch-arm
GCC_INC_DIR		 := arm-linux-androideabi/4.4.3/include
GCC_LIB_DIR 	 := arm-linux-androideabi/4.4.3
ARCH_FLAGS 		 := -ccc-host-triple arm-android-eabi -march=armv5
endif
LIBCPP_VERSION :=
TOOLCHAIN_TARGET_VERSION := arm-linux-androideabi-4.4.3
LEGACY_GCC_VERSION := /4.4.3
endif
ANDROID_SDK_ROOT :=/Developer/DestinyCloudFist/android-sdk-mac_x86

TRACK_OBJC_ALLOCATIONS ?= no
EFENCE ?= no

LOCAL_ASFLAGS   := -shared -Wl,-Bsymbolic 
LOCAL_LDLIBS    := -llog -L$(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++$(LIBCPP_VERSION)/libs/$(TARGET_ARCH_ABI)/ -lgnustl_shared
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

ifeq ($(CHECK_ILL_OBJECTS), yes)
LOCAL_CFLAGS += -DCHECK_ILL_OBJECTS
endif

LOCAL_OBJCFLAGS += -ferror-limit=5 -fblocks -DNS_BLOCKS_AVAILABLE \
                   -ObjC \
                   -fobjc-abi-version=3 \
                   -fgnu-runtime


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
                    -DHAVE_GCC_VISIBILITY \
                    -g \
                    -fpic \
                    -ffunction-sections \
                    -funwind-tables \
                    -fstack-protector \
                    -fno-short-enums \
                    -D__ANDROID__  \
                    -DAPPORTABLE \


LOCAL_CFLAGS    +=  \
                    -nostdinc \
                    -isystem $(ANDROID_NDK_ROOT)/toolchains/$(TOOLCHAIN_TARGET_VERSION)/prebuilt/$(HOST_OS)-$(HOST_ARCH)/lib/gcc/$(GCC_INC_DIR) \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/$(ANDROID_ARCH_DIR)/usr/include/ \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/$(ANDROID_ARCH_DIR)/usr/include/linux/ \


ifeq ($(TRACK_OBJC_ALLOCATIONS),yes)
  LOCAL_CFLAGS += \
    -DTRACK_OBJC_ALLOCATIONS=1 \

endif


ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
  LOCAL_CFLAGS += \
      -mfloat-abi=softfp
      -march=armv7-a \
      -mfpu=neon \

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
                    ill_object.o \

ifeq ($(EFENCE),yes)
LOCAL_SRC_FILES += \
                    efence.o \
                    page.o \
                    print.o \

endif

ifeq ($(TRACK_OBJC_ALLOCATIONS),yes)
LOCAL_SRC_FILES += track.o

endif

# libunwind stubs
LOCAL_SRC_FILES += unwind_stubs.o

OBJECTS:=$(LOCAL_SRC_FILES)

CXX_SYSTEM = -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++$(LIBCPP_VERSION)/include/ \
             -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++$(LIBCPP_VERSION)/libs/$(TARGET_ARCH_ABI)/include/ \

CCLD=$(ANDROID_NDK_ROOT)/toolchains/$(TOOLCHAIN_TARGET_VERSION)/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/$(TARGET_TRIPLE)-g++ --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/$(ANDROID_ARCH_DIR)

CC= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/$(ANDROID_ARCH_DIR) $(CXX_SYSTEM) $(ARCH_FLAGS) -D__compiler_offsetof=__builtin_offsetof
CPP= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/$(ANDROID_ARCH_DIR) $(CXX_SYSTEM)

CCAS=$(ANDROID_NDK_ROOT)/toolchains/$(TOOLCHAIN_TARGET_VERSION)/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/$(TARGET_TRIPLE)-gcc
AS=$(ANDROID_NDK_ROOT)/toolchains/$(TOOLCHAIN_TARGET_VERSION)/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/$(TARGET_TRIPLE)-as
LDR=
AR=$(ANDROID_NDK_ROOT)/toolchains/$(TOOLCHAIN_TARGET_VERSION)/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/$(TARGET_TRIPLE)-ar

OBJDIR = $(BINDIR)/$(MODULE_DST)
# OUTPUT_OBJECTS = ${OBJECTS:%=$(OBJDIR)/%}

MODULE_CFLAGS := $(COMMON_CFLAGS) $(CFLAGS) $(LOCAL_CFLAGS) 
MODULE_CCFLAGS := $(COMMON_CCFLAGS) $(CCFLAGS) $(LOCAL_CFLAGS) 
MODULE_ASFLAGS := $(COMMON_ASFLAGS) $(ASFLAGS) $(LOCAL_ASFLAGS) 
MODULE_OBJCFLAGS := $(COMMON_OBJCFLAGS) $(LOCAL_OBJCFLAGS)

# pull in dependency info for *existing* .o files
-include $(subst .o,.out.d,$(shell find $(OBJDIR) -name "*.o" ))

.SECONDARY: ;

DEBUG_LOGGING_FLAGS ?= -DDEBUG_LOG\(...\)=do\{\}while\(0\)\; -DDEBUG_BREAK\(\)=do\{\}while\(0\)\; -DRELEASE_LOG\(...\)=do\{\}while\(0\);

ifneq ("$(ANALYZE)", "yes")
# Start Compile Rules

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.mm .SECONDARY
	@echo Compiling .mm $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.cc .SECONDARY
	@echo Compiling .cc $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ -x objective-c++ -fblocks $(MODULE_CCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.cpp .SECONDARY
	@echo Compiling .cpp $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ -x objective-c++ -fblocks $(MODULE_CCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.c .SECONDARY
	@echo Compiling .c $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ $(MODULE_CFLAGS) -fblocks $(MODULE_CCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

$(OBJDIR)/%.out.s: $(ROOTDIR)/$(MODULE)/%.m .SECONDARY
	@echo Compiling .m $<
	@mkdir -p $(dir $@)
	@$(CC) -MD -MT $@ $(MODULE_CFLAGS) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S $< -o $@

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


# End Compile Rules
else
# Start Analyze Rules

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.mm
  @echo Analyzing $<
  @mkdir -p $(dir $@)
  @$(CC) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S --analyze $< -o /dev/null 2>> $(ANALYZE_OUTPUT)

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.cc
  @echo Analyzing $<
  @mkdir -p $(dir $@)
  @$(CC) -x objective-c++ -fblocks $(MODULE_CCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S --analyze $< -o /dev/null 2>> $(ANALYZE_OUTPUT)

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.cpp
  @echo Analyzing $<
  @mkdir -p $(dir $@)
  @$(CC) -x objective-c++ -fblocks $(MODULE_CCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S --analyze $< -o /dev/null 2>> $(ANALYZE_OUTPUT)

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.c
  @echo Analyzing $<
  @mkdir -p $(dir $@)
  @$(CC) $(MODULE_CFLAGS) -fblocks $(MODULE_CCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S --analyze $< -o /dev/null 2>> $(ANALYZE_OUTPUT)

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.m
  @echo Analyzing $<
  @mkdir -p $(dir $@)
  @$(CC) $(MODULE_CFLAGS) $(MODULE_CCFLAGS) $(MODULE_OBJCFLAGS) $(DEBUG_LOGGING_FLAGS) -D__REAL_BASE_FILE__="\"$<\"" $(DEP_DEFS) -S --analyze $< -o /dev/null 2>> $(ANALYZE_OUTPUT)

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.s
  @echo Skipping analysis $<

# End Analyze Rules
endif

include $(BUILD_SHARED_LIBRARY)


