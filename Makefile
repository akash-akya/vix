calling_from_make:
	mix compile

all:
	@$(MAKE) -C c_src

clean:
	@$(MAKE) -C c_src clean

.PHONY: all clean calling_from_make
