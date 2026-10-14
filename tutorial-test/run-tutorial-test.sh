#!/usr/bin/env bash
#
# Run an AI agent over a documentation tutorial and capture its final report.
#
# The script installs opencode, points it at the shared tester instructions and
# the selected caller-provided tutorial skill, runs the tutorial from a clean
# working directory, and validates the separate report file.
#
# Environment:
#   OPENROUTER_API_KEY    OpenRouter API key (required).
#   OPENCODE_MODEL        Model in provider/model form (required).
#   CALLER_REPO_DIR       Absolute path to the checked-out caller repository (required).
#   TUTORIAL_PATH         Tutorial path relative to CALLER_REPO_DIR (required).
#   SKILL_PATH            Tutorial skill path relative to CALLER_REPO_DIR (required).
#   SHARED_TEST_DIR       Absolute path to this shared tutorial-test directory (required).
#   RUN_DIR               Clean directory used by the agent (required).
#   TRANSCRIPT_FILE       Where to write opencode's execution transcript (required).
#   REPORT_FILE           Where the agent must write the final report (required).
#   ENV_FILE              Where to write captured environment facts (required).
#
set -euo pipefail

: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY must be set}"
: "${OPENCODE_MODEL:?OPENCODE_MODEL must be set}"
: "${CALLER_REPO_DIR:?CALLER_REPO_DIR must be set}"
: "${TUTORIAL_PATH:?TUTORIAL_PATH must point to the tutorial file to test}"
: "${SKILL_PATH:?SKILL_PATH must point to the tutorial skill}"
: "${SHARED_TEST_DIR:?SHARED_TEST_DIR must be set}"
: "${RUN_DIR:?RUN_DIR must be set}"
: "${TRANSCRIPT_FILE:?TRANSCRIPT_FILE must be set}"
: "${REPORT_FILE:?REPORT_FILE must be set}"
: "${ENV_FILE:?ENV_FILE must be set}"

realpath_in_repo() {
  local path="$1"
  local resolved
  resolved="$(realpath -m -- "${CALLER_REPO_DIR}/${path}")"
  case "${resolved}" in
    "${CALLER_REPO_DIR}"|"${CALLER_REPO_DIR}"/*) printf '%s\n' "${resolved}" ;;
    *)
      echo "::error::Path escapes the caller repository: ${path}" >&2
      exit 1
      ;;
  esac
}

CALLER_REPO_DIR="$(realpath -m -- "${CALLER_REPO_DIR}")"
SHARED_TEST_DIR="$(realpath -m -- "${SHARED_TEST_DIR}")"
mkdir -p "${RUN_DIR}" "$(dirname "${TRANSCRIPT_FILE}")" \
  "$(dirname "${REPORT_FILE}")" "$(dirname "${ENV_FILE}")"

TUTORIAL_ABS="$(realpath_in_repo "${TUTORIAL_PATH}")"
SKILL_ABS="$(realpath_in_repo "${SKILL_PATH}")"

for required_path in "${CALLER_REPO_DIR}" "${SHARED_TEST_DIR}" \
  "${TUTORIAL_ABS}" "${SKILL_ABS}" \
  "${SHARED_TEST_DIR}/opencode.json" "${SHARED_TEST_DIR}/AGENTS.md"; do
  if [ ! -e "${required_path}" ]; then
    echo "::error::Required path does not exist: ${required_path}" >&2
    exit 1
  fi
done

export OPENCODE_CONFIG="${SHARED_TEST_DIR}/opencode.json"
export TUTORIAL_TEST_AGENTS_DIR="${SHARED_TEST_DIR}"
export TUTORIAL_TEST_SKILL_PATH="${SKILL_ABS}"

echo "::group::Install opencode (snap)"
sudo snap install opencode --classic
opencode --version
echo "::endgroup::"

echo "::group::Capture environment for the report"
{
  echo "- Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo "- Runner image: ${ImageOS:-unknown} ${ImageVersion:-unknown}"
  echo "- opencode: $(opencode --version 2>/dev/null || echo unknown)"
  echo "- Model: ${OPENCODE_MODEL}"
  echo "- Tutorial: ${TUTORIAL_PATH}"
  echo "- Skill: ${SKILL_PATH}"
} | tee "${ENV_FILE}"
echo "::endgroup::"

echo "::group::Run tutorial test"
# Start from existing empty outputs so later validation and publication behave
# predictably even if the agent produces no output.
: > "${TRANSCRIPT_FILE}"
: > "${REPORT_FILE}"

PROMPT_FILE="$(mktemp)"
cat > "${PROMPT_FILE}" <<EOF
Follow the tutorial at "${TUTORIAL_ABS}" step by step, exactly as a reader
would, on this machine. Execute every command it contains in order, in your
shell, from your current working directory.

Apply the general tester behaviour in "${TUTORIAL_TEST_AGENTS_DIR}/AGENTS.md"
and the tutorial-specific knowledge in "${TUTORIAL_TEST_SKILL_PATH}".

At the end, write the final Markdown report to "${REPORT_FILE}". The file must
start with exactly one result line: "## Result: PASS", "## Result: WARN", or
"## Result: FAIL". Then include "## Steps performed", "## Findings", and
"## Suggested changes" sections, in that order. Do not include an
"## Environment" section.
EOF

set +e
(
  cd "${RUN_DIR}"
  opencode run --pure --auto --model "${OPENCODE_MODEL}" "$(cat "${PROMPT_FILE}")"
) > >(tee "${TRANSCRIPT_FILE}") 2>&1
OPENCODE_EXIT=$?
set -e
rm -f "${PROMPT_FILE}"

if [ "${OPENCODE_EXIT}" -ne 0 ]; then
  echo "::warning::opencode run exited with status ${OPENCODE_EXIT}; continuing so the failure can be reported."
fi
echo "::endgroup::"

RESULT=""
if [ -s "${REPORT_FILE}" ]; then
  FIRST_LINE="$(head -n 1 "${REPORT_FILE}" | tr -d '\r')"
  case "${FIRST_LINE}" in
    '## Result: PASS') RESULT="pass" ;;
    '## Result: WARN') RESULT="warn" ;;
    '## Result: FAIL') RESULT="fail" ;;
  esac

  if [ -z "${RESULT}" ] && grep -qE '^## Result:[[:space:]]*(PASS|WARN|FAIL)[[:space:]]*$' "${REPORT_FILE}"; then
    echo "::warning::The report's result line is not the first line; treating the report as malformed."
  fi

  if [ -n "${RESULT}" ]; then
    for heading in '## Steps performed' '## Findings' '## Suggested changes'; do
      if ! grep -qF "${heading}" "${REPORT_FILE}"; then
        echo "::warning::The report is missing the required section '${heading}'."
        RESULT=""
        break
      fi
    done
  fi
fi

if [ -z "${RESULT}" ]; then
  echo "::warning::No valid final report was produced; reporting a tester failure."
  {
    echo '## Result: FAIL'
    echo
    echo '## Steps performed'
    echo '1. Run the AI tutorial tester — failed.'
    echo
    echo '## Findings'
    echo '- The AI tester did not produce a valid final report. Inspect the execution transcript and job summary for the underlying error.'
    echo
    echo '## Suggested changes'
    echo '- Inspect the tutorial-test workflow logs before treating this as a tutorial regression.'
  } > "${REPORT_FILE}"
  RESULT="fail"
fi

{
  echo "RESULT=${RESULT}"
  echo "TRANSCRIPT_FILE=${TRANSCRIPT_FILE}"
  echo "REPORT_FILE=${REPORT_FILE}"
  echo "ENV_FILE=${ENV_FILE}"
} >> "${GITHUB_OUTPUT}"
