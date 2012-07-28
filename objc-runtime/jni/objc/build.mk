MODULE = System/objc

CCFLAGS = \
    -DTYPE_DEPENDENT_DISPATCH \
    -DGNUSTEP \
    -D_XOPEN_SOURCE=500 \
    -D__OBJC_RUNTIME_INTERNAL__=1 \
    -fblocks \
    -D__BSD_VISIBLE=1 \
    -D_BSD_SOURCE=1 \

# Occasionally, it seems to deadlock by trying to
# lock the selector table twice. This was observed in
# ZombieSmash and appears to be some kind of race condition
# because it doesn't always reproduce.
CCFLAGS += -DMAP_TABLE_NO_LOCK

ifeq ($(OS), win)
CCFLAGS += \
    -I$(SYSDIR)/pthreads \
    -I$(SYSDIR)/dcfnix \

endif

ifeq ($(CHECK_ILL_OBJECTS), yes)
CCFLAGS += -DCHECK_ILL_OBJECTS
endif

OBJECTS = \
	gc_none.o \
	NSBlocks.o \
	Protocol2.o \
	abi_version.o \
	associate.o \
	block_to_imp.o \
	block_trampolines.o \
	blocks_runtime.o \
	caps.o \
	category_loader.o \
	class_table.o \
	dtable.o \
	eh_personality.o \
	encoding2.o \
	hash_table.o \
	hooks.o \
	ill_object.o \
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
	sync.o \
	toydispatch.o \
	objcxx_eh.o \

include $(ROOTDIR)/module.mk
