unit Sets;

////////////////////////////////////////////////////////////////////////////////
///  Generic custom sets library                                             ///
///                                                                          ///
///  Written by Dennis Göhlert                                               ///
///  Licensed under Mozilla Public License (MPL) 2.0                         ///
///                                                                          ///
///  Last modified: 25.09.2018 01:37                                         ///
///  (c) 2018 All rights reserved                                            ///
////////////////////////////////////////////////////////////////////////////////

interface

uses
  System.SysUtils, System.Math, System.Rtti;

type
  EInvalidSetType = class(Exception);

  TSetEnumerator<T> = class;

  TSet<T> = record
  private class var
    FMin: Integer;
    FMax: Integer;
  private
    FElements: TBytes;
    procedure Initialize;
    function ElementByteIndex(const AElement: T): Int64;
    function ElementBitIndex(const AElement: T): Byte;
  public
    class constructor Create;
    function GetEnumerator: TSetEnumerator<T>;
    /// <summary>
    ///   Includes an element in the set
    /// </summary>
    procedure Include(const AElement: T);
    /// <summary>
    ///   Excludes an element from the set
    /// </summary>
    procedure Exclude(const AElement: T);
    class operator Equal(AFirst, ASecond: TSet<T>): Boolean;
    class operator NotEqual(AFirst, ASecond: TSet<T>): Boolean;
    class operator Add(AFirst, ASecond: TSet<T>): TSet<T>;
    class operator Subtract(AFirst, ASecond: TSet<T>): TSet<T>;
    class operator In(AElement: T; ASet: TSet<T>): Boolean;
  end;

  TSetEnumerator<T> = class
  private
    FSet: TSet<T>;
    FCurrent: T;
  public
    property Current: T read FCurrent;
    constructor Create(ASet: TSet<T>);
    function MoveNext: Boolean;
  end;

implementation

{ TSet }

class operator TSet<T>.Add(AFirst, ASecond: TSet<T>): TSet<T>;
var
  Index: Integer;
begin
  Result.Initialize;
  AFirst.Initialize;
  ASecond.Initialize;
  for Index := Low(Result.FElements) to High(Result.FElements) do
  begin
    Result.FElements[Index] := AFirst.FElements[Index] or ASecond.FElements[Index];
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
    if not RttiType.IsOrdinal then
    begin
      raise EInvalidSetType.Create('Ordinal type expected');
    end;
    FMin := RttiType.AsOrdinal.MinValue;
    FMax := RttiType.AsOrdinal.MaxValue;
  finally
    RttiContext.Free;
  end;
end;

function TSet<T>.ElementBitIndex(const AElement: T): Byte;
begin
  Result := (TValue.From<T>(AElement).AsOrdinal - FMin) mod 8;
end;

function TSet<T>.ElementByteIndex(const AElement: T): Int64;
begin
  Result := (TValue.From<T>(AElement).AsOrdinal - FMin) div 8;
end;

class operator TSet<T>.Equal(AFirst, ASecond: TSet<T>): Boolean;
begin
  AFirst.Initialize;
  ASecond.Initialize;
  Result := CompareMem(AFirst.FElements, ASecond.FElements, Length(AFirst.FElements));
end;

procedure TSet<T>.Exclude(const AElement: T);
var
  ByteIndex: Int64;
begin
  Initialize;
  ByteIndex := ElementByteIndex(AElement);
  FElements[ByteIndex] := FElements[ByteIndex] and not (1 shl ElementBitIndex(AElement));
end;

function TSet<T>.GetEnumerator: TSetEnumerator<T>;
begin
  Result := TSetEnumerator<T>.Create(Self);
end;

class operator TSet<T>.In(AElement: T; ASet: TSet<T>): Boolean;
var
  BitIndex: Byte;
begin
  ASet.Initialize;
  BitIndex := ASet.ElementBitIndex(AElement);
  Result := (ASet.FElements[ASet.ElementByteIndex(AElement)] and (1 shl BitIndex)) = (1 shl BitIndex);
end;

procedure TSet<T>.Include(const AElement: T);
var
  ByteIndex: Int64;
begin
  Initialize;
  ByteIndex := ElementByteIndex(AElement);
  FElements[ByteIndex] := FElements[ByteIndex] or (1 shl ElementBitIndex(AElement));
end;

procedure TSet<T>.Initialize;
begin
  if not Assigned(FElements) then
  begin
    SetLength(FElements, Ceil((FMax - FMin) / 8));
  end;
end;

class operator TSet<T>.NotEqual(AFirst, ASecond: TSet<T>): Boolean;
begin
  Result := not (AFirst = ASecond);
end;

class operator TSet<T>.Subtract(AFirst, ASecond: TSet<T>): TSet<T>;
var
  Index: Integer;
begin
  Result.Initialize;
  AFirst.Initialize;
  ASecond.Initialize;
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
    FCurrent := TValue.FromOrdinal(TypeInfo(T), TValue.From<T>(FCurrent).AsOrdinal + 1).AsType<T>;
    if FCurrent in FSet then
    begin
      Exit(True);
    end;
  until TValue.From<T>(FCurrent).AsOrdinal >= FSet.FMax;
  Result := False;
end;

end.
