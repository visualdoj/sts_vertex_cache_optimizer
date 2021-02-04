# sts vertex cache oprimizer

Pascal port of [C version](https://github.com/Sigkill79/sts), public domain
library that does vertex optimization for GPU cache, as described in
[Tom Forsyth's Linear-Speed Vertex Cache Optimisation](https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html).

# Documentation

The triangle index algorithm implemented here was developed by Tom Forsyth.
Read more about the algorithm here:

[https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html](https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html)

Vertex indices input has to be triangles, and the resulting optimized indices
will be stored in same index buffer.  The default cache inout size is 32, but
the algorithm is universially good for all cache sizes regardless of the input
cache size. So, if you don't know the cache size you are optimizing for, this
is AFAIK as good as you can get.

However, if you know the cache size you are optimizing for then you can change
the default cache size.

The algorithm is fast and runs in linear time, and is within a few percentages
of the best known alternative algorithm (Tom Forsyth´s words).

Example:

```pascal
uses
  sts_vertex_cache_optimizer;

 ...

  Writeln('Before: ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
  stsvco_optimize(@indices[0], Length(indices), numVertices);
  Writeln('After:  ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
```
