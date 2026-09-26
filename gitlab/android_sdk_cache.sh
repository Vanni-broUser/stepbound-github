#!/bin/sh
# The Android SDK packages Gradle installs on its own (NDK, platform, CMake)
# are missing from the Flutter image, so every signed build would download
# them again. This keeps them in the job's cache (.android-sdk-cache/, see
# gitlab/package.yml):
#
#   restore  links the cached packages into the image's SDK, and notes what
#            the SDK already has;
#   save     moves into the cache what the build installed since, and drops
#            Gradle's lock files from its cached home.
#
# Both run in the same job container: the SDK outside the project directory
# does not outlive it.
set -eu

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/opt/android-sdk-linux}}"
cache="${ANDROID_SDK_CACHE:-$CI_PROJECT_DIR/.android-sdk-cache}"
before=/tmp/android-sdk-before.txt
kinds="ndk cmake platforms build-tools"

case "${1:-}" in
  restore)
    : > "$before"
    for kind in $kinds; do
      mkdir -p "$cache/$kind" "$sdk/$kind"
      for entry in "$sdk/$kind"/*; do
        [ -e "$entry" ] && echo "$entry" >> "$before"
      done
      for cached in "$cache/$kind"/*; do
        [ -d "$cached" ] || continue
        target="$sdk/$kind/$(basename "$cached")"
        if [ ! -e "$target" ]; then
          ln -s "$cached" "$target"
          echo "SDK dalla cache: $kind/$(basename "$cached")"
        fi
      done
    done
    ;;
  save)
    for kind in $kinds; do
      for entry in "$sdk/$kind"/*; do
        # What the image had, or what came from the cache, stays where it is.
        [ -d "$entry" ] && [ ! -L "$entry" ] || continue
        grep -qxF "$entry" "$before" 2>/dev/null && continue
        [ -e "$cache/$kind/$(basename "$entry")" ] && continue
        mkdir -p "$cache/$kind"
        mv "$entry" "$cache/$kind/"
        echo "SDK in cache: $kind/$(basename "$entry")"
      done
    done
    home="${GRADLE_USER_HOME:-}"
    if [ -n "$home" ]; then
      rm -f "$home/caches/modules-2/modules-2.lock"
      rm -rf "$home"/caches/*/plugin-resolution/
    fi
    ;;
  *)
    echo "uso: $0 restore|save" >&2
    exit 2
    ;;
esac
