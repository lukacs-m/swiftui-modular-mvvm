#!/usr/bin/env bash
#
# Rename the app/project from its current name to a new one.
#
# Updates: project.yml (name, target, source path, Info.plist path, bundle id),
# the @main App struct + its file/folder, the logger subsystem, the Makefile
# PROJECT/SCHEME vars, and README references. Does NOT touch the layer package
# names (Common, Model, Domain, Data, DI, Presentation) — only the app shell.
#
# Usage:  ./rename.sh <NewName>
# Example: ./rename.sh AcmeReader
#
set -euo pipefail

# ---- Resolve current name from project.yml --------------------------------

if [[ ! -f project.yml ]]; then
  echo "error: run this from the repo root (project.yml not found)." >&2
  exit 1
fi

OLD_NAME="$(grep -E '^name:' project.yml | head -1 | sed -E 's/^name:[[:space:]]*//' | tr -d '[:space:]')"
NEW_NAME="${1:-}"

if [[ -z "$NEW_NAME" ]]; then
  echo "usage: ./rename.sh <NewName>" >&2
  echo "current project name: $OLD_NAME" >&2
  exit 1
fi

# ---- Validate the new name (must be a valid Swift identifier / target) -----

if ! [[ "$NEW_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "error: '$NEW_NAME' is not a valid name." >&2
  echo "Use letters, numbers, and underscores; must not start with a number." >&2
  echo "(It becomes a Swift struct name and an Xcode target, so no spaces or dashes.)" >&2
  exit 1
fi

# Guard against collisions with the layer package names.
case "$NEW_NAME" in
  Common|Model|Domain|Data|DI|Presentation)
    echo "error: '$NEW_NAME' collides with a layer package name." >&2
    exit 1 ;;
esac

if [[ "$NEW_NAME" == "$OLD_NAME" ]]; then
  echo "Project is already named '$NEW_NAME'. Nothing to do."
  exit 0
fi

echo "Renaming '$OLD_NAME' → '$NEW_NAME'…"

# ---- Portable in-place sed (GNU + BSD/macOS) ------------------------------

sed_i() {
  # usage: sed_i 'expr' file
  if sed --version >/dev/null 2>&1; then
    sed -i "$1" "$2"          # GNU
  else
    sed -i '' "$1" "$2"       # BSD/macOS
  fi
}

# ---- 1. Move the app source folder + file ---------------------------------

if [[ -d "App/$OLD_NAME" ]]; then
  git mv "App/$OLD_NAME" "App/$NEW_NAME" 2>/dev/null || mv "App/$OLD_NAME" "App/$NEW_NAME"
fi
if [[ -f "App/$NEW_NAME/$OLD_NAME.swift" ]]; then
  git mv "App/$NEW_NAME/$OLD_NAME.swift" "App/$NEW_NAME/$NEW_NAME.swift" 2>/dev/null \
    || mv "App/$NEW_NAME/$OLD_NAME.swift" "App/$NEW_NAME/$NEW_NAME.swift"
fi

# ---- 2. Rewrite references in known files ---------------------------------

# App entry point: the `struct <name>: App` declaration.
if [[ -f "App/$NEW_NAME/$NEW_NAME.swift" ]]; then
  sed_i "s/struct ${OLD_NAME}: App/struct ${NEW_NAME}: App/" "App/$NEW_NAME/$NEW_NAME.swift"
  sed_i "s/${OLD_NAME}/${NEW_NAME}/g" "App/$NEW_NAME/$NEW_NAME.swift"
fi

# project.yml: name, target key, source path, Info.plist path, bundle id.
sed_i "s/${OLD_NAME}/${NEW_NAME}/g" project.yml

# Logger subsystem string in Common (com.example.<name>).
if [[ -f "Packages/Common/Sources/Common/Log.swift" ]]; then
  sed_i "s/com\.example\.${OLD_NAME}/com.example.${NEW_NAME}/" "Packages/Common/Sources/Common/Log.swift"
fi

# Makefile: PROJECT and SCHEME variables, plus comments.
sed_i "s/${OLD_NAME}/${NEW_NAME}/g" Makefile

# README references.
if [[ -f README.md ]]; then
  sed_i "s/${OLD_NAME}/${NEW_NAME}/g" README.md
fi

# ---- 3. Remove the stale generated project (regenerate from the new spec) --

rm -rf "${OLD_NAME}.xcodeproj" "${NEW_NAME}.xcodeproj"

echo "✅ Renamed to '$NEW_NAME'."
echo "   Next: run 'make generate' to produce ${NEW_NAME}.xcodeproj."
