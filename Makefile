calling_from_make:
	mix compile

UNAME := $(shell uname)

# CFLAGS ?= -pthread -Wall -Werror -Wno-unused-parameter -pedantic -std=c11 -O2
CFLAGS ?= -pthread -Wall -Wno-unused-parameter -pedantic -std=c11 -O2

ifeq ($(UNAME), Darwin)
	TARGET_CFLAGS ?= -fPIC -undefined dynamic_lookup -dynamiclib -Wextra
endif

ifeq ($(UNAME), Linux)
	TARGET_CFLAGS ?= -fPIC -shared
endif

VIPS := `pkg-config vips-cpp --cflags --libs`
GOBJECT := `pkg-config gobject-introspection-1.0 --cflags --libs`
GLIB := `pkg-config glib-2.0 --cflags --libs`

LIBS := $(VIPS) $(GOBJECT) $(GLIB)
C_SOURCE := c_src/vix.c c_src/nif_g_object.c c_src/nif_g_type.c c_src/nif_g_param_spec.c c_src/nif_g_value.c c_src/nif_g_boxed.c c_src/nif_vips_boxed.c c_src/nif_vips_operation.c

all: priv/vix.so

priv/vix.so: $(C_SOURCE)
	mkdir -p priv
	$(CC) -I$(ERL_INTERFACE_INCLUDE_DIR) $(LIBS) $(TARGET_CFLAGS) $(CFLAGS) $(C_SOURCE) -o priv/vix.so

clean:
	@rm -rf priv/*.so
