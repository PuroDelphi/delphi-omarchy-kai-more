program CapturaBackend;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  System.Generics.Collections, System.Generics.Defaults;

function FileURI(const FileName: string): string;
var B: Byte;
begin
  Result := 'file://';
  for B in TEncoding.UTF8.GetBytes(FileName) do
    if (B in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'), Ord('0')..Ord('9')]) or
      (Char(B) in ['/', '-', '_', '.', '~']) then Result := Result + Char(B)
    else Result := Result + '%' + IntToHex(B, 2);
end;

function Modified(const FileName: string): TDateTime;
begin
  try Result := TFile.GetLastWriteTime(FileName); except Result := 0; end;
end;

procedure ListImages(const DirectoryName: string);
var Root, Item: TJSONObject; Items: TJSONArray; Files: TArray<string>;
  FileName: string; Stream: TFileStream; Header: array[0..23] of Byte;
  Width, Height, Count: Integer; Total, Size: Int64;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('directory', DirectoryName);
    Root.AddPair('engine', 'Delphi / Linux64');
    Items := TJSONArray.Create; Root.AddPair('items', Items);
    Total := 0; Count := 0;
    if TDirectory.Exists(DirectoryName) then begin
      Files := TDirectory.GetFiles(DirectoryName, '*.png');
      TArray.Sort<string>(Files, TComparer<string>.Construct(
        function(const Left, Right: string): Integer
        var A, B: TDateTime;
        begin
          A := Modified(Left); B := Modified(Right);
          if A > B then Result := -1 else if A < B then Result := 1
          else Result := CompareStr(Left, Right);
        end));
      for FileName in Files do begin
        if Count >= 200 then Break;
        try
          Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
          try
            Size := Stream.Size; Width := 0; Height := 0;
            if (Stream.Read(Header, SizeOf(Header)) = SizeOf(Header)) and
              (Header[0] = 137) and (Header[1] = 80) and (Header[2] = 78) and (Header[3] = 71) then begin
              Width := (Integer(Header[16]) shl 24) or (Integer(Header[17]) shl 16) or
                (Integer(Header[18]) shl 8) or Integer(Header[19]);
              Height := (Integer(Header[20]) shl 24) or (Integer(Header[21]) shl 16) or
                (Integer(Header[22]) shl 8) or Integer(Header[23]);
            end;
          finally Stream.Free; end;
          Item := TJSONObject.Create;
          Item.AddPair('path', FileName);
          Item.AddPair('uri', FileURI(FileName));
          Item.AddPair('name', ExtractFileName(FileName));
          Item.AddPair('modified', FormatDateTime('dd/mm/yyyy hh:nn', Modified(FileName)));
          Item.AddPair('bytes', TJSONNumber.Create(Size));
          Item.AddPair('width', TJSONNumber.Create(Width));
          Item.AddPair('height', TJSONNumber.Create(Height));
          Items.AddElement(Item); Inc(Count); Inc(Total, Size);
        except
          // A capture can still be being written or disappear during enumeration.
        end;
      end;
    end;
    Root.AddPair('count', TJSONNumber.Create(Count));
    Root.AddPair('totalBytes', TJSONNumber.Create(Total));
    Writeln(Root.ToJSON);
  finally Root.Free; end;
end;

begin
  try
    if (ParamCount = 2) and SameText(ParamStr(1), 'list') then
      ListImages(ExpandFileName(ParamStr(2)))
    else if (ParamCount = 1) and SameText(ParamStr(1), 'version') then
      Writeln('Captura Delphi backend 1.0.0')
    else begin
      Writeln('{"error":"Usage: CapturaBackend list DIRECTORY | version"}');
      ExitCode := 2;
    end;
  except
    on E: Exception do begin
      var J := TJSONObject.Create;
      try J.AddPair('error', E.Message); Writeln(J.ToJSON); finally J.Free; end;
      ExitCode := 1;
    end;
  end;
end.
