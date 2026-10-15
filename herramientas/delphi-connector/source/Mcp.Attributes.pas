unit Mcp.Attributes;

interface

type
   McpToolAttribute = class(TCustomAttribute)
   private
      FName: string;
      FDescription: string;
      FRequired: string;
      FProperties: string;
   public
      constructor Create(const AName: string; const ADescription: string = '';
         const ARequired: string = ''; const AProperties: string = '');
      property Name: string read FName;
      property Description: string read FDescription;
      property Required: string read FRequired;
      property Properties: string read FProperties;
   end;

   McpResourceListAttribute = class(TCustomAttribute);
   McpResourceReadAttribute = class(TCustomAttribute);
   McpPromptListAttribute = class(TCustomAttribute);
   McpPromptGetAttribute = class(TCustomAttribute);

   McpControlAttribute = class(TCustomAttribute)
   private
      FName: string;
      FWritable: boolean;
      FDescription: string;
   public
      constructor Create(const AName: string; AWritable: boolean = true; const ADescription: string = '');
      property Name: string read FName;
      property Writable: boolean read FWritable;
      property Description: string read FDescription;
   end;

implementation

constructor McpToolAttribute.Create(const AName, ADescription, ARequired, AProperties: string);
begin
   inherited Create;
   FName := AName;
   FDescription := ADescription;
   FRequired := ARequired;
   FProperties := AProperties;
end;

constructor McpControlAttribute.Create(const AName: string; AWritable: boolean = true; const ADescription: string = '');
begin
   inherited Create;
   FName := AName;
   FWritable := AWritable;
   FDescription := ADescription;
end;

end.
