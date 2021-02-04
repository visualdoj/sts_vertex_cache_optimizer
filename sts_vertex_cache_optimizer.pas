unit sts_vertex_cache_optimizer;

{* sts_vertex_cache_optimizer - v0.04 - public domain triangle index optimizer
 no warranty implied; use at your own risk

 LICENSE

 See end of file for license information.

 REVISION HISTORY:

 0.04  (2020-02-04) Ported to pascal by Doj
 0.04  (2017-11-17) Fixed MSVC compatibility
 0.03  (2017-11-17) Fixed clean return on three or less vertices and/or triangles
 0.02  (2017-11-16) Initial public release
 *}

// DOCUMENTATION
//
//
// The triangle index algorithm implemented here was developed by Tom Forsyth.
// Read more about the algorithm here: https://tomforsyth1000.github.io/papers/fast_vert_cache_opt.html
//
// Vertex indices input has to be triangles, and the resulting optimized indices will be stored in same index buffer.
// The default cache inout size is 32, but the algorithm is universially good for all cache sizes regardless of
// the input cache size. So, if you don't know the cache size you are optimizing for, this is AFAIK as good
// as you can get.
//
// However, if you know the cache size you are optimizing for then you can change the default cache size.
//
// The algorithm is fast and runs in linear time, and is within a few percentages of the best known alternative
// algorithm (Tom Forsyth´s words).
//
// Example:
//
//   uses
//     sts_vertex_cache_optimizer;
//
//     ...
//
//     Writeln('Before: ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
//     stsvco_optimize(@indices[0], Length(indices), numVertices);
//     Writeln('After:  ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
//
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

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

implementation

function powf(A, B: Single): Single; inline;
begin
  Exit(Exp(B * Ln(A)));
end;

// Computes the score for a vertex with numTris using the vertex
function stsvco_valenceScore(numTris: UInt32): Single;
begin
  if numTris = 0 then
    Exit(0.0);
  Exit(2 * powf(numTris, -0.5));
end;

const
  UNDEFINED = High(UInt32);

procedure stsvco_optimize(
      indices: PUInt32;
      numIndices, numVertices: UInt32;
      cacheSize: UInt32 = 32);
type
Pvertex = ^vertex;
vertex = record
  numAdjecentTris: UInt32;
  numTrisLeft: UInt32;
  triListIndex: UInt32;
  cacheIndex: UInt32;
end;
Ptriangle = ^triangle;
triangle = record
  vertices: array[0 .. 3 - 1] of UInt32;
  drawn: Boolean;
end;

var
  vertices: Pvertex;
  numTriangles: UInt32;
  triangles: Ptriangle;
  v, t: UInt32;
  numVertToTri: UInt32;
  vertToTri: PUInt32;
  index: UInt32;
  triListIndex: UInt32;
  LRUCacheSize: UInt32;
  LRUCache: PUInt32;
  scoring: PSingle;
  i, j: UInt32;
  numIndicesDone: UInt32;
  vertexIndex: UInt32;
  scaler, scoreBase: Single;
  numTrisLeft: UInt32;
  triangleToDraw: UInt32;
  bestTriScore: Single;
  vIndex, tIndex: UInt32;
  triScore: Single;
  cacheIndex: UInt32;
  numVerticesFound: UInt32;
  topOfCacheInTri: Boolean;
  topIndex: UInt32;
begin
  Assert(numIndices mod 3 = 0); // 'Index input has to be triangles'

  if (numIndices <= 3) or (numVertices <= 3) then
    Exit;

  vertices := GetMem(numVertices * SizeOf(vertex)) ;
  assert(vertices <> nil); // 'Out of memory when allocating vertices'

  numTriangles := numIndices div 3;
  triangles := GetMem(numTriangles * SizeOf(triangle));
  assert(triangles <> nil); // 'Out of memory when allocating triangles'

  v := 0;
  while v < numVertices do begin
    vertices[v].numAdjecentTris := 0;
    vertices[v].numTrisLeft := 0;
    vertices[v].triListIndex := 0;
    vertices[v].cacheIndex := UNDEFINED;
    Inc(v);
  end;

  t := 0;
  while t < numTriangles do begin
    v := 0;
    while v < 3 do begin
      triangles[t].vertices[v] := indices[t * 3 + v];
      Inc(vertices[triangles[t].vertices[v]].numAdjecentTris);
      Inc(v);
    end;
    triangles[t].drawn := False;
    Inc(t);
  end;

  // Loop through and find index for the tri list for vertex^.tri
  v := 1;
  while v < numVertices do begin
    vertices[v].triListIndex := vertices[v - 1].triListIndex
                              + vertices[v - 1].numAdjecentTris;
    Inc(v);
  end;

  numVertToTri := vertices[numVertices - 1].triListIndex
                + vertices[numVertices - 1].numAdjecentTris;
  vertToTri := GetMem(numVertToTri * SizeOf(UInt32));

  t := 0;
  while t < numTriangles do begin
    v := 0;
    while v < 3 do begin
      index := triangles[t].vertices[v];
      triListIndex := vertices[index].triListIndex
                    + vertices[index].numTrisLeft;
      vertToTri[triListIndex] := t;
      Inc(vertices[index].numTrisLeft);
      Inc(v);
    end;
    Inc(t);
  end;

  // Make LRU cache
  LRUCacheSize := cacheSize;
  LRUCache := GetMem(LRUCacheSize * SizeOf(UInt32));
  scoring  := GetMem(LRUCacheSize * SizeOf(Single));

  i := 0;
  while i < LRUCacheSize do begin
    LRUCache[i] := UNDEFINED;
    scoring[i] := - 1.0;
    Inc(i);
  end;

  numIndicesDone := 0;
  while numIndicesDone <> numIndices do begin
    // update vertex scoring
    i := 0;
    while (i < LRUCacheSize) and (LRUCache[i] <> UNDEFINED) do begin
      vertexIndex := LRUCache[i];
      if vertexIndex <> UNDEFINED then begin
        // Do scoring based on cache position
        if i < 3 then begin
          scoring[i] := 0.75;
        end else begin
          scaler := 1.0 / (LRUCacheSize - 3);
          scoreBase := 1.0 - (i - 3) * scaler;
          scoring[i] := powf(scoreBase, 1.5);
        end;
        // Add score based on tris left for vertex (valence score)
        numTrisLeft := vertices[vertexIndex].numTrisLeft;
        scoring[i] := scoring[i] + stsvco_valenceScore(numTrisLeft);
      end;
      Inc(i);
    end;
    // find triangle to draw based on score
    // Update score for all triangles with vertexes in cache
    triangleToDraw := UNDEFINED;
    bestTriScore := 0.0;
    i := 0;
    while (i < LRUCacheSize) and (LRUCache[i] <> UNDEFINED) do begin
      vIndex := LRUCache[i];

      if vertices[vIndex].numTrisLeft > 0 then begin
        t := 0;
        while t < vertices[vIndex].numAdjecentTris do begin
          tIndex := vertToTri[vertices[vIndex].triListIndex + t];
          if not triangles[tIndex].drawn then begin
            triScore := 0.0;
            v := 0;
            while v < 3 do begin
              cacheIndex := vertices[triangles[tIndex].vertices[v]].cacheIndex;
              if cacheIndex <> UNDEFINED then
                triScore := triScore + scoring[cacheIndex];
              Inc(v);
            end;

            if triScore > bestTriScore then begin
              triangleToDraw := tIndex;
              bestTriScore := triScore;
            end;
          end;
          Inc(t);
        end;
      end;
      Inc(i);
    end;

    if triangleToDraw = UNDEFINED then begin
      // No triangle can be found by heuristic, simply choose first and best
      t := 0;
      while t < numTriangles do begin
        if not triangles[t].drawn then begin
          //compute valence for each vertex
          triScore := 0.0;
          v := 0;
          while v < 3 do begin
            vertexIndex := triangles[t].vertices[v];
            // Add score based on tris left for vertex (valence score)
            numTrisLeft := vertices[vertexIndex].numTrisLeft;
            triScore := triScore + stsvco_valenceScore(numTrisLeft);
            Inc(v);
          end;
          if triScore >= bestTriScore then begin
            triangleToDraw := t;
            bestTriScore := triScore;
          end;
        end;
        Inc(t);
      end;
    end;

    // update cache
    cacheIndex := 3;
    numVerticesFound := 0;
    while (LRUCache[numVerticesFound] <> UNDEFINED) and (numVerticesFound < 3) and (cacheIndex < LRUCacheSize) do begin
      topOfCacheInTri := False;
      // Check if index is in triangle
      i := 0;
      while i < 3 do begin
        if triangles[triangleToDraw].vertices[i] = LRUCache[numVerticesFound] then begin
          Inc(numVerticesFound);
          topOfCacheInTri := True;
          break;
        end;
        Inc(i);
      end;

      if not topOfCacheInTri then begin
        topIndex := LRUCache[numVerticesFound];
        j := numVerticesFound;
        while j < 2 do begin
          LRUCache[j] := LRUCache[j + 1];
          Inc(j);
        end;
        LRUCache[2] := LRUCache[cacheIndex];
        if LRUCache[2] <> UNDEFINED then
          vertices[LRUCache[2]].cacheIndex := UNDEFINED;

        LRUCache[cacheIndex] := topIndex;
        if topIndex <> UNDEFINED then
          vertices[topIndex].cacheIndex := cacheIndex;
        Inc(cacheIndex);
      end;
    end;

    // Set triangle as drawn
    v := 0;
    while v < 3 do begin
      index := triangles[triangleToDraw].vertices[v];

      LRUCache[v] := index;
      vertices[index].cacheIndex := v;

      Dec(vertices[index].numTrisLeft);

      indices[numIndicesDone] := index;
      Inc(numIndicesDone);
      Inc(v);
    end;


    triangles[triangleToDraw].drawn := true;
  end;

  // Memory cleanup
  FreeMem(scoring);
  FreeMem(LRUCache);
  FreeMem(vertToTri);
  FreeMem(vertices);
  FreeMem(triangles);
end;

function stsvco_compute_ACMR(
      indices: PUInt32;
      numIndices, cacheSize: UInt32): Single;
var
  numCacheMisses: UInt32;
  cache: PUInt32;
  i, v: UInt32;
  index: UInt32;
  foundInCache: Boolean;
  c: UInt32;
begin
  numCacheMisses := 0;
  cache := GetMem(cacheSize * SizeOf(UInt32));

  Assert(numIndices mod 3 = 0); // 'Index input has to be triangles'

  i := 0;
  while i < cacheSize do begin
    cache[i] := UNDEFINED;
    Inc(i);
  end;

  v := 0;
  while v < numIndices do begin
    index := indices[v];
    // check if vertex in cache
    foundInCache := False;
    c := 0;
    while (c < cacheSize) and (cache[c] <> UNDEFINED) and (not foundInCache) do begin
      if cache[c] = index then
        foundInCache := True;
      Inc(c);
    end;

    if not foundInCache then begin
      Inc(numCacheMisses);
      c := cacheSize - 1;
      while c >= 1 do begin
        cache[c] := cache[c - 1];
        Dec(c);
      end;
      cache[0] := index;
    end;
    Inc(v);
  end;

  FreeMem(cache);

  Exit(numCacheMisses / (numIndices / 3));
end;

end.

{
 ------------------------------------------------------------------------------
 This software is available under 2 licenses -- choose whichever you prefer.
 ------------------------------------------------------------------------------
 ALTERNATIVE A - MIT License
 Copyright (c) 2017 Sigurd Seteklev
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 ------------------------------------------------------------------------------
 ALTERNATIVE B - Public Domain (www.unlicense.org)
 Copyright (c) 2017 Sigurd Seteklev
 This is free and unencumbered software released into the public domain.
 Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
 software, either in source code form or as a compiled binary, for any purpose,
 commercial or non-commercial, and by any means.
 In jurisdictions that recognize copyright laws, the author or authors of this
 software dedicate any and all copyright interest in the software to the public
 domain. We make this dedication for the benefit of the public at large and to
 the detriment of our heirs and successors. We intend this dedication to be an
 overt act of relinquishment in perpetuity of all present and future rights to
 this software under copyright law.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 ------------------------------------------------------------------------------
 }
