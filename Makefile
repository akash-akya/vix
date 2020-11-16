calling_from_make:
	mix compile

UNAME := $(shell uname)

CFLAGS ?= -pthread -Wall -Werror -Wno-unused-parameter -pedantic -std=c11 -O2 -D_POSIX_C_SOURCE=200809L

ifeq ($(UNAME), Darwin)
	TARGET_CFLAGS ?= -fPIC -undefined dynamic_lookup -dynamiclib -Wextra
endif

ifeq ($(UNAME), Linux)
	TARGET_CFLAGS ?= -fPIC -shared
endif

CFLAGS += `pkg-config vips --cflags`
LIBS := `pkg-config vips --libs`

C_SOURCE := c_src/g_object/*.c c_src/*.c

all: priv/vix.so

priv/vix.so: $(C_SOURCE)
	mkdir -p priv
	$(CC) -I$(ERL_INTERFACE_INCLUDE_DIR) $(TARGET_CFLAGS) $(CFLAGS) $(C_SOURCE) $(LIBS) -o priv/vix.so

clean:
	@rm -rf priv/*.so
