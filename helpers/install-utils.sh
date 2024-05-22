#!/usr/bin/env bash

set -eEuo pipefail

log() { printf -- "%s\n" "$*" >&2; }

: "${CI_PROJECT_DIR:?Missing CI_PROJECT_DIR}"
: "${PYTHON_UTILS_DIR:?Missing PYTHON_UTILS_DIR}"
command -v jq >/dev/null || { log "jq is required"; exit 1; }

[[ -d "${CI_PROJECT_DIR}/src/utils" ]] && {
  log "Python Utils already installed in ${CI_PROJECT_DIR}/src/utils"
  exit 1
}

declare build_output; build_output="$(
  log 'Building Package'
  cd "${PYTHON_UTILS_DIR}" || exit 1
  source "${PYTHON_UTILS_DIR}/.venv/bin/activate"
  rm -rf "${PYTHON_UTILS_DIR}/.cache/build" &>/dev/null || true
  install -dm0755 "${PYTHON_UTILS_DIR}/.cache/build"
  python3 -m build \
    pkg \
      --build="${PYTHON_UTILS_DIR}/.cache/build" \
      --config="${PYTHON_UTILS_DIR}/config/stable/all.yaml"
)"
log "Installing Python Utils into ${CI_PROJECT_DIR}/src/utils"
install -dm0755 "${CI_PROJECT_DIR}/src/utils"
trap 'rm -f "${CI_PROJECT_DIR}/src/utils/" &>/dev/null | true' ERR
tar \
  -xzf "$(jq -r '.artifact' <<<"${build_output}")" \
  -C "${CI_PROJECT_DIR}/src/utils" \
  --strip-components=1 \
  'utils'

log "Copying Utilities Requirements File to ${CI_PROJECT_DIR}/src/utils.requirements.txt"
trap 'rm -f "${CI_PROJECT_DIR}/src/utils.requirements.txt" &>/dev/null | true' ERR
(
  cd "$(mktemp -d)" || exit 1
  tar \
    -xzf "$(jq -r '.artifact' <<<"${build_output}")" \
    'requirements.txt'
  mv 'requirements.txt' "${CI_PROJECT_DIR}/src/utils.requirements.txt"
)

log 'Install Complete'
