unit Mcp.FormBridge;

interface

uses
   System.SysUtils, System.Classes, System.JSON, System.Rtti, System.Generics.Collections,
   Vcl.Forms, Vcl.Controls, Mcp.Server, Mcp.Types, Mcp.Attributes;

type
   TMcpDiscoveryMode = (mdAttributes, mdRtti);

   TMcpFormBridge = class;

   TMcpReflectedTool = class
   private
      FBridge: TMcpFormBridge;
      FMethodName: string;
   public
      constructor Create(ABridge: TMcpFormBridge; const AMethodName: string);
      function Execute(const Arguments: TJSONObject): TJSONValue;
   end;

   TMcpControlBinding = class
   private
      FName: string;
      FComponentName: string;
      FWritable: boolean;
      FDescription: string;
   public
      constructor Create(const AName, AComponentName: string; AWritable: boolean; const ADescription: string);
      property Name: string read FName;
      property ComponentName: string read FComponentName;
      property Writable: boolean read FWritable;
      property Description: string read FDescription;
   end;

   [ComponentPlatformsAttribute(pidWin32 or pidWin64)]
   TMcpFormBridge = class(TComponent)
   private
      FServer: TMcpServer;
      FForm: TCustomForm;
      FCaptionFormat: string;
      FDiscoveryMode: TMcpDiscoveryMode;
      FAutoStart: boolean;
      FAutoCaption: boolean;
      FRegistered: boolean;
      FOwnerId: string;
      FReflectedTools: TObjectList<TMcpReflectedTool>;
      FControls: TObjectList<TMcpControlBinding>;
      FResourceListMethod: string;
      FResourceReadMethod: string;
      FPromptListMethod: string;
      FPromptGetMethod: string;
      procedure SetServer(const Value: TMcpServer);
      function IsDesigning: boolean;
      function TargetForm: TCustomForm;
      function InvokeJsonMethod(const MethodName: string; const Arguments: array of TValue): TJSONValue;
      function InvokeJsonArrayMethod(const MethodName: string): TJSONArray;
      function InvokeJsonObjectMethod(const MethodName: string; const Argument: string): TJSONObject;
      function FindControlBinding(const Name: string): TMcpControlBinding;
      function FindComponentByBinding(Binding: TMcpControlBinding): TComponent;
      function IsSupportedValueComponent(Component: TComponent): boolean;
      function ReadComponentValue(Component: TComponent): TJSONValue;
      procedure WriteComponentValue(Component: TComponent; const Value: TJSONValue);
      procedure AddReflectedTool(const MethodName, ToolName, Description, RequiredCsv, PropertiesCsv: string);
      procedure AddControlBinding(const Name, ComponentName: string; Writable: boolean; const Description: string);
      function CsvToArray(const Csv: string): TArray<string>;
      function MethodNameToToolName(const MethodName: string): string;
      function BuildOwnerId: string;
      procedure EnsureServer;
      procedure AutoRegisterAttributes(RttiType: TRttiType);
      procedure AutoRegisterRtti(RttiType: TRttiType);
      function ToolGetFormState(const Arguments: TJSONObject): TJSONValue;
      function ToolCloseForm(const Arguments: TJSONObject): TJSONValue;
      function ToolSetCaption(const Arguments: TJSONObject): TJSONValue;
      function ToolListControls(const Arguments: TJSONObject): TJSONValue;
      function ToolGetControlValue(const Arguments: TJSONObject): TJSONValue;
      function ToolSetControlValue(const Arguments: TJSONObject): TJSONValue;
      function ToolGetFormValues(const Arguments: TJSONObject): TJSONValue;
      function ToolSetFormValues(const Arguments: TJSONObject): TJSONValue;
      function ListResources: TJSONArray;
      function ReadResource(const Uri: string): TJSONObject;
      function ListPrompts: TJSONArray;
      function GetPrompt(const PromptName: string): TJSONObject;
   protected
      procedure Loaded; override;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure RegisterDefaultTools;
      procedure AutoRegister;
      procedure ApplyMcpCaption;
   published
      property Server: TMcpServer read FServer write SetServer;
      property Form: TCustomForm read FForm write FForm;
      property CaptionFormat: string read FCaptionFormat write FCaptionFormat;
      property DiscoveryMode: TMcpDiscoveryMode read FDiscoveryMode write FDiscoveryMode default mdRtti;
      property AutoStart: boolean read FAutoStart write FAutoStart default true;
      property AutoCaption: boolean read FAutoCaption write FAutoCaption default true;
   end;

implementation

constructor TMcpReflectedTool.Create(ABridge: TMcpFormBridge; const AMethodName: string);
begin
   inherited Create;
   FBridge := ABridge;
   FMethodName := AMethodName;
end;

function TMcpReflectedTool.Execute(const Arguments: TJSONObject): TJSONValue;
begin
   result := FBridge.InvokeJsonMethod(FMethodName, [TValue.From<TJSONObject>(Arguments)]);
end;

constructor TMcpControlBinding.Create(const AName, AComponentName: string; AWritable: boolean; const ADescription: string);
begin
   inherited Create;
   FName := AName;
   FComponentName := AComponentName;
   FWritable := AWritable;
   FDescription := ADescription;
end;

constructor TMcpFormBridge.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   if AOwner is TCustomForm then begin
      FForm := TCustomForm(AOwner);
   end;
   FCaptionFormat := '%s - MCP(%s)';
   FDiscoveryMode := mdRtti;
   FAutoStart := true;
   FAutoCaption := true;
   FReflectedTools := TObjectList<TMcpReflectedTool>.Create(true);
   FControls := TObjectList<TMcpControlBinding>.Create(true);
end;

destructor TMcpFormBridge.Destroy;
begin
   if (FServer <> nil) and (FOwnerId <> '') then begin
      FServer.UnregisterOwner(FOwnerId);
   end;
   FControls.Free;
   FReflectedTools.Free;
   inherited Destroy;
end;

procedure TMcpFormBridge.SetServer(const Value: TMcpServer);
begin
   if FServer = Value then begin
      exit;
   end;
   if (FServer <> nil) and (FOwnerId <> '') then begin
      FServer.UnregisterOwner(FOwnerId);
   end;
   FServer := Value;
   FRegistered := false;
end;

function TMcpFormBridge.IsDesigning: boolean;
var
   AOwner: TComponent;
begin
   result := csDesigning in ComponentState;
   AOwner := Owner;
   while (not result) and (AOwner <> nil) do begin
      result := csDesigning in AOwner.ComponentState;
      AOwner := AOwner.Owner;
   end;
end;

procedure TMcpFormBridge.Loaded;
begin
   inherited Loaded;
   if IsDesigning then begin
      exit;
   end;
   if FAutoStart then begin
      EnsureServer;
      AutoRegister;
      FServer.Start;
      if FAutoCaption then begin
         ApplyMcpCaption;
      end;
   end;
end;

procedure TMcpFormBridge.EnsureServer;
begin
   if FOwnerId = '' then begin
      FOwnerId := BuildOwnerId;
   end;
   if FServer = nil then begin
      FServer := GlobalMcpServer;
   end;
   if SameText(FServer.ServerName, 'delphi-mcp') then begin
      FServer.ServerName := LowerCase(TargetForm.Name);
   end;
end;

function TMcpFormBridge.BuildOwnerId: string;
var
   AForm: TCustomForm;
begin
   AForm := TargetForm;
   result := AForm.ClassName + '.' + AForm.Name + '.' + IntToHex(NativeUInt(AForm), SizeOf(Pointer) * 2);
end;

function TMcpFormBridge.TargetForm: TCustomForm;
begin
   result := FForm;
   if result = nil then begin
      result := Application.MainForm;
   end;
   if result = nil then begin
      raise Exception.Create('Keine VCL-Form fuer MCP registriert.');
   end;
end;

function TMcpFormBridge.CsvToArray(const Csv: string): TArray<string>;
var
   Parts: TArray<string>;
   i, Count: integer;
   S: string;
begin
   if Trim(Csv) = '' then begin
      SetLength(result, 0);
      exit;
   end;
   Parts := Csv.Split([',']);
   Count := 0;
   SetLength(result, length(Parts));
   for i := 0 to high(Parts) do begin
      S := Trim(Parts[i]);
      if S <> '' then begin
         result[Count] := S;
         inc(Count);
      end;
   end;
   SetLength(result, Count);
end;

function TMcpFormBridge.MethodNameToToolName(const MethodName: string): string;
var
   i: integer;
   S: string;
   C: Char;
begin
   S := MethodName;
   if SameText(Copy(S, 1, 3), 'Mcp') then begin
      Delete(S, 1, 3);
   end;
   result := '';
   for i := 1 to length(S) do begin
      C := S[i];
      if CharInSet(C, ['A' .. 'Z']) then begin
         if result <> '' then begin
            result := result + '_';
         end;
         result := result + LowerCase(C);
      end
      else begin
         result := result + LowerCase(C);
      end;
   end;
end;

function TMcpFormBridge.InvokeJsonMethod(const MethodName: string; const Arguments: array of TValue): TJSONValue;
var
   Context: TRttiContext;
   RttiType: TRttiType;
   Method: TRttiMethod;
   Value: TValue;
begin
   Context := TRttiContext.Create;
   try
      RttiType := Context.GetType(TargetForm.ClassType);
      Method := RttiType.GetMethod(MethodName);
      if Method = nil then begin
         raise Exception.CreateFmt('MCP-Methode nicht gefunden: %s', [MethodName]);
      end;
      Value := Method.Invoke(TargetForm, Arguments);
      if (not Value.IsObject) or not (Value.AsObject is TJSONValue) then begin
         raise Exception.CreateFmt('MCP-Methode %s muss TJSONValue liefern.', [MethodName]);
      end;
      result := TJSONValue(Value.AsObject);
   finally
      Context.Free;
   end;
end;

function TMcpFormBridge.InvokeJsonArrayMethod(const MethodName: string): TJSONArray;
var
   Value: TJSONValue;
begin
   Value := InvokeJsonMethod(MethodName, []);
   if not (Value is TJSONArray) then begin
      Value.Free;
      raise Exception.CreateFmt('MCP-Methode %s muss TJSONArray liefern.', [MethodName]);
   end;
   result := TJSONArray(Value);
end;

function TMcpFormBridge.InvokeJsonObjectMethod(const MethodName: string; const Argument: string): TJSONObject;
var
   Value: TJSONValue;
begin
   Value := InvokeJsonMethod(MethodName, [Argument]);
   if not (Value is TJSONObject) then begin
      Value.Free;
      raise Exception.CreateFmt('MCP-Methode %s muss TJSONObject liefern.', [MethodName]);
   end;
   result := TJSONObject(Value);
end;

procedure TMcpFormBridge.AddReflectedTool(const MethodName, ToolName, Description, RequiredCsv, PropertiesCsv: string);
var
   Adapter: TMcpReflectedTool;
   Required, Properties: TArray<string>;
begin
   if FServer = nil then begin
      raise Exception.Create('TMcpFormBridge.Server ist nicht gesetzt.');
   end;
   Adapter := TMcpReflectedTool.Create(Self, MethodName);
   FReflectedTools.Add(Adapter);
   Required := CsvToArray(RequiredCsv);
   Properties := CsvToArray(PropertiesCsv);
   FServer.RegisterTool(ToolName, Description, Required, Properties, Adapter.Execute, true, FOwnerId);
end;

procedure TMcpFormBridge.AddControlBinding(const Name, ComponentName: string; Writable: boolean; const Description: string);
var
   Existing: TMcpControlBinding;
begin
   if Name = '' then begin
      exit;
   end;
   Existing := FindControlBinding(Name);
   if Existing <> nil then begin
      exit;
   end;
   FControls.Add(TMcpControlBinding.Create(Name, ComponentName, Writable, Description));
end;

function TMcpFormBridge.FindControlBinding(const Name: string): TMcpControlBinding;
var
   Binding: TMcpControlBinding;
begin
   result := nil;
   for Binding in FControls do begin
      if SameText(Binding.Name, Name) then begin
         result := Binding;
         exit;
      end;
   end;
end;

function TMcpFormBridge.FindComponentByBinding(Binding: TMcpControlBinding): TComponent;
begin
   result := nil;
   if Binding <> nil then begin
      result := TargetForm.FindComponent(Binding.ComponentName);
   end;
end;

function TMcpFormBridge.IsSupportedValueComponent(Component: TComponent): boolean;
var
   Context: TRttiContext;
   RttiType: TRttiType;
begin
   result := false;
   if (Component = nil) or (Component.Name = '') then begin
      exit;
   end;
   Context := TRttiContext.Create;
   try
      RttiType := Context.GetType(Component.ClassType);
      result := ((RttiType.GetProperty('Text') <> nil) and RttiType.GetProperty('Text').IsReadable) or
         ((RttiType.GetProperty('Checked') <> nil) and RttiType.GetProperty('Checked').IsReadable) or
         ((RttiType.GetProperty('Value') <> nil) and RttiType.GetProperty('Value').IsReadable) or
         ((RttiType.GetProperty('ItemIndex') <> nil) and RttiType.GetProperty('ItemIndex').IsReadable);
   finally
      Context.Free;
   end;
end;

function TMcpFormBridge.ReadComponentValue(Component: TComponent): TJSONValue;
var
   Context: TRttiContext;
   RttiType: TRttiType;
   Prop: TRttiProperty;
begin
   if Component = nil then begin
      raise Exception.Create('MCP-Control nicht gefunden.');
   end;

   Context := TRttiContext.Create;
   try
      RttiType := Context.GetType(Component.ClassType);
      Prop := RttiType.GetProperty('Text');
      if (Prop <> nil) and Prop.IsReadable then begin
         result := TJSONString.Create(Prop.GetValue(Component).ToString);
         exit;
      end;
      Prop := RttiType.GetProperty('Checked');
      if (Prop <> nil) and Prop.IsReadable then begin
         result := McpBoolValue(Prop.GetValue(Component).AsBoolean);
         exit;
      end;
      Prop := RttiType.GetProperty('Value');
      if (Prop <> nil) and Prop.IsReadable then begin
         result := TJSONNumber.Create(Prop.GetValue(Component).AsExtended);
         exit;
      end;
      Prop := RttiType.GetProperty('ItemIndex');
      if (Prop <> nil) and Prop.IsReadable then begin
         result := TJSONNumber.Create(Prop.GetValue(Component).AsInteger);
         exit;
      end;
   finally
      Context.Free;
   end;

   raise Exception.CreateFmt('Control %s hat keine unterstuetzte Wert-Property.', [Component.Name]);
end;

procedure TMcpFormBridge.WriteComponentValue(Component: TComponent; const Value: TJSONValue);
var
   Context: TRttiContext;
   RttiType: TRttiType;
   Prop: TRttiProperty;
begin
   if Component = nil then begin
      raise Exception.Create('MCP-Control nicht gefunden.');
   end;

   Context := TRttiContext.Create;
   try
      RttiType := Context.GetType(Component.ClassType);
      Prop := RttiType.GetProperty('Text');
      if (Prop <> nil) and Prop.IsWritable then begin
         Prop.SetValue(Component, Value.Value);
         exit;
      end;
      Prop := RttiType.GetProperty('Checked');
      if (Prop <> nil) and Prop.IsWritable then begin
         Prop.SetValue(Component, SameText(Value.Value, 'true'));
         exit;
      end;
      Prop := RttiType.GetProperty('Value');
      if (Prop <> nil) and Prop.IsWritable then begin
         Prop.SetValue(Component, StrToFloatDef(StringReplace(Value.Value, '.', FormatSettings.DecimalSeparator, []), 0));
         exit;
      end;
      Prop := RttiType.GetProperty('ItemIndex');
      if (Prop <> nil) and Prop.IsWritable then begin
         Prop.SetValue(Component, Round(StrToFloatDef(Value.Value, -1)));
         exit;
      end;
   finally
      Context.Free;
   end;

   raise Exception.CreateFmt('Control %s kann nicht per MCP geschrieben werden.', [Component.Name]);
end;

procedure TMcpFormBridge.RegisterDefaultTools;
begin
   EnsureServer;

   FServer.RegisterTool('get_form_state', 'Zustand der VCL-Form lesen.', [], ['includeCaption'], ToolGetFormState, true, FOwnerId);
   FServer.RegisterTool('close_form', 'VCL-Form geordnet schliessen.', [], [], ToolCloseForm, true, FOwnerId);
   FServer.RegisterTool('set_caption', 'Caption der VCL-Form setzen.', ['caption'], ['caption'], ToolSetCaption, true, FOwnerId);
   FServer.RegisterTool('list_controls', 'Per MCP freigegebene Controls auflisten.', [], [], ToolListControls, true, FOwnerId);
   FServer.RegisterTool('get_control_value', 'Wert eines freigegebenen Controls lesen.', ['name'], ['name'], ToolGetControlValue, true, FOwnerId);
   FServer.RegisterTool('set_control_value', 'Wert eines freigegebenen Controls setzen.', ['name', 'value'], ['name', 'value'], ToolSetControlValue, true, FOwnerId);
   FServer.RegisterTool('get_form_values', 'Alle freigegebenen Control-Werte lesen.', [], [], ToolGetFormValues, true, FOwnerId);
   FServer.RegisterTool('set_form_values', 'Mehrere freigegebene Control-Werte setzen.', ['values'], ['values'], ToolSetFormValues, true, FOwnerId);
end;

procedure TMcpFormBridge.AutoRegister;
var
   Context: TRttiContext;
   RttiType: TRttiType;
begin
   if FRegistered then begin
      exit;
   end;
   EnsureServer;
   RegisterDefaultTools;
   Context := TRttiContext.Create;
   try
      RttiType := Context.GetType(TargetForm.ClassType);
      if FDiscoveryMode = mdAttributes then begin
         AutoRegisterAttributes(RttiType);
      end
      else begin
         AutoRegisterRtti(RttiType);
      end;
   finally
      Context.Free;
   end;

   if (FResourceListMethod <> '') or (FResourceReadMethod <> '') then begin
      FServer.RegisterResourceHandlers(ListResources, ReadResource, FOwnerId);
   end;
   if (FPromptListMethod <> '') or (FPromptGetMethod <> '') then begin
      FServer.RegisterPromptHandlers(ListPrompts, GetPrompt, FOwnerId);
   end;
   FRegistered := true;
end;

procedure TMcpFormBridge.AutoRegisterAttributes(RttiType: TRttiType);
var
   Method: TRttiMethod;
   Field: TRttiField;
   Attr: TCustomAttribute;
   ToolAttr: McpToolAttribute;
   ControlAttr: McpControlAttribute;
begin
   for Method in RttiType.GetMethods do begin
      for Attr in Method.GetAttributes do begin
         if Attr is McpToolAttribute then begin
            ToolAttr := McpToolAttribute(Attr);
            AddReflectedTool(Method.Name, ToolAttr.Name, ToolAttr.Description, ToolAttr.Required, ToolAttr.Properties);
         end
         else if Attr is McpResourceListAttribute then begin
            FResourceListMethod := Method.Name;
         end
         else if Attr is McpResourceReadAttribute then begin
            FResourceReadMethod := Method.Name;
         end
         else if Attr is McpPromptListAttribute then begin
            FPromptListMethod := Method.Name;
         end
         else if Attr is McpPromptGetAttribute then begin
            FPromptGetMethod := Method.Name;
         end;
      end;
   end;

   for Field in RttiType.GetFields do begin
      for Attr in Field.GetAttributes do begin
         if Attr is McpControlAttribute then begin
            ControlAttr := McpControlAttribute(Attr);
            AddControlBinding(ControlAttr.Name, Field.Name, ControlAttr.Writable, ControlAttr.Description);
         end;
      end;
   end;
end;

procedure TMcpFormBridge.AutoRegisterRtti(RttiType: TRttiType);
var
   Method: TRttiMethod;
   Component: TComponent;
   i: integer;
begin
   for Method in RttiType.GetMethods do begin
      if SameText(Copy(Method.Name, 1, 3), 'Mcp') then begin
         AddReflectedTool(Method.Name, MethodNameToToolName(Method.Name),
            'RTTI MCP method ' + Method.Name, '', 'arguments');
      end;
   end;

   for i := 0 to TargetForm.ComponentCount - 1 do begin
      Component := TargetForm.Components[i];
      if IsSupportedValueComponent(Component) then begin
         AddControlBinding(Component.Name, Component.Name, true, Component.ClassName);
      end;
   end;
end;

procedure TMcpFormBridge.ApplyMcpCaption;
var
   AForm: TCustomForm;
begin
   if FServer = nil then begin
      exit;
   end;
   AForm := TargetForm;
   AForm.Caption := Format(FCaptionFormat, [AForm.Caption, FServer.Url]);
end;

function TMcpFormBridge.ToolGetFormState(const Arguments: TJSONObject): TJSONValue;
var
   AForm: TCustomForm;
begin
   AForm := TargetForm;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('caption', AForm.Caption);
   TJSONObject(result).AddPair('className', AForm.ClassName);
   TJSONObject(result).AddPair('visible', McpBoolValue(AForm.Visible));
   TJSONObject(result).AddPair('enabled', McpBoolValue(AForm.Enabled));
   TJSONObject(result).AddPair('left', TJSONNumber.Create(AForm.Left));
   TJSONObject(result).AddPair('top', TJSONNumber.Create(AForm.Top));
   TJSONObject(result).AddPair('width', TJSONNumber.Create(AForm.Width));
   TJSONObject(result).AddPair('height', TJSONNumber.Create(AForm.Height));
   if FServer <> nil then begin
      TJSONObject(result).AddPair('mcpUrl', FServer.Url);
   end;
end;

function TMcpFormBridge.ToolCloseForm(const Arguments: TJSONObject): TJSONValue;
begin
   TargetForm.Close;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('status', 'closing');
end;

function TMcpFormBridge.ToolSetCaption(const Arguments: TJSONObject): TJSONValue;
var
   NewCaption: string;
begin
   NewCaption := McpJsonString(Arguments, 'caption', '');
   if NewCaption = '' then begin
      raise Exception.Create('set_caption erwartet caption.');
   end;
   TargetForm.Caption := NewCaption;
   result := ToolGetFormState(nil);
end;

function TMcpFormBridge.ToolListControls(const Arguments: TJSONObject): TJSONValue;
var
   Arr: TJSONArray;
   Binding: TMcpControlBinding;
   Obj: TJSONObject;
begin
   Arr := TJSONArray.Create;
   for Binding in FControls do begin
      Obj := TJSONObject.Create;
      Obj.AddPair('name', Binding.Name);
      Obj.AddPair('component', Binding.ComponentName);
      Obj.AddPair('writable', McpBoolValue(Binding.Writable));
      Obj.AddPair('description', Binding.Description);
      Arr.AddElement(Obj);
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('controls', Arr);
end;

function TMcpFormBridge.ToolGetControlValue(const Arguments: TJSONObject): TJSONValue;
var
   Name: string;
   Binding: TMcpControlBinding;
begin
   Name := McpJsonString(Arguments, 'name', '');
   Binding := FindControlBinding(Name);
   if Binding = nil then begin
      raise Exception.CreateFmt('MCP-Control nicht registriert: %s', [Name]);
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('name', Binding.Name);
   TJSONObject(result).AddPair('value', ReadComponentValue(FindComponentByBinding(Binding)));
end;

function TMcpFormBridge.ToolSetControlValue(const Arguments: TJSONObject): TJSONValue;
var
   Name: string;
   Binding: TMcpControlBinding;
   Value: TJSONValue;
begin
   Name := McpJsonString(Arguments, 'name', '');
   Binding := FindControlBinding(Name);
   if Binding = nil then begin
      raise Exception.CreateFmt('MCP-Control nicht registriert: %s', [Name]);
   end;
   if not Binding.Writable then begin
      raise Exception.CreateFmt('MCP-Control ist read-only: %s', [Name]);
   end;
   Value := Arguments.Values['value'];
   if Value = nil then begin
      raise Exception.Create('set_control_value erwartet value.');
   end;
   WriteComponentValue(FindComponentByBinding(Binding), Value);
   result := ToolGetControlValue(Arguments);
end;

function TMcpFormBridge.ToolGetFormValues(const Arguments: TJSONObject): TJSONValue;
var
   Values: TJSONObject;
   Binding: TMcpControlBinding;
begin
   Values := TJSONObject.Create;
   for Binding in FControls do begin
      Values.AddPair(Binding.Name, ReadComponentValue(FindComponentByBinding(Binding)));
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('values', Values);
end;

function TMcpFormBridge.ToolSetFormValues(const Arguments: TJSONObject): TJSONValue;
var
   Values: TJSONObject;
   Pair: TJSONPair;
   Binding: TMcpControlBinding;
begin
   if not (Arguments.Values['values'] is TJSONObject) then begin
      raise Exception.Create('set_form_values erwartet values.');
   end;
   Values := TJSONObject(Arguments.Values['values']);
   for Pair in Values do begin
      Binding := FindControlBinding(Pair.JsonString.Value);
      if Binding <> nil then begin
         if not Binding.Writable then begin
            raise Exception.CreateFmt('MCP-Control ist read-only: %s', [Binding.Name]);
         end;
         WriteComponentValue(FindComponentByBinding(Binding), Pair.JsonValue);
      end;
   end;
   result := ToolGetFormValues(nil);
end;

function TMcpFormBridge.ListResources: TJSONArray;
begin
   if FResourceListMethod = '' then begin
      result := TJSONArray.Create;
      exit;
   end;
   result := InvokeJsonArrayMethod(FResourceListMethod);
end;

function TMcpFormBridge.ReadResource(const Uri: string): TJSONObject;
begin
   if FResourceReadMethod = '' then begin
      raise Exception.Create('Keine MCP Resource-Read-Methode registriert.');
   end;
   result := InvokeJsonObjectMethod(FResourceReadMethod, Uri);
end;

function TMcpFormBridge.ListPrompts: TJSONArray;
begin
   if FPromptListMethod = '' then begin
      result := TJSONArray.Create;
      exit;
   end;
   result := InvokeJsonArrayMethod(FPromptListMethod);
end;

function TMcpFormBridge.GetPrompt(const PromptName: string): TJSONObject;
begin
   if FPromptGetMethod = '' then begin
      raise Exception.Create('Keine MCP Prompt-Get-Methode registriert.');
   end;
   result := InvokeJsonObjectMethod(FPromptGetMethod, PromptName);
end;

end.
