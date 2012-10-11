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
ANDROID_NDK_ROOT :=/Developer/DestinyCloudFist/android-ndk-r8
ANDROID_SDK_ROOT :=/Developer/DestinyCloudFist/android-sdk-mac_x86
TRACK_OBJC_ALLOCATIONS ?= no
EFENCE ?= no

LOCAL_ASFLAGS   := -shared -Wl,-Bsymbolic 
LOCAL_LDLIBS    := -llog -L$(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/libs/$(TARGET_ARCH_ABI)/ -lgnustl_shared
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

LOCAL_OBJCFLAGS += -ferror-limit=5 -fblocks -DNS_BLOCKS_AVAILABLE


LOCAL_CFLAGS    +=  \
                    -Iobjc \
                    -Iobjc/Headers \
                    -Iobjc/Headers/Additions \
                    -Iobjc/jemalloc \

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
                    -DMOZ_MEMORY \
                    -DMOZ_MEMORY_ANDROID \
                    -DMOZ_MEMORY_LINUX \

#debug malloc
ifneq ($(BUILD), release)
	LOCAL_CFLAGS +=  -DMALLOC_DEBUG
endif

ifeq ($(TARGET_ARCH_ABI),x86)
LOCAL_CFLAGS    +=  \
                    -nostdinc \
                    -isystem $(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/lib/gcc/i686-android-linux/4.4.3/include/ \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-8/$(HOST_OS)-$(HOST_ARCH)/usr/include/ \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-8/$(HOST_OS)-$(HOST_ARCH)/usr/include/linux/ \

else
LOCAL_CFLAGS    +=  \
                    -nostdinc \
                    -isystem $(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/lib/gcc/arm-linux-androideabi/4.4.3/include/ \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm/usr/include/ \
                    -isystem $(ANDROID_NDK_ROOT)/platforms/android-8/arch-arm/usr/include/linux/ \

endif

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
	gc_none.o \
	NSBlocks.o \
	Protocol2.o \
	arc.o \
	alias_table.o \
	abi_version.o \
	associate.o \
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
	objc_msgSend.o \
	properties.o \
	protocol.o \
	runtime.o \
	sarray2.o \
	selector_table.o \
	sendmsg2.o \
	statics_loader.o \
	blocks/runtime.o \
    blocks/data.o \
	toydispatch.o \
	jemalloc/jemalloc.o \
    jemalloc/extra_malloc.o \

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

CXX_SYSTEM = -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/include/ \
             -isystem $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/libs/$(TARGET_ARCH_ABI)/include/ \

LOCAL_LDLIBS += \
	-Wl,--wrap,malloc \
	-Wl,--wrap,memalign \
	-Wl,--wrap,posix_memalign \
	-Wl,--wrap,valloc \
	-Wl,--wrap,calloc \
	-Wl,--wrap,realloc \
	-Wl,--wrap,free \
	-Wl,--wrap,malloc_usable_size \
	-Wl,--wrap,strdup \
	-Wl,--wrap,strndup \
	-Wl,--wrap,_Znwj \
	-Wl,--wrap,_Znaj \
	-Wl,--wrap,_ZdlPv \
	-Wl,--wrap,_ZdaPv \

ifeq ($(TARGET_ARCH_ABI),x86)
  LD=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-g++ --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/arch-x86

  CC= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-x86 $(CXX_SYSTEM) -ccc-host-triple i686-android-linux -march=i386 -D__compiler_offsetof=__builtin_offsetof
  CPP= /Developer/DestinyCloudFist/clang-$(CLANG_VERSION)/bin/clang --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-8/arch-x86 $(CXX_SYSTEM)

  CCAS=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-gcc
  AS=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-as
  LDR=
  AR=$(ANDROID_NDK_ROOT)/toolchains/x86-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/i686-android-linux-ar

else
  LD=$(ANDROID_NDK_ROOT)/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$(HOST_OS)-$(HOST_ARCH)/bin/arm-linux-androideabi-g++ --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-$(ANDROID_API_LEVEL)/arch-arm

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

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.S .SECONARY
	@echo Assembling $<
	mkdir -p $(dir $@)
	@$(CC) $(MODULE_ASFLAGS) -c $< -o $@

$(OBJDIR)/%.fixed.s: $(OBJDIR)/%.out.s .SECONDARY
	@echo fixing $<
	@perl fixup_assembly.pl < $< > $@

$(OBJDIR)/%.o: $(OBJDIR)/%.fixed.s
	@echo assembling $<
	@$(CCAS) $(MODULE_ASFLAGS) -c $< -o $@

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.S
	@echo Assembling $<
	mkdir -p $(dir $@)
	@$(CCAS) $(MODULE_ASFLAGS) -c $< -o $@



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

$(OBJDIR)/%.o: $(ROOTDIR)/$(MODULE)/%.S
  @echo Skipping analysis $<

# End Analyze Rules
endif

include $(BUILD_SHARED_LIBRARY)


