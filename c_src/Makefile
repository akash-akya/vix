# Based on c_src.mk from erlang.mk by Loic Hoguin <essen@ninenines.eu>

PREFIX = ../priv
BUILD  = ../obj

VIX = $(PREFIX)/vix.so

# System type and C compiler/flags.

UNAME_SYS := $(shell uname -s)

ifeq ($(UNAME_SYS), Darwin)
	CFLAGS += -O2 -Wall -Werror -Wextra -Wno-unused-parameter -Wmissing-prototypes -std=c11
	LDFLAGS += -flat_namespace -undefined suppress
else ifeq ($(UNAME_SYS), Linux)
	CFLAGS += -O2 -Wall -Werror -Wextra -Wno-unused-parameter -Wmissing-prototypes -std=c11
else
	# unsupported
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

SRC = $(shell find . -type f \( -name "*.c" \))
OBJ = $(addprefix $(BUILD)/,$(addsuffix .o,$(basename $(SRC))))
OBJ_DIRS = $(addprefix $(BUILD)/,$(shell find . -mindepth 1 -type d))

calling_from_make:
	cd .. && mix compile

all: install

install: $(PREFIX) $(BUILD) $(OBJ_DIRS) $(VIX)

$(OBJ): Makefile

$(BUILD)/%.o: %.c
	$(c_verbose) $(CC) -c $(CFLAGS) -o $@ $<

$(VIX): $(OBJ)
	$(link_verbose) $(CC) $^ -o $@ $(LDFLAGS) $(LDLIBS)

$(PREFIX) $(BUILD) $(OBJ_DIRS):
	@mkdir -p $@

clean:
	@$(RM) $(VIX) $(OBJ)

.PHONY: all clean calling_from_make install
