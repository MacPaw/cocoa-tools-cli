#!/bin/sh

set -Eeo pipefail

REPOSITORY_ROOT_DIR="${REPOSITORY_ROOT_DIR:-"$(git rev-parse --show-toplevel 2> /dev/null || pwd)"}"

SECRET_VALUE_1="$(openssl rand -hex 16 | tr -d '[:space:]')"
SECRET_VALUE_2="$(openssl rand -hex 16 | tr -d '[:space:]')"

op_create_test_secrets() {
  echo "Creating test secrets"
  op item create \
    --category password \
    --vault personal \
    --title '[TEST] mpct.import-secrets.shared-item' \
    --url 'https://test.com' \
    "Test Section.item1-secret[password]=${SECRET_VALUE_1}" \
    $'Test Section.item1-multiline[text]=test-item1\nmultiline-value'

  op item create \
    --category password \
    --vault personal \
    --title '[TEST] mpct.import-secrets.database-item' \
    --url 'https://test.com' \
    "Test Section.item2-secret[password]=${SECRET_VALUE_2}"
}

op_remove_test_secrets() {
  echo "Removing test secrets"
  op item delete '[TEST] mpct.import-secrets.shared-item' --vault personal || true
  op item delete '[TEST] mpct.import-secrets.database-item' --vault personal || true
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

  if [ -z "${TEST_MPCT_SECRET1_OP_ONLY}" ]; then
    echo "TEST_MPCT_SECRET1_OP_ONLY is not present"
    exit 1
  elif [ "${TEST_MPCT_SECRET1_OP_ONLY}" != "${SECRET_VALUE_1}" ]; then
    echo "TEST_MPCT_SECRET1_OP_ONLY is not equal to '${SECRET_VALUE_1}'"
    echo "TEST_MPCT_SECRET1_OP_ONLY: '${TEST_MPCT_SECRET1_OP_ONLY}'"
    exit 1
  else
    echo "✅ TEST_MPCT_SECRET1_OP_ONLY: '${TEST_MPCT_SECRET1_OP_ONLY}'"
  fi

  if [ -z "${TEST_MPCT_SECRET2_MULTILINE}" ]; then
    echo "TEST_MPCT_SECRET2_MULTILINE is not present"
    exit 1
  elif [ "${TEST_MPCT_SECRET2_MULTILINE}" != $'test-item1\nmultiline-value' ]; then
    printf "TEST_MPCT_SECRET2_MULTILINE is not equal to 'test-item1\nmultiline-value'"
    echo "TEST_MPCT_SECRET2_MULTILINE: '${TEST_MPCT_SECRET2_MULTILINE}'"
    exit 1
  else
    echo "✅ TEST_MPCT_SECRET2_MULTILINE: '${TEST_MPCT_SECRET2_MULTILINE}'"
  fi

  if [ -z "${TEST_MPCT_SECRET3_OP_AND_FAKE}" ]; then
    echo "TEST_MPCT_SECRET3_OP_AND_FAKE is not present"
    exit 1
  elif [ "${TEST_MPCT_SECRET3_OP_AND_FAKE}" != "${SECRET_VALUE_2}" ]; then
    echo "TEST_MPCT_SECRET3_OP_AND_FAKE is not equal to '${SECRET_VALUE_2}'"
    echo "TEST_MPCT_SECRET3_OP_AND_FAKE: '${TEST_MPCT_SECRET3_OP_AND_FAKE}'"
    exit 1
  else
    echo "✅ TEST_MPCT_SECRET3_OP_AND_FAKE: '${TEST_MPCT_SECRET3_OP_AND_FAKE}'"
  fi

  echo "✅ All secrets are present and correct"
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
