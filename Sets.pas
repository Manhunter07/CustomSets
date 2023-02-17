unit Sets;

////////////////////////////////////////////////////////////////////////////////
///  Generic custom sets library                                             ///
///                                                                          ///
///  Written by Dennis Göhlert                                               ///
///  Licensed under Mozilla Public License (MPL) 2.0                         ///
///                                                                          ///
///  Last modified: 17.02.2023 20:30                                         ///
///  (c) 2018-2023 All rights reserved                                       ///
////////////////////////////////////////////////////////////////////////////////

interface

uses
  System.SysUtils, System.Types, System.Math, System.Rtti;

type
  ESetTypeException = class(Exception);

  TSetEnumerator<T> = class;

  TSet<T> = record
  private class var
    FMin: Int64;
    FMax: Int64;
  private
    FElements: TBytes;
    function ElementByteIndex(const AElement: T): Int64; inline;
    function ElementBitIndex(const AElement: T): Byte; inline;
    procedure DefineRange(const AFrom, ATo: T; const AValue: Boolean); inline;
  public
    class constructor Create;
    function GetEnumerator: TSetEnumerator<T>; inline;
    /// <summary>
    ///   Includes an element in the set
    /// </summary>
    procedure Include(const AElement: T); inline;
    /// <summary>
    ///   Excludes an element from the set
    /// </summary>
    procedure Exclude(const AElement: T); inline;
    /// <summary>
    ///   Checks if the set is distinct from another one
    /// </summary>
    function Distinct(const ASet: TSet<T>): Boolean; inline;
    /// <summary>
    ///   Counts the elements in the set
    /// </summary>
    function Count: Int64; inline;
    /// <summary>
    ///   Fills the set by including all values within a range
    /// </summary>
    procedure Fill(const AFrom, ATo: T); inline;
    /// <summary>
    ///   Clears the set by excluding all values within a range
    /// </summary>
    procedure Clear(const AFrom, ATo: T); inline;
    class operator Initialize(out ASet: TSet<T>);
    class operator Assign(var ADestination, ASource: TSet<T>); inline;
    class operator Implicit(const AArray: TArray<T>): TSet<T>; inline;
    class operator LogicalNot(const ASet: TSet<T>): TSet<T>; inline;
    class operator Equal(const AFirst, ASecond: TSet<T>): Boolean; inline;
    class operator NotEqual(const AFirst, ASecond: TSet<T>): Boolean; inline;
    class operator GreaterThanOrEqual(const AFirst, ASecond: TSet<T>): Boolean; inline;
    class operator LessThanOrEqual(const AFirst, ASecond: TSet<T>): Boolean; inline;
    class operator Add(const AFirst, ASecond: TSet<T>): TSet<T>; inline;
    class operator Subtract(const AFirst, ASecond: TSet<T>): TSet<T>; inline;
    class operator In(const AElement: T; const ASet: TSet<T>): Boolean; inline;
  end;

  TSetEnumerator<T> = class
  private
    FSet: TSet<T>;
    FCurrent: T;
  public
    property Current: T read FCurrent;
    constructor Create(ASet: TSet<T>);
    function MoveNext: Boolean; inline;
  end;

implementation

{ TSet<T> }

class operator TSet<T>.Add(const AFirst, ASecond: TSet<T>): TSet<T>;
var
  Index: Integer;
begin
  for Index := Low(Result.FElements) to High(Result.FElements) do
  begin
    Result.FElements[Index] := AFirst.FElements[Index] or ASecond.FElements[Index];
  end;
end;

class operator TSet<T>.Assign(var ADestination, ASource: TSet<T>);
begin
  ADestination.FElements := Copy(ASource.FElements);
end;

procedure TSet<T>.Clear(const AFrom, ATo: T);
begin
  DefineRange(AFrom, ATo, False);
end;

function TSet<T>.Count: Int64;
var
  ByteIndex: Integer;
  BitIndex: Byte;
begin
  Result := 0;
  for ByteIndex := Low(FElements) to High(FElements) do
  begin
    for BitIndex := 0 to 7 do
    begin
      if FElements[ByteIndex] and (1 shl BitIndex) <> 0 then
      begin
        Inc(Result);
      end;
    end;
  end;
end;

class constructor TSet<T>.Create;
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
begin
  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(TypeInfo(T));
    if RttiType.IsOrdinal then
    begin
      FMin := RttiType.AsOrdinal.MinValue;
      FMax := RttiType.AsOrdinal.MaxValue;
    end else
    begin
      if RttiType is TRttiInt64Type then
      begin
        FMin := (RttiType as TRttiInt64Type).MinValue;
        FMax := (RttiType as TRttiInt64Type).MaxValue;
      end else
      begin
        raise ESetTypeException.Create('Ordinal type expected');
      end;
    end;
    if (FMax - FMin) > (MaxInt - SizeOf(Integer){$IFDEF CPU64BITS} * 2{$ENDIF} - SizeOf(NativeInt)) then
    begin
      raise ESetTypeException.Create('Range exceeds size constraints');
    end;
  finally
    RttiContext.Free;
  end;
end;

procedure TSet<T>.DefineRange(const AFrom, ATo: T; const AValue: Boolean);
const
  ByteMasks: array [Boolean] of Byte = (Low(Byte), High(Byte));
var
  FromByteIndex: Int64;
  ToByteIndex: Int64;
begin
  FromByteIndex := ElementByteIndex(AFrom);
  ToByteIndex := ElementByteIndex(ATo);
  FillChar(FElements[Succ(FromByteIndex)], Pred(ToByteIndex - FromByteIndex), ByteMasks[AValue]);
  case CompareValue(FromByteIndex, ToByteIndex) of
    LessThanValue:
      begin
        FElements[FromByteIndex] := FElements[FromByteIndex] or (ByteMasks[AValue] shl ElementBitIndex(AFrom));
        FElements[ToByteIndex] := FElements[ToByteIndex] or (ByteMasks[AValue] shr (7 - ElementBitIndex(ATo)));
      end;
    EqualsValue:
      begin
        FElements[FromByteIndex] := FElements[FromByteIndex] or ((ByteMasks[AValue] shl ElementBitIndex(AFrom)) and (ByteMasks[AValue] shr (7 - ElementBitIndex(ATo))));
      end;
  end;
end;

function TSet<T>.Distinct(const ASet: TSet<T>): Boolean;
var
  Index: Integer;
begin
  for Index := Low(FElements) to High(FElements) do
  begin
    if FElements[Index] and ASet.FElements[Index] <> 0 then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

function TSet<T>.ElementBitIndex(const AElement: T): Byte;
begin
  Result := (TValue.From<T>(AElement).AsOrdinal - FMin) mod 8;
end;

function TSet<T>.ElementByteIndex(const AElement: T): Int64;
begin
  Result := (TValue.From<T>(AElement).AsOrdinal - FMin) div 8;
end;

class operator TSet<T>.Equal(const AFirst, ASecond: TSet<T>): Boolean;
begin
  Result := CompareMem(AFirst.FElements, ASecond.FElements, Length(AFirst.FElements));
end;

procedure TSet<T>.Exclude(const AElement: T);
var
  ByteIndex: Int64;
begin
  ByteIndex := ElementByteIndex(AElement);
  FElements[ByteIndex] := FElements[ByteIndex] and not (1 shl ElementBitIndex(AElement));
end;

procedure TSet<T>.Fill(const AFrom, ATo: T);
begin
  DefineRange(AFrom, ATo, True);
end;

function TSet<T>.GetEnumerator: TSetEnumerator<T>;
begin
  Result := TSetEnumerator<T>.Create(Self);
end;

class operator TSet<T>.GreaterThanOrEqual(const AFirst, ASecond: TSet<T>): Boolean;
var
  Index: Integer;
begin
  for Index := Low(ASecond.FElements) to High(ASecond.FElements) do
  begin
    if AFirst.FElements[Index] and ASecond.FElements[Index] <> ASecond.FElements[Index] then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

class operator TSet<T>.Implicit(const AArray: TArray<T>): TSet<T>;
var
  Current: T;
begin
  for Current in AArray do
  begin
    Result.Include(Current);
  end;
end;

class operator TSet<T>.In(const AElement: T; const ASet: TSet<T>): Boolean;
var
  BitIndex: Byte;
begin
  BitIndex := ASet.ElementBitIndex(AElement);
  Result := (ASet.FElements[ASet.ElementByteIndex(AElement)] and (1 shl BitIndex)) <> 0;
end;

procedure TSet<T>.Include(const AElement: T);
var
  ByteIndex: Int64;
begin
  ByteIndex := ElementByteIndex(AElement);
  FElements[ByteIndex] := FElements[ByteIndex] or (1 shl ElementBitIndex(AElement));
end;

class operator TSet<T>.Initialize(out ASet: TSet<T>);
begin
  SetLength(ASet.FElements, Ceil((FMax - FMin) / 8));
end;

class operator TSet<T>.LessThanOrEqual(const AFirst, ASecond: TSet<T>): Boolean;
var
  Index: Integer;
begin
  for Index := Low(AFirst.FElements) to High(AFirst.FElements) do
  begin
    if ASecond.FElements[Index] and AFirst.FElements[Index] <> AFirst.FElements[Index] then
    begin
      Exit(False);
    end;
  end;
  Result := True;
end;

class operator TSet<T>.LogicalNot(const ASet: TSet<T>): TSet<T>;
var
  Index: Integer;
begin
  for Index := Low(Result.FElements) to High(Result.FElements) do
  begin
    Result.FElements[Index] := not ASet.FElements[Index];
  end;
end;

class operator TSet<T>.NotEqual(const AFirst, ASecond: TSet<T>): Boolean;
begin
  Result := not (AFirst = ASecond);
end;

class operator TSet<T>.Subtract(const AFirst, ASecond: TSet<T>): TSet<T>;
var
  Index: Integer;
begin
  for Index := Low(Result.FElements) to High(Result.FElements) do
  begin
    Result.FElements[Index] := AFirst.FElements[Index] and not ASecond.FElements[Index];
  end;
end;

{ TSetEnumerator<T> }

constructor TSetEnumerator<T>.Create(ASet: TSet<T>);
begin
  FSet := ASet;
  FCurrent := TValue.FromOrdinal(TypeInfo(T), Pred(FSet.FMin)).AsType<T>;
end;

function TSetEnumerator<T>.MoveNext: Boolean;
begin
  repeat
    FCurrent := TValue.FromOrdinal(TypeInfo(T), Succ(TValue.From<T>(FCurrent).AsOrdinal)).AsType<T>;
    if FCurrent in FSet then
    begin
      Exit(True);
    end;
  until TValue.From<T>(FCurrent).AsOrdinal >= FSet.FMax;
  Result := False;
end;

end.
