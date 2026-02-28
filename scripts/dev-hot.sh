#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BIN="$BUILD_DIR/some-app"
PKG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig:${PKG_CONFIG_PATH:-}"

# Polling interval in seconds (used only in polling mode).
INTERVAL="${HOT_RELOAD_INTERVAL:-0.25}"
APP_PID=""
LAST_STATE=""
LAST_MESON_STATE=""
WATCH_MODE="poll"

if command -v fswatch >/dev/null 2>&1; then
  WATCH_MODE="fswatch"
fi

watch_targets() {
  find "$ROOT_DIR/src" -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' -o -name '*.hpp' -o -name '*.h' \)
  printf '%s\n' "$ROOT_DIR/meson.build"
}

calc_state() {
  local files
  files="$(watch_targets | sort)"
  if [[ -z "$files" ]]; then
    echo "empty"
    return
  fi

  # Combine path + mtime + size to detect changes quickly.
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    stat -f '%N %m %z' "$f"
  done <<< "$files" | shasum -a 256 | awk '{print $1}'
}

setup_build() {
  if [[ ! -d "$BUILD_DIR" ]]; then
    PKG_CONFIG_PATH="$PKG_PATH" meson setup "$BUILD_DIR" >/dev/null
    LAST_MESON_STATE="$(stat -f '%m %z' "$ROOT_DIR/meson.build" 2>/dev/null || echo '')"
    return
  fi

  local meson_state
  meson_state="$(stat -f '%m %z' "$ROOT_DIR/meson.build" 2>/dev/null || echo '')"
  if [[ "$meson_state" != "$LAST_MESON_STATE" ]]; then
    PKG_CONFIG_PATH="$PKG_PATH" meson setup "$BUILD_DIR" --reconfigure >/dev/null 2>&1 || \
    PKG_CONFIG_PATH="$PKG_PATH" meson setup "$BUILD_DIR" >/dev/null
    LAST_MESON_STATE="$meson_state"
  fi
}

build_app() {
  echo "[hot] building..."
  if PKG_CONFIG_PATH="$PKG_PATH" meson compile -C "$BUILD_DIR" some-app; then
    echo "[hot] build OK"
    return 0
  fi

  echo "[hot] build failed; waiting for next change"
  return 1
}

stop_app() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  APP_PID=""
}

start_app() {
  if [[ ! -x "$APP_BIN" ]]; then
    echo "[hot] executable not found: $APP_BIN"
    return 1
  fi

  echo "[hot] starting app"
  "$APP_BIN" &
  APP_PID="$!"
}

cleanup() {
  stop_app
}
trap cleanup EXIT INT TERM

main() {
  cd "$ROOT_DIR"
  echo "[hot] project: $ROOT_DIR (watch mode: $WATCH_MODE)"

  setup_build
  if build_app; then
    start_app
  fi

  LAST_STATE="$(calc_state)"

  while true; do
    if [[ "$WATCH_MODE" == "fswatch" ]]; then
      fswatch -1 -r "$ROOT_DIR/src" "$ROOT_DIR/meson.build" >/dev/null
    else
      sleep "$INTERVAL"
    fi

    local state
    state="$(calc_state)"
    if [[ "$state" == "$LAST_STATE" ]]; then
      continue
    fi

    LAST_STATE="$state"
    echo "[hot] change detected"
    setup_build
    if build_app; then
      stop_app
      start_app
    fi
  done
}

main
