# Silence directory change messages
MAKEFLAGS += --no-print-directory

# Default target
all: compile

# Main compilation target
compile:
ifdef ERTS_INCLUDE_DIR
	@$(MAKE) -C c_src all
else
	@mix compile
endif

# Mix compilation (called by elixir_make)
calling_from_make:
	mix compile

# Clean targets
clean:
ifdef ERTS_INCLUDE_DIR
	@$(MAKE) -C c_src clean
else
	@mix clean
endif

clean_precompiled_libvips:
	@$(MAKE) -C c_src clean_precompiled_libvips

deep_clean:
ifdef ERTS_INCLUDE_DIR
	@$(MAKE) -C c_src clean_precompiled_libvips
else
	@mix clean
	@$(MAKE) -C c_src clean_precompiled_libvips
endif

# Development targets
test:
	mix test

format:
	mix format

lint:
	mix credo

dialyxir:
	mix dialyxir

dialyz: dialyxir

debug:
	@$(MAKE) -C c_src debug

# Help target
help:
	@echo "Available targets:"
	@echo "  all/compile           - Build the project"
	@echo "  clean                 - Clean build artifacts"
	@echo "  clean_precompiled_libvips - Clean precompiled libvips"
	@echo "  deep_clean            - Full clean including precompiled libs"
	@echo "  test                  - Run tests"
	@echo "  format                - Format Elixir code"
	@echo "  lint                  - Run Credo linter"
	@echo "  dialyxir/dialyz       - Run Dialyzer type checking"
	@echo "  debug                 - Show native build configuration"
	@echo "  help                  - Show this help"

.PHONY: all compile clean clean_precompiled_libvips deep_clean calling_from_make test format lint dialyxir dialyz debug help
