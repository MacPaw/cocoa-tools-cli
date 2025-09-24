#!/usr/bin/env bash

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"

ITEM1_SECRET_VALUE="$(openssl rand -hex 16 | tr -d '[:space:]')"
ITEM1_MULTILINE_VALUE=$'test-item1\nmultiline value'
ITEM2_SECRET_VALUE="$(openssl rand -hex 16 | tr -d '[:space:]')"
ITEM2_MULTILINE_VALUE=$'test-item2\nmultiline value'

DATABASE_ITEM_SECRET_VALUE="$(openssl rand -hex 16 | tr -d '[:space:]')"

op_create_test_secrets() {
  echo "Creating test secrets"
  op item create \
    --category password \
    --vault personal \
    --title '[TEST] mpct.import-secrets.shared-item' \
    --url 'https://test.com' \
    "Test Section.item1-secret[password]=${ITEM1_SECRET_VALUE}" \
    "Test Section.item1-multiline[text]="$"${ITEM1_MULTILINE_VALUE}"

  op item create \
    --category password \
    --vault personal \
    --title '[TEST] mpct.import-secrets.database-item' \
    --url 'https://test.com' \
    "Test Section.db password[password]=${DATABASE_ITEM_SECRET_VALUE}"

  op item create \
    --category password \
    --vault personal \
    --title '[TEST] mpct.import-secrets.shared-item2' \
    --url 'https://test.com' \
    "Test Section.item2-secret[password]=${ITEM2_SECRET_VALUE}" \
    "Test Section.item2-multiline[text]="$"${ITEM2_MULTILINE_VALUE}"
}

op_remove_test_secrets() {
  echo "Removing test secrets"
  op item delete '[TEST] mpct.import-secrets.shared-item' --vault personal || true
  op item delete '[TEST] mpct.import-secrets.database-item' --vault personal || true
  op item delete '[TEST] mpct.import-secrets.shared-item2' --vault personal || true
}

function op_validate_secret() {
  local SECRET_NAME EXPECTED_SECRET_VALUE CURRENT_SECRET_VALUE
  SECRET_NAME="${1}"
  EXPECTED_SECRET_VALUE="${2}"
  CURRENT_SECRET_VALUE="${!SECRET_NAME}"

  if [ -z "${CURRENT_SECRET_VALUE}" ]; then
    echo "❌ ${SECRET_NAME} is not present"
    EXIT_CODE=1
  elif [ "${CURRENT_SECRET_VALUE}" != "${EXPECTED_SECRET_VALUE}" ]; then
    echo "❌ ${SECRET_NAME} is not equal to '${EXPECTED_SECRET_VALUE}'"
    echo "  ${SECRET_NAME}: '${CURRENT_SECRET_VALUE}'"
    EXIT_CODE=1
  else
    echo "✅ ${SECRET_NAME}: '"$"${CURRENT_SECRET_VALUE}""'"
  fi
}

op_run_tests() {

  echo "Building mpct cli..."
  ./scripts/tools/swift/swift.sh --action=build -- --product mpct

  op_remove_test_secrets > /dev/null 2>&1
  op_create_test_secrets

  echo "Running mpct secrets export command..."
  RESULT="$("./.build/$(uname -m)-apple-macosx/debug/mpct" \
    secrets export \
    --config "$(dirname "${0}")/.import-secrets.yaml" \
    --destination stdout \
    --source op || echo "Error: $?")"

  op_remove_test_secrets

  echo $'\nmpct secrets export result:\n'"${RESULT}"$'\n'

  echo "Evaluating result"
  if ! eval "${RESULT}"; then
    echo "Error: $?"
    echo "Result: ${RESULT}"
    exit 1
  fi

  echo "Checking if all secrets are present and correct"

  op_validate_secret "TEST_OP_SHARED_ITEM_SINGLE_LABEL_item1_secret" "${ITEM1_SECRET_VALUE}"

  op_validate_secret "TEST_OP_SHARED_ITEM_SINGLE_LABEL_MULTILINE_item1_multiline" "${ITEM1_MULTILINE_VALUE}"

  op_validate_secret "TEST_OP_DATABASE_ITEM_db_password" "${DATABASE_ITEM_SECRET_VALUE}"

  op_validate_secret "TEST_OP_SHARED_ITEM2_ALL_LABELS_item2_secret" "${ITEM2_SECRET_VALUE}"
  op_validate_secret "TEST_OP_SHARED_ITEM2_ALL_LABELS_item2_multiline" "${ITEM2_MULTILINE_VALUE}"

  op_validate_secret "RENAMED_ITEM2_SECRET" "${ITEM2_SECRET_VALUE}"
  op_validate_secret "RENAMED_ITEM2_MULTILINE" "${ITEM2_MULTILINE_VALUE}"

  if [ "${EXIT_CODE}" != "1" ]; then
    echo "✅ All secrets are present and correct"
  else
    exit "${EXIT_CODE}"
  fi
}

OPTIND=

die() {
  echo "${*}" >&2
  exit 2
} # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --${OPT} option"; fi; }

while getopts "c:r:-:" OPTSPEC; do

  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPTSPEC" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPTSPEC="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPTSPEC"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"          # if long option argument, remove assigning `=`
  fi

  case "${OPTSPEC}" in
    create-test-secrets)
      op_create_test_secrets
      ;;
    remove-test-secrets)
      op_remove_test_secrets
      ;;
    test)
      op_run_tests
      ;;
    *)
      echo "Unknown option: ${OPTSPEC}" >&2
      exit 1
      ;;
  esac
done
