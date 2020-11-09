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

GLIB := `pkg-config glib-2.0 --cflags --libs`
VIPS := `pkg-config vips --cflags --libs`

LIBS := $(GLIB) $(VIPS)
C_SOURCE := c_src/*.c

all: priv/vix.so

priv/vix.so: $(C_SOURCE)
	mkdir -p priv
	$(CC) -I$(ERL_INTERFACE_INCLUDE_DIR) $(LIBS) $(TARGET_CFLAGS) $(CFLAGS) $(C_SOURCE) -o priv/vix.so

clean:
	@rm -rf priv/*.so
