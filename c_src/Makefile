MIX_APP_PATH ?= ..

PREFIX = $(MIX_APP_PATH)/priv
PRECOMPILED_LIBVIPS = $(PREFIX)/precompiled_libvips
VIX = $(PREFIX)/vix.so

# System type and C compiler/flags.

UNAME_SYS := $(shell uname -s)

ifeq ($(UNAME_SYS), Darwin)
	CFLAGS += -O2 -Wall -Werror -Wextra -Wno-unused-parameter -Wmissing-prototypes -std=c11
	LDFLAGS += -flat_namespace -undefined suppress
else ifeq ($(UNAME_SYS), Linux)
	CFLAGS += -O2 -Wall -Werror -Wextra -Wno-unused-parameter -Wmissing-prototypes -std=c11
endif

CFLAGS   += -D_POSIX_C_SOURCE=200809L -fPIC -I $(ERTS_INCLUDE_DIR) -I $(ERL_INTERFACE_INCLUDE_DIR)
LDLIBS   += -L $(ERL_INTERFACE_LIB_DIR)
LDFLAGS  += -shared

ifeq ($(VIX_PRECOMPILE), false)
	CFLAGS += `pkg-config vips --cflags`
	LDLIBS += `pkg-config vips --libs`
else
	PRECOMPILED_PATH = $(PREFIX)/precompiled_libvips
	CFLAGS  += -pthread -I $(PRECOMPILED_PATH)/include -I $(PRECOMPILED_PATH)/lib/glib-2.0/include -I $(PRECOMPILED_PATH)/include/glib-2.0
	LDLIBS  += -L $(PRECOMPILED_PATH)/lib

	ifeq ($(UNAME_SYS), Darwin)
		LDFLAGS += -Wl,-rpath,@loader_path/precompiled_libvips/lib
		LDLIBS  += -lvips.42
	else ifeq ($(UNAME_SYS), Linux)
		LDFLAGS += -Wl,-s -Wl,--disable-new-dtags -Wl,-rpath='$$ORIGIN/precompiled_libvips/lib'
		LDLIBS  += -l:libvips.so.42
	endif
endif

# Verbosity

c_verbose_0 = @echo " C     " $(?F);
c_verbose = $(c_verbose_$(V))

link_verbose_0 = @echo " LD    " $(@F);
link_verbose = $(link_verbose_$(V))

SRC = $(shell find . -type f -name "*.c")

# Object files are put in `c_src` directory.
# Maybe we should put in `${MIX_APP_PATH}/priv`?
# but then we need to compile NIF for each env
OBJ = $(addsuffix .o,$(basename $(SRC)))

calling_from_make:
	cd .. && mix compile

all: install

install: $(PREFIX) $(VIX)

$(OBJ): Makefile $(PRECOMPILED_LIBVIPS)

%.o: %.c
	$(c_verbose) $(CC) -c $(CFLAGS) -o $@ $<

$(VIX): $(OBJ)
	$(link_verbose) $(CC) $^ -o $@ $(LDFLAGS) $(LDLIBS)

$(PREFIX):
	@mkdir -p $@

$(PRECOMPILED_LIBVIPS):
	@MIX_EXS="../mix.exs" mix run --no-start --no-compile --no-deps-check ../compiler_scripts/precompiler.exs

clean:
	$(RM) $(VIX) $(OBJ)

clean_precompiled_libvips: clean
	$(RM) $(PREFIX)/libvips-*.tar.gz
	$(RM) -r $(PREFIX)/precompiled_libvips

.PHONY: all clean clean_precompiled_libvips calling_from_make install
