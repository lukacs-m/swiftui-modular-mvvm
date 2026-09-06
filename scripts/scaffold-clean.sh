#!/usr/bin/env bash
# Empty targets need placeholders after the example is removed.
set -euo pipefail

FORCE="${1:-}"

# The example slice — every file that exists only to demonstrate the pattern.
EXAMPLE_FILES=(
  "Packages/AppModules/Sources/Model/Article.swift"
  "Packages/AppModules/Sources/Domain/ArticleRepository.swift"
  "Packages/AppModules/Sources/Domain/FetchArticlesUseCase.swift"
  "Packages/AppModules/Tests/DomainTests/FetchArticlesTests.swift"
  "Packages/AppModules/Sources/Data/ArticleDTO.swift"
  "Packages/AppModules/Sources/Data/SampleArticleRepository.swift"
  "Packages/AppModules/Tests/DataTests/ArticleRepositoryTests.swift"
  "Packages/AppModules/Sources/DI/Registrations/ArticleRegistrations.swift"
  "Packages/AppModules/Sources/Presentation/ArticleListView.swift"
  "Packages/AppModules/Sources/Presentation/ArticleListViewModel.swift"
  "Packages/AppModules/Tests/PresentationTests/ArticleListViewModelTests.swift"
  "Packages/AppModules/Tests/PresentationTests/ArticleLifecycleTests.swift"
)

if [[ ! -f Packages/AppModules/Package.swift ]]; then
  echo "error: run this from the repo root (Packages/AppModules/Package.swift not found)." >&2
  exit 1
fi

# Detect whether the slice is even present (idempotency).
if [[ ! -f "Packages/AppModules/Sources/Model/Article.swift" ]]; then
  echo "Example slice already removed — nothing to do."
  exit 0
fi

if [[ "$FORCE" != "--force" ]]; then
  echo "This removes the example 'Article' feature from all six modules and"
  echo "replaces the app entry point with an empty scene. Structural files"
  echo "(ViewState, DomainError, Log, DI re-export) are kept."
  printf "Proceed? [y/N] "
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# Resolve the current app name from project.yml so we rewrite the right file.
APP_NAME="$(grep -E '^name:' project.yml | head -1 | sed -E 's/^name:[[:space:]]*//' | tr -d '[:space:]')"

# --force skips the prompt, not protection for customized example files.
if [[ "$(git rev-parse --show-toplevel 2>/dev/null || true)" == "$(pwd -P)" ]]; then
  if [[ -n "$(git status --porcelain -- "${EXAMPLE_FILES[@]}" "App/$APP_NAME/$APP_NAME.swift")" ]]; then
    echo "error: example files have local changes; commit or save them before removing the slice." >&2
    exit 1
  fi
fi

for f in "${EXAMPLE_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    git rm -q "$f" 2>/dev/null || rm -f "$f"
  fi
done

# SPM requires at least one source file per target.

placeholder() {
  # $1 = file path, $2 = module name (for the comment)
  local path="$1" module="$2"
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]]; then return; fi
  cat > "$path" <<EOF
// Placeholder so the $module target has a source to compile.
// Delete this once you add your first real type to $module.
EOF
}

placeholder "Packages/AppModules/Sources/Model/Placeholder.swift"             "Model"
placeholder "Packages/AppModules/Sources/Data/Placeholder.swift"               "Data"

# Keep the DI Registrations folder discoverable, but empty of features.
placeholder "Packages/AppModules/Sources/DI/Registrations/Placeholder.swift"     "DI registrations"

# Keep test discovery working after removing the example suites.
mkdir -p "Packages/AppModules/Tests/DomainTests"
if [[ ! -f "Packages/AppModules/Tests/DomainTests/PlaceholderTests.swift" ]]; then
cat > "Packages/AppModules/Tests/DomainTests/PlaceholderTests.swift" <<'EOF'
import Testing

@Test func domainPlaceholder() {
    // Replace with real Domain tests as you add use cases.
    #expect(Bool(true))
}
EOF
fi

mkdir -p "Packages/AppModules/Tests/PresentationTests"
if [[ ! -f "Packages/AppModules/Tests/PresentationTests/PlaceholderTests.swift" ]]; then
cat > "Packages/AppModules/Tests/PresentationTests/PlaceholderTests.swift" <<'EOF'
import Testing

@Test func presentationPlaceholder() {
    // Replace with real Presentation tests as you add view models.
    #expect(Bool(true))
}
EOF
fi

mkdir -p "Packages/AppModules/Tests/DataTests"
if [[ ! -f "Packages/AppModules/Tests/DataTests/PlaceholderTests.swift" ]]; then
cat > "Packages/AppModules/Tests/DataTests/PlaceholderTests.swift" <<'EOF'
import Testing

@Test func dataPlaceholder() {
    #expect(Bool(true))
}
EOF
fi

APP_FILE="App/$APP_NAME/$APP_NAME.swift"
if [[ -f "$APP_FILE" ]]; then
  cat > "$APP_FILE" <<EOF
import SwiftUI

@main
struct $APP_NAME: App {
    var body: some Scene {
        WindowGroup {
            // Replace with your root view from the Presentation module.
            EmptyView()
        }
    }
}
EOF
fi

echo "✅ Stripped the example slice. One package with six clean modules remains."
echo "   Next: add your first feature (Model → Domain → Data → DI → Presentation)."
