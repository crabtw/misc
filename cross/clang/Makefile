TARGETS = arm-linux-gnueabihf mips-linux-gnu
TARGET_CLANGS = $(addsuffix -clang,$(TARGETS))

LIB = unix.cmxa

all: $(TARGET_CLANGS)

clean:
	rm -f $(TARGET_CLANGS) *.o *.cmi *.cmo *.cmx

define DEF_TARGET_CLANGS
$(1)-clang: $(subst -,_,$(1)).ml
	ocamlopt -o $$@ $$(LIB) $$<
endef

$(foreach t,$(TARGETS),$(eval $(call DEF_TARGET_CLANGS,$(t))))

.PHONY: all clean
