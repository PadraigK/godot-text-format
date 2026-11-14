// The two functions of Zstandard's decoder this package calls, as zstd.h declares them.
// zstddeclib.c beside this folder is Zstandard 1.5.7's own single-file decoder, unchanged:
// build/single_file_libs/combine.py -r ../../lib -x legacy/zstd_legacy.h -o zstddeclib.c zstddeclib-in.c
// in https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz, under the BSD
// licence in LICENSE.
#ifndef ZSTD_DECODER_H
#define ZSTD_DECODER_H

#include <stddef.h>

// Decompresses one frame of `compressedSize` bytes at `src` into `dst`, which holds
// `dstCapacity` bytes. Returns the number of bytes written, or an error code that
// ZSTD_isError recognises.
size_t ZSTD_decompress(void *dst, size_t dstCapacity, const void *src, size_t compressedSize);

// Whether a size a Zstandard function returned is an error code.
unsigned ZSTD_isError(size_t code);

#endif
