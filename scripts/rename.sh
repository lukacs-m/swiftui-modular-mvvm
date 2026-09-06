#!/usr/bin/env bash
# AppModules and its module names stay stable when the app shell is renamed.
set -euo pipefail

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

if ! [[ "$NEW_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "error: use letters and numbers, starting with a letter (Swift type and bundle ID)." >&2
  exit 1
fi
if ! printf 'struct %s {}\n' "$NEW_NAME" | swiftc -frontend -parse - >/dev/null 2>&1; then
  echo "error: '$NEW_NAME' cannot be used as a Swift type name." >&2
  exit 1
fi

case "$NEW_NAME" in
  Common|Model|Domain|Data|DI|Presentation|App|AppModules)
    echo "error: '$NEW_NAME' is reserved by the scaffold." >&2
    exit 1 ;;
esac

if [[ "$NEW_NAME" == "$OLD_NAME" ]]; then
  echo "Project is already named '$NEW_NAME'. Nothing to do."
  exit 0
fi

if [[ -e "App/$NEW_NAME" ]]; then
  echo "error: App/$NEW_NAME already exists." >&2
  exit 1
fi

if [[ "${2:-}" == "--check" ]]; then
  exit 0
fi

echo "Renaming '$OLD_NAME' → '$NEW_NAME'…"

sed_i() {
  # usage: sed_i 'expr' file
  if sed --version >/dev/null 2>&1; then
    sed -i "$1" "$2"          # GNU
  else
    sed -i '' "$1" "$2"       # BSD/macOS
  fi
}

if [[ -d "App/$OLD_NAME" ]]; then
  git mv "App/$OLD_NAME" "App/$NEW_NAME" 2>/dev/null || mv "App/$OLD_NAME" "App/$NEW_NAME"
fi
if [[ -f "App/$NEW_NAME/$OLD_NAME.swift" ]]; then
  git mv "App/$NEW_NAME/$OLD_NAME.swift" "App/$NEW_NAME/$NEW_NAME.swift" 2>/dev/null \
    || mv "App/$NEW_NAME/$OLD_NAME.swift" "App/$NEW_NAME/$NEW_NAME.swift"
fi

# App entry point: the `struct <name>: App` declaration.
if [[ -f "App/$NEW_NAME/$NEW_NAME.swift" ]]; then
  sed_i "s/${OLD_NAME}/${NEW_NAME}/g" "App/$NEW_NAME/$NEW_NAME.swift"
fi

# project.yml: name, target key, source path, Info.plist path, bundle id.
sed_i "s/${OLD_NAME}/${NEW_NAME}/g" project.yml

# Logger subsystem string in Common (com.example.<name>).
if [[ -f "Packages/AppModules/Sources/Common/Log.swift" ]]; then
  sed_i "s/com\.example\.${OLD_NAME}/com.example.${NEW_NAME}/" "Packages/AppModules/Sources/Common/Log.swift"
fi

# Makefile: PROJECT and SCHEME variables, plus comments.
sed_i "s/${OLD_NAME}/${NEW_NAME}/g" Makefile

# README references.
if [[ -f README.md ]]; then
  sed_i "s/${OLD_NAME}/${NEW_NAME}/g" README.md
fi

rm -rf "${OLD_NAME}.xcodeproj" "${NEW_NAME}.xcodeproj"

echo "✅ Renamed to '$NEW_NAME'."
echo "   Next: run 'make generate' to produce ${NEW_NAME}.xcodeproj."
