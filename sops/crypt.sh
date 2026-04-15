#!/bin/sh
set -eu

mode="${1:-}"

if [ -z "$mode" ]; then
  echo 'usage: crypt.sh <encrypt|decrypt>' >&2
  exit 1
fi

case "$mode" in
  encrypt|decrypt) ;;
  *)
    echo "unsupported mode: $mode" >&2
    exit 1
    ;;
esac

SOPS_CONFIG_FILE="${SOPS_CONFIG_FILE:-.sops.yaml}"
SOPS_TARGET="${SOPS_TARGET:-}"
AGE_KEY_FILE="${AGE_KEY_FILE:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 が見つかりません" >&2
    exit 1
  }
}

list_path_regexes() {
  tr -d '\r' < "$SOPS_CONFIG_FILE" \
  | sed -n -E "s/^[[:space:]]*-?[[:space:]]*path_regex:[[:space:]]*['\"]?([^'\"]*)['\"]?[[:space:]]*$/\1/p"
}

list_target_files() {
  regexes="$(list_path_regexes || true)"
  [ -n "$regexes" ] || return 0

  printf '%s\n' "$regexes" | while IFS= read -r regex; do
    [ -n "$regex" ] || continue
    find . -type f | sed 's#^\./##' | grep -E "$regex" || true
  done | awk '!seen[$0]++'
}

is_encrypted_file() {
  file="$1"

  if grep -Eq '^[[:space:]]*sops[[:space:]]*:' "$file" >/dev/null 2>&1 \
    || grep -Eq '^[[:space:]]*"?sops"?[[:space:]]*:' "$file" >/dev/null 2>&1 \
    || grep -Eq '^[[:space:]]*sops_[A-Za-z0-9_]+=' "$file" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

run_sops() {
  if [ -n "$AGE_KEY_FILE" ]; then
    SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops "$@"
  else
    sops "$@"
  fi
}

process_file() {
  file="$1"

  case "$mode" in
    encrypt)
      if is_encrypted_file "$file"; then
        echo "==> skip (already encrypted): $file"
      else
        run_sops encrypt -i "$file"
      fi
      ;;
    decrypt)
      if is_encrypted_file "$file"; then
        run_sops decrypt -i "$file"
      else
        echo "==> skip (not encrypted): $file"
      fi
      ;;
  esac
}

main() {
  require_cmd sops
  require_cmd sed
  require_cmd awk
  require_cmd find
  require_cmd grep
  require_cmd tr

  if [ -n "$SOPS_TARGET" ]; then
    [ -f "$SOPS_TARGET" ] || {
      echo "ファイルが見つかりません: $SOPS_TARGET" >&2
      exit 1
    }
    process_file "$SOPS_TARGET"
    exit 0
  fi

  [ -f "$SOPS_CONFIG_FILE" ] || {
    echo "$SOPS_CONFIG_FILE が見つかりません" >&2
    exit 1
  }

  targets="$(list_target_files || true)"
  [ -n "$targets" ] || {
    echo "$SOPS_CONFIG_FILE の path_regex に一致するファイルがありません"
    exit 0
  }

  printf '%s\n' "$targets" | while IFS= read -r file; do
    [ -n "$file" ] || continue
    process_file "$file"
  done
}

main "$@"
