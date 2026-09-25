#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
output=${1:?absolute empty output directory is required}
recipe="$root/.github/rpg-runtime/candidate_descriptor.py"
python3 "$recipe" prepare "$output"
test -n "${RETROM_EMSDK_ROOT:-}" && test -f "$RETROM_EMSDK_ROOT/emsdk_env.sh"
source "$RETROM_EMSDK_ROOT/emsdk_env.sh" >/dev/null 2>&1

mkdir -p "$root/.retrom-build"
work=$(mktemp -d "$root/.retrom-build/candidate.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/core" "$work/retroarch" "$work/EmulatorJS/data/cores" "$work/stage"
source_digest=$(python3 "$recipe" digest "$output")
python3 "$recipe" paths "$output" > "$work/paths"
tar --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$root" \
  --null --verbatim-files-from -T "$work/paths" -cf "$work/source.tar"
tar -C "$work/core" -xf "$work/source.tar"

retroarch_commit=6dd4353937ef48b6ec0bfbdbb15d1c5992d86927
git -C "$work/retroarch" init -q
git -C "$work/retroarch" remote add origin https://github.com/EmulatorJS/RetroArch.git
git -C "$work/retroarch" fetch -q --depth=1 origin "$retroarch_commit"
git -C "$work/retroarch" checkout -q --detach FETCH_HEAD
test "$(git -C "$work/retroarch" rev-parse HEAD)" = "$retroarch_commit"

export SOURCE_DATE_EPOCH=1722900000
emmake make -C "$work/core" -f Makefile clean platform=emscripten EMULATORJS_THREADS=1 > "$work/build.log" 2>&1
emmake make -C "$work/core" -j4 -f Makefile platform=emscripten EMULATORJS_THREADS=1 \
  INITIAL_HEAP=268435456 AUTO_MEMORY_GROWTH=1 >> "$work/build.log" 2>&1 || { tail -100 "$work/build.log" >&2; exit 1; }
install -m 0644 "$work/core/puae_libretro_emscripten.bc" "$work/retroarch/emulatorjs/"
(
  cd "$work/retroarch/emulatorjs"
  emmake ./build-emulatorjs.sh --threads --clean
) >> "$work/build.log" 2>&1 || { tail -100 "$work/build.log" >&2; exit 1; }
if grep -q 'undefined symbol:' "$work/build.log"; then tail -100 "$work/build.log" >&2; exit 1; fi

7z x -bd -bso0 -bsp0 -o"$work/stage" \
  "$work/EmulatorJS/data/cores/puae-thread-wasm.data" >/dev/null
test -f "$work/stage/puae_libretro.js" && test -f "$work/stage/puae_libretro.wasm"
{
  printf '%s\n\n' '# PUAE browser core license' '## PUAE'
  cat "$root/COPYING"
  printf '\n\n%s\n\n' '## EmulatorJS RetroArch frontend'
  cat "$work/retroarch/COPYING"
} > "$work/stage/license.txt"
printf '%s\n' '{"minimumEJSVersion":"4.2.3","version":"2.0.2"}' > "$work/stage/build.json"
printf '%s\n' '{"name":"puae","extensions":["adf","chd","iso"],"options":{"supportsMouse":true},"license":"COPYING","repo":"https://github.com/retrom-project/libretro-uae"}' > "$work/stage/core.json"
(
  cd "$work/stage"
  7z a -mtm=off -mta=off -mtc=off -bd -bso0 -bsp0 -t7z \
    "$output/puae-thread-wasm.data" puae_libretro.js puae_libretro.wasm build.json core.json license.txt
) >/dev/null
install -m 0644 "$work/stage/license.txt" "$output/COPYING"
gzip -n -c "$work/source.tar" > "$output/source.tar.gz"
test "$source_digest" = "$(python3 "$recipe" digest "$output")"
python3 "$recipe" finalize "$output" --core-id puae
