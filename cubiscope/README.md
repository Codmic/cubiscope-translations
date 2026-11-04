# Cubiscope's build of the Firefox Translations engine

This is the source of the offline translation engine in **Cubiscope**, an Android launcher by
Codmic (package `com.codmic.cubiscope`). Its Translate applet translates text on the phone with
Mozilla's bergamot-translator and Marian, from this repository's `inference/` directory, using
Mozilla's Firefox Translations models.

This repository is a fork of [mozilla/translations](https://github.com/mozilla/translations). The
branch `cubiscope` is Mozilla's commit
[`8eada038`](https://github.com/mozilla/translations/commit/8eada038fd45bbf6fa58a412b22f80c79887fabc)
(2026-10-29, bergamot v0.6.0) plus our changes. Each released app version has a tag
`cubiscope-<version>` marking the exact source it was built from.

## Licences

Every file keeps its own licence; nothing here is relicensed. bergamot-translator is under the
Mozilla Public License 2.0 (`LICENSE` at the top of this repository), Marian under MIT, and the
third-party components under their own licences, which sit next to their sources. The rest of the
Cubiscope app is separate code and is not part of this repository.

## Our changes

Five changes are commits on the `cubiscope` branch, one per change. Two change files inside git
submodules (SentencePiece and ssplit-cpp), which cannot be committed here, so all seven are also
kept as patch files in [`patches/`](patches/):

| Patch | File (licence) | Why |
|---|---|---|
| 0001 | bergamot `inference/src/translator/translation_model.cpp` (MPL-2.0) | Free the raw model bytes right after the scorers are built instead of after the first forward pass: −31 MB peak per model |
| 0002 | Marian `src/graph/node_initializers.cpp` (MIT) | Release each parsed weight once it is copied into its tensor: −19 MB peak; output byte-identical |
| 0003 | pathie-cpp `src/path.cpp`, `src/pathie.cpp` (BSD) | `glob()` and `iconv()` exist on Android only from API 28; the app supports API 26 |
| 0004 | SentencePiece `src/trainer_interface.cc` (Apache-2.0), submodule | Clang 21 rejects a `constexpr` out-of-range enum cast in training code that is never run |
| 0005 | ssplit-cpp `cmake/FindPCRE2.cmake` (Apache-2.0), submodule | Pass `CMAKE_POLICY_VERSION_MINIMUM` to the bundled PCRE2 build, which CMake 4 otherwise refuses |
| 0006 | Marian `src/common/binary.cpp`, `src/layers/generic.cpp`, `src/tensors/cpu/ruy_interface.h` (MIT) | Keep the embedding matrices int8 on ARM instead of expanding them to float32 at load: −47 MB steady per model. x86 is unchanged |
| 0007 | faiss `VectorTransform.h` (MIT) | Include `<x86intrin.h>` whenever `__SSE__` is defined; the Android x86_64 build fails on `__m128` otherwise |

## Rebuilding

[`fetch_sources.sh`](fetch_sources.sh) is the script the app's build uses: it fetches
mozilla/translations at the pinned commit with only the submodules the Android build needs, then
applies `patches/`. Run it from this folder; the tree lands in `upstream/`.

The app builds `inference/` with CMake through the Android NDK (r30), as a shared library linked
into a small JNI wrapper, with these options:

- Always: `USE_FBGEMM=OFF`, `COMPILE_CUDA=OFF`, `COMPILE_TESTS=OFF`, `SSPLIT_USE_INTERNAL_PCRE2=ON`,
  `USE_STATIC_LIBS=OFF`, `CMAKE_BUILD_TYPE=Release`.
- **arm64-v8a:** `BUILD_ARCH=armv8-a`, and `ARM FMA SSE` defined for the whole tree (Marian
  defines them only for its own directory; bergamot includes the same SIMD headers).
- **x86_64:** `BUILD_ARCH=x86-64-v2`, `USE_RUY=ON`, `USE_RUY_SGEMM=ON` (upstream expects MKL or
  OpenBLAS for float matrix products on x86; ruy replaces them).
