#!/usr/bin/env bash
#
# Strip the example "Article" feature slice from the scaffold, leaving a clean
# but still-compiling skeleton: six packages with their structural files intact
# (ViewState, Log, the DI FactoryKit re-export) and a minimal app entry point.
#
# After running, each layer has a placeholder source so SPM still has something
# to build. Replace the placeholders as you add your first real feature.
#
# Usage:  ./scaffold-clean.sh [--force]
#         --force   skip the confirmation prompt
#
set -euo pipefail

FORCE="${1:-}"

# The example slice — every file that exists only to demonstrate the pattern.
EXAMPLE_FILES=(
  "Packages/Model/Sources/Model/Article.swift"
  "Packages/Domain/Sources/Domain/ArticleRepository.swift"
  "Packages/Domain/Sources/Domain/FetchArticlesUseCase.swift"
  "Packages/Domain/Tests/DomainTests/FetchArticlesTests.swift"
  "Packages/Data/Sources/Data/ArticleDTO.swift"
  "Packages/Data/Sources/Data/RemoteArticleRepository.swift"
  "Packages/DI/Sources/DI/Registrations/ArticleRegistrations.swift"
  "Packages/Presentation/Sources/Presentation/ArticleListView.swift"
  "Packages/Presentation/Sources/Presentation/ArticleListViewModel.swift"
  "Packages/Presentation/Tests/PresentationTests/ArticleListViewModelTests.swift"
)

if [[ ! -d Packages ]]; then
  echo "error: run this from the repo root (no Packages/ directory found)." >&2
  exit 1
fi

# Detect whether the slice is even present (idempotency).
if [[ ! -f "Packages/Model/Sources/Model/Article.swift" ]]; then
  echo "Example slice already removed — nothing to do."
  exit 0
fi

if [[ "$FORCE" != "--force" ]]; then
  echo "This removes the example 'Article' feature from all six packages and"
  echo "replaces the app entry point with an empty scene. Structural files"
  echo "(ViewState, Log, DI re-export) are kept."
  printf "Proceed? [y/N] "
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# Resolve the current app name from project.yml so we rewrite the right file.
APP_NAME="$(grep -E '^name:' project.yml | head -1 | sed -E 's/^name:[[:space:]]*//' | tr -d '[:space:]')"

# ---- 1. Delete the example files ------------------------------------------

for f in "${EXAMPLE_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    git rm -q "$f" 2>/dev/null || rm -f "$f"
  fi
done

# ---- 2. Drop a placeholder into every now-empty target --------------------
# SPM requires at least one source file per target.

placeholder() {
  # $1 = file path, $2 = module name (for the comment)
  local path="$1" module="$2"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
// Placeholder so the $module target has a source to compile.
// Delete this once you add your first real type to $module.
EOF
}

placeholder "Packages/Model/Sources/Model/Placeholder.swift"             "Model"
placeholder "Packages/Domain/Sources/Domain/Placeholder.swift"           "Domain"
placeholder "Packages/Data/Sources/Data/Placeholder.swift"               "Data"
placeholder "Packages/Presentation/Sources/Presentation/Placeholder.swift" "Presentation"

# Keep the DI Registrations folder discoverable, but empty of features.
placeholder "Packages/DI/Sources/DI/Registrations/Placeholder.swift"     "DI registrations"

# Domain and Presentation lose their only test file — leave the test target
# with a trivially-passing placeholder so `swift test` still runs.
cat > "Packages/Domain/Tests/DomainTests/PlaceholderTests.swift" <<'EOF'
import Testing

@Test func domainPlaceholder() {
    // Replace with real Domain tests as you add use cases.
    #expect(Bool(true))
}
EOF

cat > "Packages/Presentation/Tests/PresentationTests/PlaceholderTests.swift" <<'EOF'
import Testing

@Test func presentationPlaceholder() {
    // Replace with real Presentation tests as you add view models.
    #expect(Bool(true))
}
EOF

# ---- 3. Reset the app entry point to an empty scene -----------------------

APP_FILE="App/$APP_NAME/$APP_NAME.swift"
if [[ -f "$APP_FILE" ]]; then
  cat > "$APP_FILE" <<EOF
import SwiftUI

/// The entire app target. All logic and UI live in the layer packages
/// (Common / Model / Domain / Data / DI / Presentation). Wire your root view
/// from Presentation here once you build it.
@main
struct $APP_NAME: App {
    var body: some Scene {
        WindowGroup {
            // Replace with your root view from the Presentation package.
            EmptyView()
        }
    }
}
EOF
fi

echo "✅ Stripped the example slice. Six clean packages remain."
echo "   Next: add your first feature (Model → Domain → Data → DI → Presentation)."
