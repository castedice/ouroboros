#!/bin/bash
# Post Write/Edit hook: unified format dispatcher
# Routes to language-specific formatters based on file extension.
# Silently skips if the required tool is not installed.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

case "$FILE_PATH" in
  *.py)
    command -v ruff >/dev/null 2>&1 && {
      ruff format "$FILE_PATH" 2>/dev/null
      ruff check --fix "$FILE_PATH" 2>/dev/null
    }
    command -v ty >/dev/null 2>&1 && ty check "$FILE_PATH" 2>/dev/null || true
    ;;
  *.ts | *.tsx)
    command -v npx >/dev/null 2>&1 && {
      npx prettier --write "$FILE_PATH" 2>/dev/null
      npx eslint --fix "$FILE_PATH" 2>/dev/null || true
    }
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE_PATH" 2>/dev/null
    ;;
  *.md)
    # auto-fix: trailing whitespace
    sed -i '' 's/[[:space:]]*$//' "$FILE_PATH" 2>/dev/null
    # auto-fix: ensure final newline
    [ -s "$FILE_PATH" ] && [ -n "$(tail -c 1 "$FILE_PATH")" ] && printf '\n' >>"$FILE_PATH"
    # lint: remaining issues need judgment
    command -v rumdl >/dev/null 2>&1 && rumdl check "$FILE_PATH" 2>&1 || true
    ;;
  *.sh)
    command -v shfmt >/dev/null 2>&1 && shfmt -w "$FILE_PATH" 2>/dev/null
    command -v shellcheck >/dev/null 2>&1 && shellcheck "$FILE_PATH" 2>&1 || true
    command -v shellharden >/dev/null 2>&1 && shellharden --check "$FILE_PATH" 2>&1 || true
    ;;
esac

exit 0
