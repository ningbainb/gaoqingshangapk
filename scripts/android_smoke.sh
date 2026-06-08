#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-com.local.aichathelper}"
MAIN_ACTIVITY="${MAIN_ACTIVITY:-${PACKAGE_NAME}/.MainActivity}"
APK_PATH="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
SMOKE_TEXT="${SMOKE_TEXT:-AI Reply adb smoke text}"
SMOKE_TEXT_SECOND="${SMOKE_TEXT_SECOND:-AI Reply adb smoke follow up}"
WAIT_SECONDS="${WAIT_SECONDS:-2}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is required but was not found on PATH." >&2
  exit 1
fi

if [[ ! -f "${APK_PATH}" ]]; then
  echo "APK not found: ${APK_PATH}" >&2
  echo "Build one first, for example: flutter build apk --debug" >&2
  exit 1
fi

adb_args=()
if [[ -n "${ADB_SERIAL:-}" ]]; then
  adb_args=(-s "${ADB_SERIAL}")
fi

adb_cmd() {
  adb "${adb_args[@]}" "$@"
}

device_count="$(adb devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
if [[ -z "${ADB_SERIAL:-}" && "${device_count}" != "1" ]]; then
  echo "Expected exactly one adb device, found ${device_count}." >&2
  echo "Set ADB_SERIAL=<serial> when multiple devices are connected." >&2
  adb devices -l >&2
  exit 1
fi

echo "Installing ${APK_PATH}..."
adb_cmd install -r "${APK_PATH}" >/dev/null

assert_launcher_shortcut() {
  local shortcuts expected
  echo "Smoke: launcher app shortcut"
  if ! shortcuts="$(adb_cmd shell cmd shortcut get-shortcuts "${PACKAGE_NAME}" 2>/dev/null | tr -d '\r')"; then
    echo "Unable to inspect launcher shortcuts for ${PACKAGE_NAME}." >&2
    exit 1
  fi
  for expected in \
    "id=quick_image_reply" \
    "shortLabel=处理截图" \
    "dat=aichathelper://quick-image" \
    "cmp=${PACKAGE_NAME}/.MainActivity"; do
    if ! printf '%s\n' "${shortcuts}" | grep -F "${expected}" >/dev/null; then
      echo "Launcher shortcut check missed: ${expected}" >&2
      printf '%s\n' "${shortcuts}" >&2
      exit 1
    fi
  done
}

assert_launcher_shortcut

assert_native_components() {
  local package_dump expected
  echo "Smoke: native Android components"
  if ! package_dump="$(adb_cmd shell dumpsys package "${PACKAGE_NAME}" 2>/dev/null | tr -d '\r')"; then
    echo "Unable to inspect installed package ${PACKAGE_NAME}." >&2
    exit 1
  fi
  assert_component_registered "${package_dump}" "MainActivity"
  assert_component_registered "${package_dump}" "FloatingCaptureService"
  assert_component_registered "${package_dump}" "ProjectionForegroundService"
  assert_component_registered "${package_dump}" "ScreenshotAccessibilityService"

  for expected in \
    "android.permission.BIND_ACCESSIBILITY_SERVICE" \
    "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" \
    "android.permission.SYSTEM_ALERT_WINDOW" \
    "android.permission.POST_NOTIFICATIONS"; do
    assert_dump_contains "${package_dump}" "${expected}" "Installed package check missed"
  done
}

assert_component_registered() {
  local dump="$1"
  local class_name="$2"
  if ! component_is_registered "${dump}" "${class_name}"; then
    echo "Installed package check missed component: ${class_name}" >&2
    exit 1
  fi
}

component_is_registered() {
  local dump="$1"
  local class_name="$2"
  printf '%s\n' "${dump}" | grep -E \
    "(${PACKAGE_NAME}/\\.${class_name}|${PACKAGE_NAME}/${PACKAGE_NAME}\\.${class_name})" >/dev/null
}

assert_dump_contains() {
  local dump="$1"
  local expected="$2"
  local message="$3"
  if ! printf '%s\n' "${dump}" | grep -F "${expected}" >/dev/null; then
    echo "${message}: ${expected}" >&2
    exit 1
  fi
}

assert_native_components

echo "Clearing logcat..."
adb_cmd logcat -c

sleep_step() {
  sleep "${WAIT_SECONDS}"
}

assert_running() {
  if [[ -z "$(current_pid)" ]]; then
    echo "App process is not running after: $1" >&2
    exit 1
  fi
}

current_pid() {
  adb_cmd shell pidof "${PACKAGE_NAME}" 2>/dev/null |
    tr -d '\r' |
    awk '{ print $1 }'
}

run_intent() {
  local label="$1"
  shift
  echo "Smoke: ${label}"
  adb_cmd shell am start "$@" >/dev/null
  sleep_step
  assert_running "${label}"
}

run_intent "cold launch" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER

run_intent "settings API deeplink" \
  -a android.intent.action.VIEW \
  -d "aichathelper://settings/api"

run_intent "text ACTION_SEND" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.SEND \
  -t "text/plain" \
  --es android.intent.extra.TEXT "${SMOKE_TEXT}"

escape_am_array_item() {
  local value="$1"
  printf '%s' "${value//,/\\,}"
}

base64_decode_file() {
  local output="$1"
  if base64 --decode >"${output}" 2>/dev/null; then
    return
  fi
  base64 -D >"${output}"
}

smoke_text_array="$(escape_am_array_item "${SMOKE_TEXT}"),$(escape_am_array_item "${SMOKE_TEXT_SECOND}")"
run_intent "text ACTION_SEND_MULTIPLE" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.SEND_MULTIPLE \
  -t "text/plain" \
  --esa android.intent.extra.TEXT "${smoke_text_array}"

run_intent "selected text ACTION_PROCESS_TEXT" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.PROCESS_TEXT \
  -t "text/plain" \
  --es android.intent.extra.PROCESS_TEXT "${SMOKE_TEXT}" \
  --ez android.intent.extra.PROCESS_TEXT_READONLY true

tmp_png="$(mktemp "${TMPDIR:-/tmp}/ai-reply-smoke.XXXXXX.png")"
device_png="/sdcard/Download/ai-reply-smoke.png"
pushed_device_png=false
cleanup_smoke_files() {
  rm -f "${tmp_png}"
  if [[ "${pushed_device_png}" == "true" ]]; then
    adb_cmd shell rm -f "${device_png}" >/dev/null 2>&1 || true
  fi
}
trap cleanup_smoke_files EXIT
printf '%s' \
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=' |
  base64_decode_file "${tmp_png}"
adb_cmd push "${tmp_png}" "${device_png}" >/dev/null
pushed_device_png=true

run_intent "image ACTION_SEND file URI" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.SEND \
  -t "image/png" \
  --eu android.intent.extra.STREAM "file://${device_png}"

run_intent "image ACTION_SEND untyped file URI" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.SEND \
  --eu android.intent.extra.STREAM "file://${device_png}"

run_intent "image ACTION_VIEW file URI" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.VIEW \
  -t "image/png" \
  -d "file://${device_png}"

run_intent "image ACTION_VIEW untyped file URI" \
  -n "${MAIN_ACTIVITY}" \
  -a android.intent.action.VIEW \
  -d "file://${device_png}"

run_intent "quick URL fallback route" \
  -a android.intent.action.VIEW \
  -d "aichathelper://quick-image"

echo "Checking recent logcat for app crash markers..."
app_pid="$(current_pid)"
if [[ -n "${app_pid}" ]] && adb_cmd logcat --help 2>&1 | grep -q -- "--pid"; then
  recent_logcat="$(adb_cmd logcat -d -v brief --pid="${app_pid}")"
else
  recent_logcat="$(adb_cmd logcat -d -v brief | grep -F "${PACKAGE_NAME}" || true)"
fi
if printf '%s\n' "${recent_logcat}" |
  grep -E "(FATAL EXCEPTION|AndroidRuntime|Force finishing|ANR|crash|Exception)" >/dev/null; then
  printf '%s\n' "${recent_logcat}" |
    grep -E "(FATAL EXCEPTION|AndroidRuntime|Force finishing|ANR|crash|Exception)" >&2
  exit 1
fi

echo "Android smoke passed for ${PACKAGE_NAME}."
