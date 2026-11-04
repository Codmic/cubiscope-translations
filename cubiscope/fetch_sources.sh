#!/bin/sh
# Fetches the offline translation engine's sources at a pinned commit and applies our patches.
#
# Upstream: Mozilla's in-repo bergamot-translator (mozilla/translations, inference/), MPL-2.0, with
# its Marian fork (MIT) and the third-party code it needs. Only the submodules the Android build
# uses are fetched; the training pipeline's submodules (kenlm, fast_align, emsdk, ...) are not.
#
# The result lands in native/bergamot/upstream/ (git-ignored). Gradle's CMake build reads it from
# there; run this once after cloning, and again whenever UPSTREAM_COMMIT or patches/ change.
#
# The patches are also what we publish under MPL-2.0 (see docs/archive/OFFLINE_TRANSLATION_PLAN.md
# §6): keep each one small and self-describing.
set -eu

UPSTREAM_URL=https://github.com/mozilla/translations
UPSTREAM_COMMIT=8eada038fd45bbf6fa58a412b22f80c79887fabc   # 2026-10-29, bergamot v0.6.0

HERE=$(cd "$(dirname "$0")" && pwd)
DEST="$HERE/upstream"
STAMP="$DEST/.cubiscope-stamp"
WANT="$UPSTREAM_COMMIT $(cat "$HERE"/patches/*.patch | sha256sum | cut -d' ' -f1)"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANT" ]; then
  echo "upstream sources already at $UPSTREAM_COMMIT with current patches"
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cd "$DEST"
git init -q
git remote add origin "$UPSTREAM_URL"
git fetch -q --depth 1 --filter=blob:none origin "$UPSTREAM_COMMIT"
git checkout -q FETCH_HEAD

git submodule update -q --init --depth 1 \
  inference/3rd_party/ssplit-cpp \
  inference/marian-fork/src/3rd_party/sentencepiece \
  inference/marian-fork/src/3rd_party/intgemm \
  inference/marian-fork/src/3rd_party/ruy \
  inference/marian-fork/src/3rd_party/simd_utils
git -C inference/marian-fork/src/3rd_party/ruy submodule update -q --init --depth 1 third_party/cpuinfo

for p in "$HERE"/patches/*.patch; do
  echo "applying $(basename "$p")"
  git apply --whitespace=nowarn "$p"
done

echo "$WANT" > "$STAMP"
echo "done: $DEST"
