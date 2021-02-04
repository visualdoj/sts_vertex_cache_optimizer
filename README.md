# sts vertex cache optimizer

Pascal port of public domain [C library](https://github.com/Sigkill79/sts) that
does vertex optimization for GPU cache, as described in
[Tom Forsyth's Linear-Speed Vertex Cache Optimisation](https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html).

# Documentation

The triangle index algorithm implemented here was developed by Tom Forsyth.
Read more about the algorithm here:

[https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html](https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html)

Vertex indices input has to be triangles, and the resulting optimized indices
will be stored in same index buffer.  The default cache input size is 32, but
the algorithm is universially good for all cache sizes regardless of the input
cache size. So, if you don't know the cache size you are optimizing for, this
is AFAIK as good as you can get.

However, if you know the cache size you are optimizing for then you can change
the default cache size.

The algorithm is fast and runs in linear time, and is within a few percentages
of the best known alternative algorithm (Tom Forsyth´s words).

```pascal
// Function that does the optimization.
// NOTE: numVertices has to equal the MAX vertex index in the indices.
procedure stsvco_optimize(
      indices: PUInt32;
      numIndices, numVertices: UInt32;
      cacheSize: UInt32 = 32);

// Function that computes ACMR (Average Cache Miss Ratio) for a given index
// list and cache size.  The function returns the average number of cache
// misses per triangle, used for measuring the performance of the cache
// optimzation (not required to do the actual optimization).
function stsvco_compute_ACMR(
      indices: PUInt32;
      numIndices, cacheSize: UInt32): Single;
```

Example:

```pascal
uses
  sts_vertex_cache_optimizer;

 ...

  Writeln('Before: ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
  stsvco_optimize(@indices[0], Length(indices), numVertices);
  Writeln('After:  ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
```
