MODULE = System/objc

CCFLAGS = \
    -DTYPE_DEPENDENT_DISPATCH \
    -DGNUSTEP \
    -D_XOPEN_SOURCE=500 \
    -D__OBJC_RUNTIME_INTERNAL__=1 \

OBJECTS = \
	NSBlocks.o\
	Protocol2.o\
	abi_version.o\
	blocks_runtime.o\
	caps.o\
	category_loader.o\
	class_table.o\
	dtable.o\
	eh_personality.o\
	encoding2.o\
	hash_table.o\
	hooks.o\
	ivar.o\
	legacy_malloc.o\
	loader.o\
	mutation.o\
	properties.o\
	protocol.o\
	runtime.o\
	sarray2.o\
	selector_table.o\
	sendmsg2.o\
	statics_loader.o\
	sync.o\
	toydispatch.o

include $(ROOTDIR)/module.mk
