#!/usr/bin/env bash
#
# Publish a tutorial-test report: always write it to the job summary and, when
# the result is WARN or FAIL, open an issue in the caller repository.
#
# Environment:
#   RESULT          pass | warn | fail (required).
#   REPORT_FILE     Path to the final markdown report (required).
#   ENV_FILE        Path to the captured environment details (required).
#   TUTORIAL_PATH   Path of the tutorial that was tested (required).
#   OPENCODE_MODEL  Model used (for the report metadata).
#   ISSUE_LABELS    Optional comma-separated issue labels (default: tutorial-test).
#   GH_TOKEN        Token used by `gh` to open the issue (required when failing).
#
set -euo pipefail

: "${RESULT:?RESULT must be set (pass|warn|fail)}"
: "${REPORT_FILE:?REPORT_FILE must be set}"
: "${ENV_FILE:?ENV_FILE must be set}"
: "${TUTORIAL_PATH:?TUTORIAL_PATH must be set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

TUTORIAL_NAME="$(basename "${TUTORIAL_PATH}")"
TUTORIAL_NAME="${TUTORIAL_NAME%.*}"
DATE_UTC="$(date -u '+%Y-%m-%d %H:%M UTC')"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}"
ISSUE_LABELS="${ISSUE_LABELS:-tutorial-test}"

print_report() {
  if [ -f "${REPORT_FILE}" ] && [ -s "${REPORT_FILE}" ]; then
    cat "${REPORT_FILE}"
  else
    echo '## Result: FAIL'
    echo
    echo '## Steps performed'
    echo '1. Run the AI tutorial tester — failed.'
    echo
    echo '## Findings'
    echo '- The report file was missing or empty before publication.'
    echo
    echo '## Suggested changes'
    echo '- Inspect the tutorial-test workflow logs before treating this as a tutorial regression.'
  fi
}

print_env() {
  if [ -f "${ENV_FILE}" ] && [ -s "${ENV_FILE}" ]; then
    sed 's/^/  /' "${ENV_FILE}"
  else
    echo '  - Not captured'
  fi
}

# Promote PASS to WARN when the report contains actionable suggestions. Do this
# before rendering so the summary, issue, and workflow output agree.
if [ "${RESULT}" = "pass" ] && [ -f "${REPORT_FILE}" ] && [ -s "${REPORT_FILE}" ]; then
  SUGGESTIONS="$(awk '/^## Suggested changes/{found=1; next} /^## /{found=0} found' "${REPORT_FILE}" | tr -d '[:space:]')"
  case "${SUGGESTIONS}" in
    ''|'-None.'|'None.'|'-None'|'None') : ;;
    *)
      echo "PASS report contains suggested changes; promoting RESULT to 'warn'."
      RESULT="warn"
      ;;
  esac
fi

echo "RESULT=${RESULT}"
echo "RESULT=${RESULT}" >> "${GITHUB_OUTPUT}"

{
  echo "# Tutorial test report"
  echo
  echo "- **Tutorial:** \`${TUTORIAL_PATH}\`"
  echo "- **Result:** ${RESULT}"
  echo "- **Model:** ${OPENCODE_MODEL:-unknown}"
  echo "- **Date:** ${DATE_UTC}"
  echo "- **Run:** ${RUN_URL}"
  echo "- **Environment:**"
  print_env
  echo
  print_report
} >> "${GITHUB_STEP_SUMMARY}"

if [ "${RESULT}" != "fail" ] && [ "${RESULT}" != "warn" ]; then
  echo "Tutorial test result is '${RESULT}'; not opening an issue."
  exit 0
fi

if [ "${RESULT}" = "fail" ]; then
  ISSUE_TITLE="Tutorial test failing: ${TUTORIAL_NAME}"
  ISSUE_INTRO="The automated tutorial test for **${TUTORIAL_NAME}** found problems."
else
  ISSUE_TITLE="Tutorial test feedback: ${TUTORIAL_NAME}"
  ISSUE_INTRO="The automated tutorial test for **${TUTORIAL_NAME}** completed, but found things worth changing."
fi
echo "Result is '${RESULT}'; opening a GitHub issue in ${GITHUB_REPOSITORY}."

ISSUE_BODY_FILE="$(mktemp)"
{
  echo "${ISSUE_INTRO}"
  echo
  echo "- **Tutorial:** \`${TUTORIAL_PATH}\`"
  echo "- **Date:** ${DATE_UTC}"
  echo "- **Model:** ${OPENCODE_MODEL:-unknown}"
  echo "- **CI run:** ${RUN_URL}"
  echo "- **Environment:**"
  print_env
  echo
  print_report
  echo
  echo "---"
  echo "_Filed automatically by the tutorial-test reusable workflow. Keep"
  echo "tutorial-specific testing knowledge in the caller repository's tutorial"
  echo "skill so known behaviour is not reported again._"
} > "${ISSUE_BODY_FILE}"

read -r -a LABELS <<< "${ISSUE_LABELS//,/ }"
if [ "${#LABELS[@]}" -gt 0 ]; then
  for LABEL in "${LABELS[@]}"; do
    gh label create "${LABEL}" --repo "${GITHUB_REPOSITORY}" --force >/dev/null 2>&1 || true
  done
fi

ISSUE_ARGS=(issue create --repo "${GITHUB_REPOSITORY}" --title "${ISSUE_TITLE}" --body-file "${ISSUE_BODY_FILE}")
for LABEL in "${LABELS[@]}"; do
  ISSUE_ARGS+=(--label "${LABEL}")
done

if ISSUE_URL="$(gh "${ISSUE_ARGS[@]}")"; then
  echo "Opened issue: ${ISSUE_URL}"
  echo "ISSUE_URL=${ISSUE_URL}" >> "${GITHUB_OUTPUT}"
else
  echo "::error::Failed to open the GitHub issue for the tutorial test." >&2
  rm -f "${ISSUE_BODY_FILE}"
  exit 1
fi

rm -f "${ISSUE_BODY_FILE}"
