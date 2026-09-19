#!/usr/bin/env bash
set -euo pipefail

mobile=false
if [[ "${1:-}" == "--mobile" ]]; then
  mobile=true
  shift
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$project_root/.env" ]]; then
  echo 'Missing .env in the project root.' >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$project_root/.env"
set +a

: "${SUPABASE_URL:?Missing SUPABASE_URL in .env}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY in .env}"

defines=(
  "--dart-define=SUPABASE_URL=$SUPABASE_URL"
  "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
)
if [[ "$mobile" == false && -n "${AUTH_REDIRECT_URL:-}" ]]; then
  defines+=("--dart-define=AUTH_REDIRECT_URL=$AUTH_REDIRECT_URL")
fi

cd "$project_root"
exec flutter run "$@" "${defines[@]}"
