{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

uses
  sts_vertex_cache_optimizer;

var
  indices: array[0 .. 3 * 256 - 1] of UInt32;
  i: Int32;

begin
  Writeln('Generating random pseudo mesh');
  for i := 0 to Length(indices) div 3 do begin
    indices[i*3 + 0] := Random(1024);
    indices[i*3 + 1] := Random(1024);
    indices[i*3 + 2] := Random(1024);
  end;
  Writeln('Before: ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
  stsvco_optimize(@indices[0], Length(indices), 1023);
  Writeln('After:  ', stsvco_compute_ACMR(@indices[0], Length(indices), 8));
end.
