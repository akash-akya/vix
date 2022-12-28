calling_from_make:
	mix compile

all:
	@$(MAKE) -C c_src all

clean:
	@$(MAKE) -C c_src clean

clean_precompiled_libvips:
	@$(MAKE) -C c_src clean_precompiled_libvips

.PHONY: all clean calling_from_make clean_precompiled_libvips

# .SILENT:
