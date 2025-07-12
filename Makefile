# Silence directory change messages
MAKEFLAGS += --no-print-directory

# Default target
all: compile

# Main compilation target
compile:
	@$(MAKE) -C c_src all

# Mix compilation (called by elixir_make)
calling_from_make:
	mix compile

# Clean targets
clean:
	@$(MAKE) -C c_src clean

clean_precompiled_libvips:
	@$(MAKE) -C c_src clean_precompiled_libvips

deep_clean: clean_precompiled_libvips

# Development targets
test:
	mix test

format:
	mix format

lint:
	mix credo

dialyz:
	mix dialyxir

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
	@echo "  dialyz                - Run Dialyzer type checking"
	@echo "  help                  - Show this help"

.PHONY: all compile clean clean_precompiled_libvips deep_clean calling_from_make test format lint dialyz help
