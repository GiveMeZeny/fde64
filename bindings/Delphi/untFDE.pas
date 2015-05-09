// thanks to Saedelaere*
unit untFDE;

interface

uses
  {$IFDEF WIN64}untFDE64{$ELSE}untFDE32{$ENDIF};

type
  {$IFDEF WIN64}
  TFDES = TFDE64S;
  {$ELSE}
  TFDES = TFDE32S;
  {$ENDIF}

function FDEDecode(lpCode: Pointer; var FDE: TFDES): LongWord;
function FDEEncode(lpCode: Pointer; var FDE: TFDES): LongWord;

implementation

function FDEDecode(lpCode: Pointer; var FDE: TFDES): LongWord;
begin
{$IFDEF WIN64}
  Result := untFDE64.FDE64Decode(lpCode, FDE);
{$ELSE}
  Result := untFDE32.FDE32Decode(lpCode, FDE);
{$ENDIF}
end;

function FDEEncode(lpCode: Pointer; var FDE: TFDES): LongWord;
begin
{$IFDEF WIN64}
  Result := untFDE64.FDE64Encode(lpCode, FDE);
{$ELSE}
  Result := untFDE32.FDE32Encode(lpCode, FDE);
{$ENDIF}
end;

end.
