# Force POSIX-compatible shell
SHELL = /bin/sh

# Build configuration
MIX_APP_PATH ?= ..
PREFIX = $(MIX_APP_PATH)/priv
VIX = $(PREFIX)/vix.so

# Compilation mode configuration
VIX_COMPILATION_MODE ?= PRECOMPILED_NIF_AND_LIBVIPS
VIX_COMPILATION_MODE := $(shell echo "$(VIX_COMPILATION_MODE)" | tr '[:lower:]' '[:upper:]')

# Build tools
CC ?= gcc
RM ?= rm -f
MKDIR_P ?= mkdir -p

# System detection and platform-specific configuration
UNAME_SYS := $(shell uname -s 2>/dev/null || echo Unknown)
UNAME_ARCH := $(shell uname -m 2>/dev/null || echo Unknown)

# Base compiler flags
BASE_CFLAGS = -O2 -Wall -Werror -Wextra -Wno-unused-parameter -Wmissing-prototypes -std=c11

# Platform-specific flags
ifeq ($(UNAME_SYS), Darwin)
	CFLAGS += $(BASE_CFLAGS)
	LDFLAGS += -flat_namespace -undefined suppress
else ifeq ($(UNAME_SYS), Linux)
	CFLAGS += $(BASE_CFLAGS)
endif

# flags that are common to all platform
CFLAGS += -D_POSIX_C_SOURCE=200809L -fPIC

# Erlang/OTP includes and libraries
CFLAGS += -I "$(ERTS_INCLUDE_DIR)" -I "$(ERL_INTERFACE_INCLUDE_DIR)"
LDLIBS += -L "$(ERL_INTERFACE_LIB_DIR)"
LDFLAGS += -shared

ifeq ($(VIX_COMPILATION_MODE), PLATFORM_PROVIDED_LIBVIPS)
	VIPS_CFLAGS := $(shell pkg-config vips --cflags 2>/dev/null)
	VIPS_LIBS := $(shell pkg-config vips --libs 2>/dev/null)
	CFLAGS += $(VIPS_CFLAGS)
	LDLIBS += $(VIPS_LIBS)
	PKG_CONFIG_CHECK = check-pkg-config
else
	PKG_CONFIG_CHECK =
	PRECOMPILED_LIBVIPS_PATH = $(PREFIX)/precompiled_libvips

	ifeq ($(VIX_COMPILATION_MODE), PRECOMPILED_LIBVIPS)
		# force fetching libvips if previously configured to use PRECOMPILED_NIF_AND_LIBVIPS
		# since the precompiled vix does not bundle `include`
		PRECOMPILED_LIBVIPS_PREREQUISITE = $(PRECOMPILED_LIBVIPS_PATH)/include
	else
		PRECOMPILED_LIBVIPS_PREREQUISITE = $(PRECOMPILED_LIBVIPS_PATH)
	endif

	CFLAGS += -pthread
	CFLAGS += -I "$(PRECOMPILED_LIBVIPS_PATH)/include"
	CFLAGS += -I "$(PRECOMPILED_LIBVIPS_PATH)/lib/glib-2.0/include"
	CFLAGS += -I "$(PRECOMPILED_LIBVIPS_PATH)/include/glib-2.0"
	LDLIBS += -L "$(PRECOMPILED_LIBVIPS_PATH)/lib"

	ifeq ($(UNAME_SYS), Darwin)
		LDFLAGS += -Wl,-rpath,@loader_path/precompiled_libvips/lib
		LDLIBS  += -lvips.42
	else ifeq ($(UNAME_SYS), Linux)
		LDFLAGS += -Wl,-s -Wl,--disable-new-dtags -Wl,-rpath='$$ORIGIN/precompiled_libvips/lib'
		LDLIBS  += -l:libvips.so.42
	endif
endif

# Verbosity control
V ?= 0
ifeq ($(V),0)
	Q = @
	SAY = @echo
else
	Q =
	SAY = @\#
endif

c_verbose_0 = @echo " CC    " $(<F);
c_verbose_1 =
c_verbose = $(c_verbose_$(V))

link_verbose_0 = @echo " LD    " $(@F);
link_verbose_1 =
link_verbose = $(link_verbose_$(V))

# Source files discovery
SRC := $(wildcard *.c g_object/*.c)
ifeq ($(SRC),)
	$(error No C source files found)
endif

# Object files (placed in source directory to avoid env conflicts)
OBJ := $(SRC:.c=.o)

# Dependency files for better incremental builds
DEP := $(SRC:.c=.d)

# Main targets
all: check-env $(PKG_CONFIG_CHECK) $(VIX)
	$(SAY) "Build complete: $(VIX)"

install: all

calling_from_make:
	$(Q)cd .. && mix compile

# Environment validation
check-env:
	@if [ -z "$(ERTS_INCLUDE_DIR)" ]; then \
		echo "Error: ERTS_INCLUDE_DIR not set"; \
		exit 1; \
	fi
	@if [ -z "$(ERL_INTERFACE_INCLUDE_DIR)" ]; then \
		echo "Error: ERL_INTERFACE_INCLUDE_DIR not set"; \
		exit 1; \
	fi
	@if [ -z "$(ERL_INTERFACE_LIB_DIR)" ]; then \
		echo "Error: ERL_INTERFACE_LIB_DIR not set"; \
		exit 1; \
	fi

check-pkg-config:
	@if ! command -v pkg-config >/dev/null 2>&1; then \
		echo "Error: pkg-config not found but required for PLATFORM_PROVIDED_LIBVIPS"; \
		exit 1; \
	fi
	@if ! pkg-config --exists vips; then \
		echo "Error: vips not found via pkg-config"; \
		echo "Please install libvips development headers"; \
		exit 1; \
	fi

# Create output directory
$(PREFIX):
	$(Q)$(MKDIR_P) "$@"

$(OBJ): Makefile $(PRECOMPILED_LIBVIPS_PREREQUISITE)

# Dependency generation
%.d: %.c
	$(Q)$(CC) $(CFLAGS) -MM -MT $(@:.d=.o) $< > $@

# Include dependency files if they exist
-include $(DEP)

# Object file compilation with dependency tracking
%.o: %.c
	$(c_verbose)$(CC) -c $(CFLAGS) -MMD -MP -o $@ $<

# Final linking
$(VIX): $(PREFIX) $(OBJ)
	$(link_verbose)$(CC) $(OBJ) -o $@ $(LDFLAGS) $(LDLIBS)

# Precompiled libvips setup
$(PRECOMPILED_LIBVIPS_PREREQUISITE):
	$(SAY) "Setting up precompiled libvips..."
	$(Q) elixir ../build_scripts/precompiler.exs "$(PREFIX)"

# Clean targets
clean:
	$(SAY) "Cleaning build artifacts..."
	$(Q)$(RM) $(VIX) $(OBJ) $(DEP)

clean_precompiled_libvips: clean
	$(SAY) "Cleaning precompiled libvips..."
	$(Q)$(RM) "$(PREFIX)"/libvips-*.tar.gz
	$(Q)$(RM) -r "$(PREFIX)/precompiled_libvips"

# Help target
help:
	@echo "Available targets:"
	@echo "  all                        - Build the NIF library"
	@echo "  clean                      - Clean build artifacts"
	@echo "  clean_precompiled_libvips  - Clean precompiled libvips"
	@echo "  check-env                  - Validate build environment"
	@echo "  help                       - Show this help"
	@echo ""
	@echo "Build configuration:"
	@echo "  VIX_COMPILATION_MODE: $(VIX_COMPILATION_MODE)"
	@echo "  System: $(UNAME_SYS) $(UNAME_ARCH)"
	@echo "  CC: $(CC)"
	@echo ""
	@echo "Set V=1 for verbose output"

# Debug target
debug:
	@echo "=== Build Configuration ==="
	@echo "VIX_COMPILATION_MODE: $(VIX_COMPILATION_MODE)"
	@echo "UNAME_SYS: $(UNAME_SYS)"
	@echo "UNAME_ARCH: $(UNAME_ARCH)"
	@echo "CC: $(CC)"
	@echo "CFLAGS: $(CFLAGS)"
	@echo "LDFLAGS: $(LDFLAGS)"
	@echo "LDLIBS: $(LDLIBS)"
	@echo "SRC: $(SRC)"
	@echo "OBJ: $(OBJ)"
	@echo "PREFIX: $(PREFIX)"
	@echo "VIX: $(VIX)"

.PHONY: all clean clean_precompiled_libvips calling_from_make install check-env check-pkg-config help debug
