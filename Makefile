# MyApp — developer tasks
#
# Common entry points:
#   make setup      install tooling, generate the Xcode project, resolve packages
#   make generate   regenerate MyApp.xcodeproj from project.yml
#   make open       open the project in Xcode (generates first if missing)
#   make test       run all module tests
#   make build      build the app for the simulator
#   make clean      remove generated project + build artifacts

PROJECT      := MyApp.xcodeproj
SCHEME       := MyApp
# Pick a simulator that exists on the machine; override on the CLI if needed:
#   make build DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro'
DESTINATION  ?= generic/platform=iOS Simulator
TEST_DESTINATION ?= $(shell python3 scripts/simulator.py)
APP_LOCK := $(PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

PACKAGE_PATH := Packages/AppModules

# Use xcbeautify for readable xcodebuild output if it's installed.
XCBEAUTIFY   := $(shell command -v xcbeautify 2>/dev/null)
ifeq ($(XCBEAUTIFY),)
  FORMAT := cat
else
  FORMAT := xcbeautify
endif

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: tools ## Generate the project. Optional: NAME=NewName to rename, RESOLVE=1 to pre-resolve packages
	@if [ -n "$(NAME)" ]; then \
		echo "Renaming project to '$(NAME)' as part of setup…"; \
		./scripts/rename.sh "$(NAME)"; \
	fi
	@$(MAKE) generate
	@echo "✅ Generated the Xcode project."
	@if [ -n "$(RESOLVE)" ]; then \
		echo "Pre-resolving packages into the Xcode project…"; \
		$(MAKE) resolve-app || exit $$?; \
	fi
	@echo "✅ Setup complete. Run 'make open' to launch Xcode."

.PHONY: tools
tools: ## Ensure XcodeGen is installed (via Homebrew)
	@if ! command -v xcodegen >/dev/null 2>&1; then \
		echo "XcodeGen not found."; \
		if command -v brew >/dev/null 2>&1; then \
			echo "Installing with Homebrew…"; \
			brew install xcodegen; \
		else \
			echo "Homebrew not found. Install XcodeGen manually:"; \
			echo "  https://github.com/yonaskolb/XcodeGen#installing"; \
			exit 1; \
		fi; \
	else \
		echo "XcodeGen present: $$(xcodegen --version)"; \
	fi

.PHONY: generate
generate: tools ## Generate MyApp.xcodeproj from project.yml
	@xcodegen generate
	@if [ -f Package.resolved ]; then \
		mkdir -p "$(dir $(APP_LOCK))"; \
		cp Package.resolved "$(APP_LOCK)"; \
	fi
	@echo "✅ Generated $(PROJECT)"

# Regenerate only when the spec or this Makefile changes.
$(PROJECT): project.yml Makefile
	@$(MAKE) generate

.PHONY: open
open: $(PROJECT) ## Open the project in Xcode
	@open $(PROJECT)

# Dependency updates are explicit; normal builds and tests use the resolved versions.

.PHONY: resolve-app
resolve-app: $(PROJECT) ## Resolve the app and retain its generated lockfile outside the project
	@xcodebuild -resolvePackageDependencies -project $(PROJECT) -scheme $(SCHEME)
	@cp "$(APP_LOCK)" Package.resolved
	@echo "✅ Resolved app dependencies."

.PHONY: resolve
resolve: ## Resolve AppModules dependencies for command-line builds
	@swift package --package-path $(PACKAGE_PATH) resolve

.PHONY: build
build: $(PROJECT) ## Build the app for the simulator
	@set -o pipefail && xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-onlyUsePackageVersionsFromResolvedFile \
		-skipMacroValidation \
		| $(FORMAT)

.PHONY: test
test: ## Run all module tests on the host Mac
	@swift test --package-path $(PACKAGE_PATH) --force-resolved-versions

.PHONY: test-app
test-app: $(PROJECT) ## Run package tests on an available simulator (override TEST_DESTINATION)
	@test -n "$(TEST_DESTINATION)" || (echo "No iPhone simulator available."; exit 1)
	@set -o pipefail && xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(TEST_DESTINATION)' \
		-onlyUsePackageVersionsFromResolvedFile \
		-skipMacroValidation \
		| $(FORMAT)

.PHONY: lint
lint: ## Lint with SwiftLint (reads .swiftlint.yml)
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		echo "SwiftLint not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi
	@swiftlint lint --quiet

.PHONY: format
format: ## Reformat sources in place with SwiftFormat (reads .swiftformat)
	@if ! command -v swiftformat >/dev/null 2>&1; then \
		echo "SwiftFormat not found. Install with: brew install swiftformat"; \
		exit 1; \
	fi
	@swiftformat Packages App
	@echo "✅ Formatted."

.PHONY: format-check
format-check: ## Check formatting without writing (used by CI)
	@if ! command -v swiftformat >/dev/null 2>&1; then \
		echo "SwiftFormat not found. Install with: brew install swiftformat"; \
		exit 1; \
	fi
	@swiftformat Packages App --lint

.PHONY: clean
clean: ## Remove generated project and build artifacts
	@rm -rf $(PROJECT)
	@rm -rf build DerivedData
	@rm -rf $(PACKAGE_PATH)/.build
	@echo "🧹 Cleaned generated project and build artifacts."

.PHONY: rename
rename: ## Rename the project: make rename NAME=NewName
	@if [ -z "$(NAME)" ]; then \
		echo "usage: make rename NAME=NewName"; \
		echo "(NewName must be a Swift type and bundle ID component - letters and numbers)"; \
		exit 1; \
	fi
	@./scripts/rename.sh "$(NAME)"
	@$(MAKE) generate
	@echo "✅ Renamed and regenerated. Run 'make open' to launch Xcode."

.PHONY: new-project
new-project: ## Strip the example slice (optional NAME=NewName to also rename)
	@if [ -n "$(NAME)" ]; then ./scripts/rename.sh "$(NAME)" --check; fi
	@./scripts/scaffold-clean.sh --force
	@if [ -n "$(NAME)" ]; then ./scripts/rename.sh "$(NAME)"; fi
	@$(MAKE) generate
	@echo "✅ Clean project ready. Run 'make open' to launch Xcode."

#
# Installs the .xctemplate bundles in Templates/ into Xcode's user template
# directory (symlinked, so repo edits take effect immediately). After installing,
# they appear in Xcode's "New File…" dialog under "MVVM Scaffold".

TEMPLATE_DEST := $(HOME)/Library/Developer/Xcode/Templates/MVVM Scaffold

.PHONY: install-templates
install-templates: ## Install the Xcode file templates (View/ViewModel, UseCase)
	@mkdir -p "$(TEMPLATE_DEST)"
	@for tpl in Templates/*.xctemplate; do \
		name=$$(basename "$$tpl"); \
		rm -rf "$(TEMPLATE_DEST)/$$name"; \
		ln -s "$(CURDIR)/$$tpl" "$(TEMPLATE_DEST)/$$name"; \
		echo "  ↳ linked $$name"; \
	done
	@echo "✅ Templates installed. In Xcode: New File… → MVVM Scaffold."

.PHONY: uninstall-templates
uninstall-templates: ## Remove the installed Xcode file templates
	@rm -rf "$(TEMPLATE_DEST)"
	@echo "🧹 Removed templates from $(TEMPLATE_DEST)."

.PHONY: check-architecture check-locks test-scaffold test-templates
check-architecture: ## Check target dependencies, isolation, and forbidden imports
	@python3 scripts/check-architecture.py

check-locks: ## Check that app and package roots pin identical external versions
	@python3 scripts/check-locks.py

test-scaffold: ## Exercise bootstrap commands in a temporary copy, including tests and iOS build
	@python3 scripts/test-scaffold.py

test-templates: ## Expand Xcode templates in a temporary copy and compile them
	@python3 scripts/test-templates.py
