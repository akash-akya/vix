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

all: priv/eips.so

priv/eips.so: c_src/eips.c c_src/nif_g_object.c c_src/nif_g_type.c
	mkdir -p priv
	$(CC) -I$(ERL_INTERFACE_INCLUDE_DIR) $(LIBS) $(TARGET_CFLAGS) $(CFLAGS) c_src/eips.c c_src/nif_g_object.c c_src/nif_g_type.c -o priv/eips.so

clean:
	@rm -rf priv/*.so
