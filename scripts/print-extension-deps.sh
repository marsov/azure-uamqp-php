#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXTENSION_NAME="uamqpphpbinding.so"

PHP_MAJOR_VERSION="${PHUAMQP_PHP_MAJOR_VERSION:-${PHP_MAJOR_VERSION:-8.3}}"
PHP_CONFIG_BIN="php${PHP_MAJOR_VERSION}-config"
if ! command -v "${PHP_CONFIG_BIN}" >/dev/null 2>&1; then
  PHP_CONFIG_BIN="php-config"
fi

DEFAULT_EXTENSION_PATH="${PROJECT_ROOT}/${EXTENSION_NAME}"
EXTENSION_PATH="${1:-${DEFAULT_EXTENSION_PATH}}"

if [[ ! -f "${EXTENSION_PATH}" ]]; then
  echo "Extension not found: ${EXTENSION_PATH}" >&2
  echo "Build the extension first, or pass the path as the first argument." >&2
  exit 1
fi

PHP_API="$(${PHP_CONFIG_BIN} --phpapi 2>/dev/null || true)"
PHP_COMMON_PACKAGE="php${PHP_MAJOR_VERSION}-common"

mapfile -t dependency_paths < <(
  ldd "${EXTENSION_PATH}" | awk '
    /not found/ { print "MISSING\t" $1; next }
    $1 ~ /^\// { print "PATH\t" $1; next }
    $2 == "=>" && $3 ~ /^\// { print "PATH\t" $3; next }
    $3 == "=>" && $4 ~ /^\// { print "PATH\t" $4; next }
  ' | sort -u
)

if [[ ${#dependency_paths[@]} -eq 0 ]]; then
  echo "No shared-library dependencies found for ${EXTENSION_PATH}."
  exit 0
fi

declare -A packages=()
declare -A seen_paths=()
missing=0

printf 'Extension: %s\n' "${EXTENSION_PATH}"
[[ -n "${PHP_API}" ]] && printf 'PHP API: %s\n' "${PHP_API}"
printf 'PHP package: %s\n\n' "${PHP_COMMON_PACKAGE}"
printf '%-44s %-48s %s\n' "Library" "System path" "Debian package(s)"
printf '%-44s %-48s %s\n' "-------" "----------" "----------------"

for entry in "${dependency_paths[@]}"; do
  kind="${entry%%$'\t'*}"
  value="${entry#*$'\t'}"

  [[ -n "${seen_paths[${kind}:${value}]:-}" ]] && continue
  seen_paths["${kind}:${value}"]=1

  if [[ "${kind}" == "MISSING" ]]; then
    missing=1
    printf '%-44s %-48s %s\n' "${value}" "not found" "MISSING"
    continue
  fi

  package_names="$(dpkg-query -S "${value}" 2>/dev/null | cut -d: -f1 | sort -u | paste -sd, - || true)"
  if [[ -z "${package_names}" ]]; then
    package_names="(custom build / bundled by package)"
  else
    IFS=',' read -r -a package_array <<< "${package_names}"
    for package in "${package_array[@]}"; do
      packages["${package}"]=1
    done
  fi

  printf '%-44s %-48s %s\n' "$(basename "${value}")" "${value}" "${package_names}"
done

printf '\nRequired Debian packages:\n'
{
  printf '%s\n' "${PHP_COMMON_PACKAGE}"
  for package in "${!packages[@]}"; do
    printf '%s\n' "${package}"
  done
} | sort -u | sed 's/^/  - /'

if [[ "${missing}" -eq 1 ]]; then
  echo
  echo "One or more dependencies are missing from the current system." >&2
  exit 1
fi
