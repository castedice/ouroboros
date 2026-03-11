#!/bin/bash
# Post Write/Edit hook: unified format dispatcher
# Routes to language-specific formatters based on file extension.
# Silently skips if the required tool is not installed.
#
# Idempotency: running this script multiple times on the same file produces
# identical results. All formatters are convergent (format(format(x)) == format(x)).
#
# Opt-out: set OUROBOROS_NO_FORMAT=1 to skip all formatting (useful in scripts
# or batch operations where formatting is deferred).
# No security role — formatting only, does not validate or sanitize file content.

# Opt-out via environment variable
[[ "${OUROBOROS_NO_FORMAT:-}" == "1" ]] && exit 0

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
    # auto-fix: trailing whitespace (portable — no BSD/GNU sed -i divergence)
    perl -pi -e 's/[[:blank:]]+$//' "$FILE_PATH" 2>/dev/null
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
  *)
    # Unsupported file type — no formatter available
    ;;
esac

exit 0
