unit Mcp.IdeBridge;

interface

uses
   System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Generics.Collections, System.TypInfo, System.Variants,
   System.Rtti, System.SyncObjs, System.Win.Registry, Winapi.Windows, Winapi.Messages, Vcl.ActnList, Vcl.Controls, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
   Vcl.Forms, Vcl.Clipbrd,
   Vcl.Graphics, Vcl.Menus, Vcl.Imaging.pngimage, ToolsAPI, Mcp.Server, Mcp.Types;

type
   TMcpCompileEvent = class
   public
      EventName: string;
      ProjectFileName: string;
      ModeText: string;
      ResultText: string;
      Configuration: string;
      Platform: string;
      SuccessKnown: boolean;
      Success: boolean;
      function ToJson: TJSONObject;
   end;

   TMcpIdeBridge = class;

   TMcpIdeCompileNotifier = class(TInterfacedObject, IOTACompileNotifier)
   private
      FBridge: TMcpIdeBridge;
   public
      constructor Create(ABridge: TMcpIdeBridge);
      procedure ProjectCompileStarted(const Project: IOTAProject; Mode: TOTACompileMode);
      procedure ProjectCompileFinished(const Project: IOTAProject; Result: TOTACompileResult);
      procedure ProjectGroupCompileStarted(Mode: TOTACompileMode);
      procedure ProjectGroupCompileFinished(Result: TOTACompileResult);
   end;

   TMcpIdeProjectCompileNotifier = class(TInterfacedObject, IOTAProjectCompileNotifier)
   private
      FBridge: TMcpIdeBridge;
      FProjectFileName: string;
   public
      constructor Create(ABridge: TMcpIdeBridge; const AProjectFileName: string);
      procedure AfterCompile(var CompileInfo: TOTAProjectCompileInfo);
      procedure BeforeCompile(var CompileInfo: TOTAProjectCompileInfo);
      procedure Destroyed;
   end;

   TMcpIdeBridge = class
   private
      FServer: TMcpServer;
      FOwnerId: string;
      FCompileNotifier: IOTACompileNotifier;
      FCompileNotifierIndex: integer;
      FCompileEvents: TObjectList<TMcpCompileEvent>;
      FActionList: TActionList;
      FRootMenu: TMenuItem;
      FStartAction: TAction;
      FStopAction: TAction;
      FRestartAction: TAction;
      FStatusAction: TAction;
      FSplashBitmap: TBitmap;
      function ModuleServices: IOTAModuleServices;
      function NtaServices: INTAServices;
      function ActionServices: IOTAActionServices;
      function CompileServices: IOTACompileServices;
      function DebuggerServices: IOTADebuggerServices;
      function EditorServices: IOTAEditorServices;
      function EditActions: IOTAEditActions;
      function ActiveProject: IOTAProject;
      function JsonProject(const Project: IOTAProject): TJSONObject;
      function JsonModuleInfo(const ModuleInfo: IOTAModuleInfo): TJSONObject;
      function JsonModule(const Module: IOTAModule): TJSONObject;
      function JsonProcess(const Process: IOTAProcess): TJSONObject;
      function JsonThread(const Thread: IOTAThread; const CurrentThread: IOTAThread; Index: integer): TJSONObject;
      function JsonBreakpoint(const Breakpoint: IOTABreakpoint): TJSONObject;
      function JsonSourceLineInfo(const FileName: string; Line: integer): TJSONObject;
      function JsonWindow(const Wnd: HWND; IncludeText: boolean): TJSONObject;
      function JsonVclComponent(const Component: TComponent; Depth, MaxDepth: integer; IncludeProperties: boolean): TJSONObject;
      procedure CollectVclDiagnosticTexts(const Component: TComponent; Depth, MaxDepth, MaxItems: integer;
         Texts: TJSONArray; var Total: integer);
      function JsonVclDiagnosticForm(const Form: TCustomForm; MaxDepth, MaxTextItems: integer): TJSONObject;
      function JsonRttiSummary(const Instance: TObject; const NameContains: string; MaxItems: integer): TJSONObject;
      function FindVclWinControl(const Root: TWinControl; const NameContains, ClassContains: string): TWinControl;
      function VclTreeTextByForm(const FormClassContains, FormNameContains, FormCaptionContains, ControlNameContains,
         ControlClassContains: string; VisibleOnly: boolean; MaxRows, MaxColumns: integer): TJSONValue;
      function ExtractVirtualTreeRowsFromControl(const Control: TWinControl; MaxRows, MaxColumns: integer; out RowCount: integer;
         out Truncated: boolean; out ControlClassName, ControlName: string): TJSONArray;
      function ExtractVirtualTreeRowsViaClipboard(const Control: TWinControl; MaxRows, MaxColumns: integer; out RowCount: integer;
         out Truncated: boolean): TJSONArray;
      function ExtractVirtualTreeRows(const Wnd: HWND; MaxRows, MaxColumns: integer; out RowCount: integer;
         out Truncated: boolean; out ControlClassName, ControlName: string): TJSONArray;
      function CompileModeFromText(const Value: string): TOTACompileMode;
      function CompileModeText(Mode: TOTACompileMode): string;
      function CompileResultText(Value: TOTACompileResult): string;
      procedure AddCompileEvent(const EventName: string; const Project: IOTAProject; Mode: TOTACompileMode); overload;
      procedure AddCompileEvent(const EventName: string; const Project: IOTAProject; Value: TOTACompileResult); overload;
      procedure AddProjectCompileInfoEvent(const EventName, ProjectFileName: string; const CompileInfo: TOTAProjectCompileInfo;
         IncludeResult: boolean);
      procedure AddProjectGroupCompileEvent(const EventName: string; Mode: TOTACompileMode); overload;
      procedure AddProjectGroupCompileEvent(const EventName: string; Value: TOTACompileResult); overload;
      procedure ClearCompileEvents;
      function JsonCompileEvents: TJSONArray;
      procedure RegisterCompileNotifier;
      procedure UnregisterCompileNotifier;
      function IsSelfPackageProject(const ProjectFileName: string): boolean;
      function DebugCommandResult(const Command: string): TJSONValue;
      function UnsupportedDebugCommandResult(const Command, Reason: string): TJSONValue;
      function IdeControlGuideText: string;
      function IdeDebugWorkflowGuideText: string;
      function ListIdeResources: TJSONArray;
      function ReadIdeResource(const Uri: string): TJSONObject;
      function ListIdePrompts: TJSONArray;
      function GetIdePrompt(const PromptName: string): TJSONObject;
      function StatusText: string;
      function CreateAction(const Name, Caption: string; Handler: TNotifyEvent): TAction;
      function CreateSplashBitmap: TBitmap;
      procedure AddSplashInfo;
      procedure PublishServerDiscovery(Active: boolean);
      procedure RegisterIdeMenu;
      procedure UnregisterIdeMenu;
      procedure ActionStart(Sender: TObject);
      procedure ActionStop(Sender: TObject);
      procedure ActionRestart(Sender: TObject);
      procedure ActionStatus(Sender: TObject);
      function ToolIdePing(const Arguments: TJSONObject): TJSONValue;
      function ToolIdeStatus(const Arguments: TJSONObject): TJSONValue;
      function ToolListActions(const Arguments: TJSONObject): TJSONValue;
      function ToolExecuteAction(const Arguments: TJSONObject): TJSONValue;
      function ToolGetActiveProject(const Arguments: TJSONObject): TJSONValue;
      function ToolSetActiveProject(const Arguments: TJSONObject): TJSONValue;
      function ToolListProjects(const Arguments: TJSONObject): TJSONValue;
      function ToolListProjectModules(const Arguments: TJSONObject): TJSONValue;
      function ToolGetCurrentModule(const Arguments: TJSONObject): TJSONValue;
      function ToolOpenFile(const Arguments: TJSONObject): TJSONValue;
      function ToolCloseFile(const Arguments: TJSONObject): TJSONValue;
      function ToolSaveAll(const Arguments: TJSONObject): TJSONValue;
      function ToolExitIde(const Arguments: TJSONObject): TJSONValue;
      function ToolCloseSaveDialogs(const Arguments: TJSONObject): TJSONValue;
      function ToolListWindows(const Arguments: TJSONObject): TJSONValue;
      function ToolInspectWindow(const Arguments: TJSONObject): TJSONValue;
      function ToolInspectVclControl(const Arguments: TJSONObject): TJSONValue;
      function ToolListVclComponents(const Arguments: TJSONObject): TJSONValue;
      function ToolListVclForms(const Arguments: TJSONObject): TJSONValue;
      function ToolGetVclTreeText(const Arguments: TJSONObject): TJSONValue;
      function ToolGetVirtualTreeText(const Arguments: TJSONObject): TJSONValue;
      function ToolGetBuildMessages(const Arguments: TJSONObject): TJSONValue;
      function ToolGetDiagnostics(const Arguments: TJSONObject): TJSONValue;
      function ToolCloseBuildDialogs(const Arguments: TJSONObject): TJSONValue;
      function ToolBuildProjectByAction(const Arguments: TJSONObject): TJSONValue;
      function ToolBuildProject(const Arguments: TJSONObject): TJSONValue;
      function ToolGetBuildEvents(const Arguments: TJSONObject): TJSONValue;
      function ToolDebugStatus(const Arguments: TJSONObject): TJSONValue;
      function ToolListBreakpoints(const Arguments: TJSONObject): TJSONValue;
      function ToolInspectSourceLine(const Arguments: TJSONObject): TJSONValue;
      function ToolAddSourceBreakpoint(const Arguments: TJSONObject): TJSONValue;
      function ToolRemoveSourceBreakpoint(const Arguments: TJSONObject): TJSONValue;
      function ToolRunProgram(const Arguments: TJSONObject): TJSONValue;
      function ToolProgramReset(const Arguments: TJSONObject): TJSONValue;
      function ToolPauseProgram(const Arguments: TJSONObject): TJSONValue;
      function ToolGetDebugCallstack(const Arguments: TJSONObject): TJSONValue;
      function ToolGetDebugThreads(const Arguments: TJSONObject): TJSONValue;
      function ToolEvaluateExpression(const Arguments: TJSONObject): TJSONValue;
      function ToolGetCurrentSourceLocation(const Arguments: TJSONObject): TJSONValue;
      function ToolStepOut(const Arguments: TJSONObject): TJSONValue;
      function ToolStepOver(const Arguments: TJSONObject): TJSONValue;
      function ToolTraceInto(const Arguments: TJSONObject): TJSONValue;
      function ToolRunToCursor(const Arguments: TJSONObject): TJSONValue;
      procedure RegisterTools;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Start;
      procedure Stop;
      property Server: TMcpServer read FServer;
   end;

procedure RegisterIdeMcpBridge;
procedure UnregisterIdeMcpBridge;

implementation

{$R McpIdeBridgeIcon.res}

const
   TV_FIRST = $1100;
   TVM_GETCOUNT = TV_FIRST + 5;
   TVM_GETNEXTITEM = TV_FIRST + 10;
   TVM_GETITEMHEIGHT = TV_FIRST + 28;
   TVGN_ROOT = 0;
   TVGN_NEXT = 1;
   TVGN_CHILD = 4;
   TVGN_CARET = 9;

   LVM_FIRST = $1000;
   LVM_GETITEMCOUNT = LVM_FIRST + 4;
   LVM_GETNEXTITEM = LVM_FIRST + 12;
   LVM_GETSELECTEDCOUNT = LVM_FIRST + 50;
   LVNI_SELECTED = $0002;

var
   GIdeBridge: TMcpIdeBridge = nil;

type
   TMcpBuildProgressCloser = class
   private
      FTimer: TTimer;
      FClosedCount: integer;
      FOpenCount: integer;
      function ComponentTextContains(const Component: TComponent; const Needle: string): boolean;
      function FindButton(const Component: TComponent; const NameOrCaption: string): TButton;
      procedure Timer(Sender: TObject);
   public
      constructor Create;
      destructor Destroy; override;
      function CloseFailedProgressDialogs: integer;
      procedure Start;
      procedure Stop;
      property OpenCount: integer read FOpenCount;
      property ClosedCount: integer read FClosedCount;
   end;

   TMcpIdeBuildStarter = class
   private
      FTimer: TTimer;
      FBuilder: IOTAProjectBuilder;
      FMode: TOTACompileMode;
      FClearMessages: boolean;
      FStarted: boolean;
      FFinished: boolean;
      FOk: boolean;
      FError: string;
      procedure Timer(Sender: TObject);
   public
      constructor Create(const ABuilder: IOTAProjectBuilder; Mode: TOTACompileMode; ClearMessages: boolean);
      destructor Destroy; override;
      procedure Start;
      property Started: boolean read FStarted;
      property Finished: boolean read FFinished;
      property Ok: boolean read FOk;
      property Error: string read FError;
   end;

   PMcpWindowEnumContext = ^TMcpWindowEnumContext;
   TMcpWindowEnumContext = record
      Bridge: TMcpIdeBridge;
      Windows: TJSONArray;
      Seen: TList<HWND>;
      IncludeInvisible: boolean;
      IncludeText: boolean;
      TextContains: string;
      ClassContains: string;
      MaxItems: integer;
      TotalVisited: integer;
      TotalMatched: integer;
   end;

   PMcpFindWindowContext = ^TMcpFindWindowContext;
   TMcpFindWindowContext = record
      ClassContains: string;
      TextContains: string;
      IncludeInvisible: boolean;
      Found: HWND;
   end;

   PMcpCloseDialogContext = ^TMcpCloseDialogContext;
   TMcpCloseDialogContext = record
      ProcessId: Cardinal;
      OpenCount: integer;
      ClosedCount: integer;
   end;

   PMcpCloseSaveDialogContext = ^TMcpCloseSaveDialogContext;
   TMcpCloseSaveDialogContext = record
      ProcessId: Cardinal;
      Action: string;
      OpenCount: integer;
      ClosedCount: integer;
   end;

function McpCloseBuildDialogEnumProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
   Context: PMcpCloseDialogContext;
   Pid: Cardinal;
   TitleBuffer, ClassBuffer: array[0..255] of Char;
   Title, ClassName, Combined: string;
begin
   result := true;
   Context := PMcpCloseDialogContext(LParam);
   if (Context = nil) or (Wnd = 0) or (not IsWindowVisible(Wnd)) then begin
      exit;
   end;

   Pid := 0;
   GetWindowThreadProcessId(Wnd, @Pid);
   if Pid <> Context.ProcessId then begin
      exit;
   end;

   SetString(Title, TitleBuffer, GetWindowText(Wnd, TitleBuffer, Length(TitleBuffer)));
   SetString(ClassName, ClassBuffer, GetClassName(Wnd, ClassBuffer, Length(ClassBuffer)));
   Combined := LowerCase(Title + ' ' + ClassName);

   if (Pos('compilier', Combined) > 0) or
      (Pos('tprogressform', Combined) > 0) or
      (Pos('informationen', Combined) > 0) then begin
      Inc(Context.OpenCount);
      PostMessage(Wnd, WM_COMMAND, IDOK, 0);
      PostMessage(Wnd, WM_KEYDOWN, VK_RETURN, 0);
      PostMessage(Wnd, WM_KEYUP, VK_RETURN, 0);
      PostMessage(Wnd, WM_CLOSE, 0, 0);
      Inc(Context.ClosedCount);
   end;
end;

function McpCloseSaveDialogEnumProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
   Context: PMcpCloseSaveDialogContext;
   Pid: Cardinal;
   TitleBuffer, ClassBuffer: array[0..255] of Char;
   Title, ClassName, Combined: string;
   CommandId: WPARAM;
begin
   result := true;
   Context := PMcpCloseSaveDialogContext(LParam);
   if (Context = nil) or (Wnd = 0) or (not IsWindowVisible(Wnd)) then begin
      exit;
   end;

   Pid := 0;
   GetWindowThreadProcessId(Wnd, @Pid);
   if Pid <> Context.ProcessId then begin
      exit;
   end;

   SetString(Title, TitleBuffer, GetWindowText(Wnd, TitleBuffer, Length(TitleBuffer)));
   SetString(ClassName, ClassBuffer, GetClassName(Wnd, ClassBuffer, Length(ClassBuffer)));
   Combined := LowerCase(Title + ' ' + ClassName);

   if (Pos('speicher', Combined) = 0) and
      (Pos('save', Combined) = 0) and
      (Pos('best', Combined) = 0) and
      (Pos('confirm', Combined) = 0) then begin
      exit;
   end;

   Inc(Context.OpenCount);
   CommandId := IDCANCEL;
   if SameText(Context.Action, 'save') then begin
      CommandId := IDYES;
   end
   else if SameText(Context.Action, 'discard') or SameText(Context.Action, 'no') then begin
      CommandId := IDNO;
   end;

   PostMessage(Wnd, WM_COMMAND, CommandId, 0);
   if CommandId = IDNO then begin
      PostMessage(Wnd, WM_KEYDOWN, Ord('N'), 0);
      PostMessage(Wnd, WM_KEYUP, Ord('N'), 0);
   end
   else if CommandId = IDYES then begin
      PostMessage(Wnd, WM_KEYDOWN, Ord('Y'), 0);
      PostMessage(Wnd, WM_KEYUP, Ord('Y'), 0);
   end
   else begin
      PostMessage(Wnd, WM_KEYDOWN, VK_ESCAPE, 0);
      PostMessage(Wnd, WM_KEYUP, VK_ESCAPE, 0);
   end;
   Inc(Context.ClosedCount);
end;

constructor TMcpBuildProgressCloser.Create;
begin
   inherited Create;
   FTimer := TTimer.Create(nil);
   FTimer.Enabled := false;
   FTimer.Interval := 250;
   FTimer.OnTimer := Timer;
end;

destructor TMcpBuildProgressCloser.Destroy;
begin
   FTimer.Free;
   inherited Destroy;
end;

function TMcpBuildProgressCloser.ComponentTextContains(const Component: TComponent; const Needle: string): boolean;
const
   TextPropertyNames: array[0..3] of string = ('Caption', 'Text', 'SimpleText', 'Hint');
var
   PropInfo: PPropInfo;
   PropName, Value: string;
   WinControl: TWinControl;
   i: integer;
begin
   result := false;
   if Component = nil then begin
      exit;
   end;

   for PropName in TextPropertyNames do begin
      PropInfo := GetPropInfo(Component.ClassInfo, PropName);
      if PropInfo = nil then begin
         continue;
      end;
      try
         Value := LowerCase(VarToStr(GetPropValue(Component, PropName, true)));
      except
         Value := '';
      end;
      if (Value <> '') and (Pos(Needle, Value) > 0) then begin
         result := true;
         exit;
      end;
   end;

   for i := 0 to Component.ComponentCount - 1 do begin
      if ComponentTextContains(Component.Components[i], Needle) then begin
         result := true;
         exit;
      end;
   end;

   if Component is TWinControl then begin
      WinControl := TWinControl(Component);
      for i := 0 to WinControl.ControlCount - 1 do begin
         if ComponentTextContains(WinControl.Controls[i], Needle) then begin
            result := true;
            exit;
         end;
      end;
   end;
end;

function TMcpBuildProgressCloser.FindButton(const Component: TComponent; const NameOrCaption: string): TButton;
var
   WinControl: TWinControl;
   Button: TButton;
   i: integer;
begin
   result := nil;
   if Component = nil then begin
      exit;
   end;

   if Component is TButton then begin
      Button := TButton(Component);
      if SameText(Button.Name, NameOrCaption) or SameText(Button.Caption, NameOrCaption) then begin
         result := Button;
         exit;
      end;
   end;

   for i := 0 to Component.ComponentCount - 1 do begin
      result := FindButton(Component.Components[i], NameOrCaption);
      if result <> nil then begin
         exit;
      end;
   end;

   if Component is TWinControl then begin
      WinControl := TWinControl(Component);
      for i := 0 to WinControl.ControlCount - 1 do begin
         result := FindButton(WinControl.Controls[i], NameOrCaption);
         if result <> nil then begin
            exit;
         end;
      end;
   end;
end;

function TMcpBuildProgressCloser.CloseFailedProgressDialogs: integer;
var
   Form: TCustomForm;
   Button: TButton;
   Context: TMcpCloseDialogContext;
   i: integer;
   Failed: boolean;
begin
   result := 0;
   FOpenCount := 0;
   for i := 0 to Screen.FormCount - 1 do begin
      Form := Screen.Forms[i];
      if (Form = nil) or (not Form.Visible) or (not SameText(Form.ClassName, 'TProgressForm')) then begin
         continue;
      end;

      Failed := ComponentTextContains(Form, 'fehlgeschlagen') or
         ComponentTextContains(Form, 'fehler sind aufgetreten') or
         ComponentTextContains(Form, 'fehler:') or
         ((Pos('compilier', LowerCase(Form.Caption)) > 0) and ComponentTextContains(Form, 'fehler'));
      if not Failed then begin
         continue;
      end;

      Inc(FOpenCount);
      Button := FindButton(Form, 'CancelButton');
      if Button = nil then begin
         Button := FindButton(Form, 'OK');
      end;
      if Button = nil then begin
         Button := FindButton(Form, '&OK');
      end;
      if Button = nil then begin
         Button := FindButton(Form, 'Schließen');
      end;
      if (Button <> nil) and Button.Visible and Button.Enabled then begin
         Button.Click;
      end;

      Form.ModalResult := mrOk;
      PostMessage(Form.Handle, WM_COMMAND, IDOK, 0);
      PostMessage(Form.Handle, WM_KEYDOWN, VK_RETURN, 0);
      PostMessage(Form.Handle, WM_KEYUP, VK_RETURN, 0);
      PostMessage(Form.Handle, WM_CLOSE, 0, 0);
      Inc(FClosedCount);
      Inc(result);
   end;

   Context.ProcessId := GetCurrentProcessId;
   Context.OpenCount := 0;
   Context.ClosedCount := 0;
   EnumWindows(@McpCloseBuildDialogEnumProc, LPARAM(@Context));
   if Context.OpenCount > 0 then begin
      Inc(FOpenCount, Context.OpenCount);
      Inc(FClosedCount, Context.ClosedCount);
      Inc(result, Context.ClosedCount);
   end;
end;

procedure TMcpBuildProgressCloser.Timer(Sender: TObject);
begin
   CloseFailedProgressDialogs;
end;

procedure TMcpBuildProgressCloser.Start;
begin
   FOpenCount := 0;
   FClosedCount := 0;
   FTimer.Enabled := true;
end;

procedure TMcpBuildProgressCloser.Stop;
begin
   FTimer.Enabled := false;
end;

constructor TMcpIdeBuildStarter.Create(const ABuilder: IOTAProjectBuilder; Mode: TOTACompileMode; ClearMessages: boolean);
begin
   inherited Create;
   FBuilder := ABuilder;
   FMode := Mode;
   FClearMessages := ClearMessages;
   FTimer := TTimer.Create(nil);
   FTimer.Enabled := false;
   FTimer.Interval := 1;
   FTimer.OnTimer := Timer;
end;

destructor TMcpIdeBuildStarter.Destroy;
begin
   FTimer.Free;
   inherited Destroy;
end;

procedure TMcpIdeBuildStarter.Start;
begin
   FStarted := false;
   FFinished := false;
   FOk := false;
   FError := '';
   FTimer.Enabled := true;
end;

procedure TMcpIdeBuildStarter.Timer(Sender: TObject);
begin
   FTimer.Enabled := false;
   FStarted := true;
   try
      FOk := FBuilder.BuildProject(FMode, false, FClearMessages);
   except
      on E: Exception do begin
         FOk := false;
         FError := E.Message;
      end;
   end;
   FFinished := true;
end;

function McpWindowText(Wnd: HWND): string;
var
   Len: integer;
begin
   Len := GetWindowTextLength(Wnd);
   if Len <= 0 then begin
      result := '';
      exit;
   end;
   SetLength(result, Len + 1);
   SetLength(result, GetWindowText(Wnd, PChar(result), Len + 1));
end;

function McpWindowClassName(Wnd: HWND): string;
var
   Buffer: array[0..255] of Char;
begin
   SetString(result, Buffer, GetClassName(Wnd, Buffer, Length(Buffer)));
end;

function McpWindowContains(const Value, Filter: string): boolean;
begin
   result := (Filter = '') or (Pos(Filter, LowerCase(Value)) > 0);
end;

function McpParamFlagsText(Flags: TParamFlags): string;
var
   Flag: TParamFlag;
begin
   result := '';
   for Flag := Low(TParamFlag) to High(TParamFlag) do begin
      if Flag in Flags then begin
         if result <> '' then begin
            result := result + ',';
         end;
         result := result + GetEnumName(TypeInfo(TParamFlag), Ord(Flag));
      end;
   end;
end;

function McpSummaryCount(const Value, Marker: string; const Default: integer): integer;
var
   Text: string;
   i: integer;
begin
   Text := Trim(Value);
   if Pos(Marker, Text) <= 0 then begin
      result := Default;
      exit;
   end;
   if Text = '' then begin
      result := Default;
      exit;
   end;
   for i := 1 to Length(Text) do begin
      if not CharInSet(Text[i], ['0'..'9']) then begin
         if i = 1 then begin
            result := Default;
         end
         else begin
            result := StrToIntDef(Copy(Text, 1, i - 1), Default);
         end;
         exit;
      end;
   end;
   result := StrToIntDef(Text, Default);
end;

function McpParseBuildDiagnostic(const Line: string): TJSONObject;
var
   OpenPos, ClosePos, ColonPos, CommaPos, SpacePos, PrefixClosePos: integer;
   WorkLine, PrefixText, LowerPrefix, FileName, PositionText, LineText, ColumnText, Rest, LowerRest, Severity, Code,
      MessageText, FirstToken: string;
   LineNumber, ColumnNumber: integer;
begin
   result := nil;
   WorkLine := Trim(Line);
   Severity := '';

   if Pos('[', WorkLine) = 1 then begin
      PrefixClosePos := Pos(']', WorkLine);
      if PrefixClosePos > 2 then begin
         PrefixText := Copy(WorkLine, 2, PrefixClosePos - 2);
         LowerPrefix := LowerCase(PrefixText);
         if (Pos('fatal', LowerPrefix) > 0) or (Pos('fataler fehler', LowerPrefix) > 0) then begin
            Severity := 'fatal';
         end
         else if (Pos('error', LowerPrefix) > 0) or (Pos('fehler', LowerPrefix) > 0) then begin
            Severity := 'error';
         end
         else if (Pos('warning', LowerPrefix) > 0) or (Pos('warnung', LowerPrefix) > 0) then begin
            Severity := 'warning';
         end
         else if (Pos('hint', LowerPrefix) > 0) or (Pos('hinweis', LowerPrefix) > 0) then begin
            Severity := 'hint';
         end;
         WorkLine := Trim(Copy(WorkLine, PrefixClosePos + 1, MaxInt));
      end;
   end;

   OpenPos := LastDelimiter('(', WorkLine);
   ClosePos := Pos('):', WorkLine);
   if (OpenPos <= 1) or (ClosePos <= OpenPos) then begin
      exit;
   end;

   FileName := Trim(Copy(WorkLine, 1, OpenPos - 1));
   PositionText := Copy(WorkLine, OpenPos + 1, ClosePos - OpenPos - 1);
   CommaPos := Pos(',', PositionText);
   if CommaPos > 0 then begin
      LineText := Copy(PositionText, 1, CommaPos - 1);
      ColumnText := Copy(PositionText, CommaPos + 1, MaxInt);
   end
   else begin
      LineText := PositionText;
      ColumnText := '';
   end;

   LineNumber := StrToIntDef(Trim(LineText), -1);
   ColumnNumber := StrToIntDef(Trim(ColumnText), -1);
   if (FileName = '') or (LineNumber < 0) then begin
      exit;
   end;

   Rest := Trim(Copy(WorkLine, ClosePos + 2, MaxInt));
   LowerRest := LowerCase(Rest);
   if Severity = '' then begin
      if Pos('fatal', LowerRest) = 1 then begin
         Severity := 'fatal';
      end
      else if Pos('error', LowerRest) = 1 then begin
         Severity := 'error';
      end
      else if Pos('warning', LowerRest) = 1 then begin
         Severity := 'warning';
      end
      else if Pos('hint', LowerRest) = 1 then begin
         Severity := 'hint';
      end
      else begin
         exit;
      end;
   end;

   Code := '';
   MessageText := Rest;
   SpacePos := Pos(' ', Rest);
   ColonPos := Pos(':', Rest);
   if SpacePos > 0 then begin
      FirstToken := Trim(Copy(Rest, 1, SpacePos - 1));
      if (Length(FirstToken) > 1) and CharInSet(FirstToken[1], ['A'..'Z', 'a'..'z']) and
         (StrToIntDef(Copy(FirstToken, 2, MaxInt), -1) >= 0) then begin
         Code := FirstToken;
         MessageText := Trim(Copy(Rest, SpacePos + 1, MaxInt));
      end
      else if ColonPos > SpacePos then begin
         Code := Trim(Copy(Rest, SpacePos + 1, ColonPos - SpacePos - 1));
         MessageText := Trim(Copy(Rest, ColonPos + 1, MaxInt));
      end;
   end;

   result := TJSONObject.Create;
   result.AddPair('fileName', FileName);
   result.AddPair('line', TJSONNumber.Create(LineNumber));
   if ColumnNumber >= 0 then begin
      result.AddPair('column', TJSONNumber.Create(ColumnNumber));
   end;
   result.AddPair('severity', Severity);
   if Code <> '' then begin
      result.AddPair('code', Code);
   end;
   result.AddPair('message', MessageText);
   result.AddPair('raw', Line);
end;

function McpAddWindowToContext(Wnd: HWND; Context: PMcpWindowEnumContext): boolean;
var
   Text, ClassName: string;
begin
   result := Context <> nil;
   if not result then begin
      exit;
   end;

   Inc(Context.TotalVisited);
   if (Context.MaxItems > 0) and (Context.TotalMatched >= Context.MaxItems) then begin
      result := false;
      exit;
   end;
   if Context.Seen.Contains(Wnd) then begin
      exit;
   end;
   Context.Seen.Add(Wnd);

   if (not Context.IncludeInvisible) and (not IsWindowVisible(Wnd)) then begin
      exit;
   end;

   Text := McpWindowText(Wnd);
   ClassName := McpWindowClassName(Wnd);
   if not McpWindowContains(Text, Context.TextContains) then begin
      exit;
   end;
   if not McpWindowContains(ClassName, Context.ClassContains) then begin
      exit;
   end;

   Context.Windows.AddElement(Context.Bridge.JsonWindow(Wnd, Context.IncludeText));
   Inc(Context.TotalMatched);
end;

function McpEnumChildWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
begin
   result := McpAddWindowToContext(Wnd, PMcpWindowEnumContext(LParam));
end;

function McpEnumThreadWindowsProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
begin
   result := McpAddWindowToContext(Wnd, PMcpWindowEnumContext(LParam));
   if result then begin
      EnumChildWindows(Wnd, @McpEnumChildWindowsProc, LParam);
   end;
end;

function McpFindWindowProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
   Context: PMcpFindWindowContext;
begin
   Context := PMcpFindWindowContext(LParam);
   result := Context <> nil;
   if not result then begin
      exit;
   end;

   if (not Context.IncludeInvisible) and (not IsWindowVisible(Wnd)) then begin
      exit;
   end;
   if not McpWindowContains(McpWindowClassName(Wnd), Context.ClassContains) then begin
      EnumChildWindows(Wnd, @McpFindWindowProc, LParam);
      result := Context.Found = 0;
      exit;
   end;
   if not McpWindowContains(McpWindowText(Wnd), Context.TextContains) then begin
      EnumChildWindows(Wnd, @McpFindWindowProc, LParam);
      result := Context.Found = 0;
      exit;
   end;

   Context.Found := Wnd;
   result := false;
end;

function McpFindThreadWindow(const ClassContains, TextContains: string; IncludeInvisible: boolean): HWND;
var
   Context: TMcpFindWindowContext;
begin
   Context.ClassContains := LowerCase(ClassContains);
   Context.TextContains := LowerCase(TextContains);
   Context.IncludeInvisible := IncludeInvisible;
   Context.Found := 0;
   EnumThreadWindows(GetCurrentThreadId, @McpFindWindowProc, LPARAM(@Context));
   result := Context.Found;
end;

function McpFindChildWindow(const RootWnd: HWND; const ClassContains, TextContains: string; IncludeInvisible: boolean): HWND;
var
   Context: TMcpFindWindowContext;
begin
   Context.ClassContains := LowerCase(ClassContains);
   Context.TextContains := LowerCase(TextContains);
   Context.IncludeInvisible := IncludeInvisible;
   Context.Found := 0;
   EnumChildWindows(RootWnd, @McpFindWindowProc, LPARAM(@Context));
   result := Context.Found;
end;

function TMcpCompileEvent.ToJson: TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('event', EventName);
   if ProjectFileName <> '' then begin
      result.AddPair('projectFileName', ProjectFileName);
   end;
   if ModeText <> '' then begin
      result.AddPair('mode', ModeText);
   end;
   if ResultText <> '' then begin
      result.AddPair('result', ResultText);
   end;
   if Configuration <> '' then begin
      result.AddPair('configuration', Configuration);
   end;
   if Platform <> '' then begin
      result.AddPair('platform', Platform);
   end;
   if SuccessKnown then begin
      result.AddPair('success', McpBoolValue(Success));
   end;
end;

constructor TMcpIdeCompileNotifier.Create(ABridge: TMcpIdeBridge);
begin
   inherited Create;
   FBridge := ABridge;
end;

procedure TMcpIdeCompileNotifier.ProjectCompileStarted(const Project: IOTAProject; Mode: TOTACompileMode);
begin
   if FBridge <> nil then begin
      FBridge.AddCompileEvent('project_compile_started', Project, Mode);
   end;
end;

procedure TMcpIdeCompileNotifier.ProjectCompileFinished(const Project: IOTAProject; Result: TOTACompileResult);
begin
   if FBridge <> nil then begin
      FBridge.AddCompileEvent('project_compile_finished', Project, Result);
   end;
end;

procedure TMcpIdeCompileNotifier.ProjectGroupCompileStarted(Mode: TOTACompileMode);
begin
   if FBridge <> nil then begin
      FBridge.AddProjectGroupCompileEvent('project_group_compile_started', Mode);
   end;
end;

procedure TMcpIdeCompileNotifier.ProjectGroupCompileFinished(Result: TOTACompileResult);
begin
   if FBridge <> nil then begin
      FBridge.AddProjectGroupCompileEvent('project_group_compile_finished', Result);
   end;
end;

constructor TMcpIdeProjectCompileNotifier.Create(ABridge: TMcpIdeBridge; const AProjectFileName: string);
begin
   inherited Create;
   FBridge := ABridge;
   FProjectFileName := AProjectFileName;
end;

procedure TMcpIdeProjectCompileNotifier.AfterCompile(var CompileInfo: TOTAProjectCompileInfo);
begin
   if FBridge <> nil then begin
      FBridge.AddProjectCompileInfoEvent('project_after_compile_info', FProjectFileName, CompileInfo, true);
   end;
end;

procedure TMcpIdeProjectCompileNotifier.BeforeCompile(var CompileInfo: TOTAProjectCompileInfo);
begin
   if FBridge <> nil then begin
      FBridge.AddProjectCompileInfoEvent('project_before_compile_info', FProjectFileName, CompileInfo, false);
   end;
end;

procedure TMcpIdeProjectCompileNotifier.Destroyed;
begin
   FBridge := nil;
end;

procedure RegisterIdeMcpBridge;
begin
   if GIdeBridge = nil then begin
      try
         GIdeBridge := TMcpIdeBridge.Create;
         GIdeBridge.Start;
      except
         on E: Exception do begin
            FreeAndNil(GIdeBridge);
            ShowMessage('MCP2Delphi IDE MCP Server konnte nicht gestartet werden:' + sLineBreak + E.Message);
         end;
      end;
   end;
end;

procedure UnregisterIdeMcpBridge;
begin
   FreeAndNil(GIdeBridge);
end;

constructor TMcpIdeBridge.Create;
begin
   inherited Create;
   FOwnerId := 'mcp2delphi.ide';
   FCompileNotifierIndex := -1;
   FCompileEvents := TObjectList<TMcpCompileEvent>.Create(true);
   FServer := TMcpServer.Create(nil);
   FServer.ServerName := 'delphi-ide';
   FServer.ServerVersion := '0.1.0';
   FServer.Port := 8776;
   FServer.BindHost := '127.0.0.1';
   FServer.AllowInIdeProcess := true;
end;

destructor TMcpIdeBridge.Destroy;
begin
   UnregisterCompileNotifier;
   Stop;
   UnregisterIdeMenu;
   FCompileEvents.Free;
   FSplashBitmap.Free;
   FServer.Free;
   inherited Destroy;
end;

function TMcpIdeBridge.ModuleServices: IOTAModuleServices;
begin
   if (BorlandIDEServices = nil) or not Supports(BorlandIDEServices, IOTAModuleServices, result) then begin
      raise Exception.Create('IOTAModuleServices ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.NtaServices: INTAServices;
begin
   if (BorlandIDEServices = nil) or not Supports(BorlandIDEServices, INTAServices, result) then begin
      raise Exception.Create('INTAServices ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.ActionServices: IOTAActionServices;
begin
   if (BorlandIDEServices = nil) or not Supports(BorlandIDEServices, IOTAActionServices, result) then begin
      raise Exception.Create('IOTAActionServices ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.CompileServices: IOTACompileServices;
begin
   if (BorlandIDEServices = nil) or not Supports(BorlandIDEServices, IOTACompileServices, result) then begin
      raise Exception.Create('IOTACompileServices ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.DebuggerServices: IOTADebuggerServices;
begin
   if (BorlandIDEServices = nil) or not Supports(BorlandIDEServices, IOTADebuggerServices, result) then begin
      raise Exception.Create('IOTADebuggerServices ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.EditorServices: IOTAEditorServices;
begin
   if (BorlandIDEServices = nil) or not Supports(BorlandIDEServices, IOTAEditorServices, result) then begin
      raise Exception.Create('IOTAEditorServices ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.EditActions: IOTAEditActions;
var
   View: IOTAEditView;
begin
   View := EditorServices.TopView;
   if (View = nil) or not Supports(View, IOTAEditActions, result) then begin
      raise Exception.Create('IOTAEditActions ist nicht verfuegbar.');
   end;
end;

function TMcpIdeBridge.StatusText: string;
begin
   if (FServer <> nil) and FServer.Active then begin
      result := 'MCP2Delphi IDE MCP Server ist aktiv.' + sLineBreak + FServer.Url;
   end
   else begin
      result := 'MCP2Delphi IDE MCP Server ist gestoppt.' + sLineBreak + FServer.Url;
   end;
end;

function TMcpIdeBridge.CreateAction(const Name, Caption: string; Handler: TNotifyEvent): TAction;
begin
   result := TAction.Create(FActionList);
   result.Name := Name;
   result.Caption := Caption;
   result.OnExecute := Handler;
   result.ActionList := FActionList;
end;

function TMcpIdeBridge.CreateSplashBitmap: TBitmap;
var
   ResourceStream: TResourceStream;
   Png: TPngImage;
begin
   result := TBitmap.Create;
   result.SetSize(24, 24);
   result.PixelFormat := pf24bit;
   result.Canvas.Brush.Color := clFuchsia;
   result.Canvas.FillRect(Rect(0, 0, 24, 24));

   ResourceStream := TResourceStream.Create(HInstance, 'MCP_IDE_SPLASH', RT_RCDATA);
   try
      Png := TPngImage.Create;
      try
         Png.LoadFromStream(ResourceStream);
         result.Canvas.Draw(0, 0, Png);
      finally
         Png.Free;
      end;
   finally
      ResourceStream.Free;
   end;

   result.Canvas.Pixels[0, 23] := clFuchsia;
end;

procedure TMcpIdeBridge.AddSplashInfo;
var
   Caption: string;
begin
   if SplashScreenServices = nil then begin
      exit;
   end;
   if FSplashBitmap = nil then begin
      FSplashBitmap := CreateSplashBitmap;
   end;
   Caption := 'MCP2Delphi IDE MCP Server: ' + FServer.Url;
   SplashScreenServices.AddPluginBitmap(Caption, FSplashBitmap.Handle, false, 'active');
end;

procedure TMcpIdeBridge.PublishServerDiscovery(Active: boolean);
var
   Registry: TRegistry;
begin
   if FServer = nil then begin
      exit;
   end;

   Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
   try
      try
         Registry.RootKey := HKEY_CURRENT_USER;
         if Registry.OpenKey('\Software\MCP2Delphi\IDE', true) then begin
            Registry.WriteBool('Active', Active and FServer.Active);
            Registry.WriteString('ServerName', FServer.ServerName);
            Registry.WriteString('Url', FServer.Url);
            Registry.WriteString('BindHost', FServer.BindHost);
            Registry.WriteInteger('ConfiguredPort', FServer.Port);
            Registry.WriteInteger('ActivePort', FServer.ActivePort);
            Registry.WriteInteger('ProcessId', GetCurrentProcessId);
            Registry.WriteString('ProcessName', ExtractFileName(ParamStr(0)));
            Registry.WriteString('UpdatedAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
         end;
      except
         // Discovery must never prevent the IDE server from starting or stopping.
      end;
   finally
      Registry.Free;
   end;
end;

procedure TMcpIdeBridge.RegisterIdeMenu;
var
   MainMenu: TMainMenu;
   Item: TMenuItem;
begin
   if FRootMenu <> nil then begin
      exit;
   end;

   MainMenu := NtaServices.MainMenu;
   if MainMenu = nil then begin
      exit;
   end;

   FActionList := TActionList.Create(nil);
   FStartAction := CreateAction('Mcp2DelphiIdeStartAction', 'Start Server', ActionStart);
   FStopAction := CreateAction('Mcp2DelphiIdeStopAction', 'Stop Server', ActionStop);
   FRestartAction := CreateAction('Mcp2DelphiIdeRestartAction', 'Restart Server', ActionRestart);
   FStatusAction := CreateAction('Mcp2DelphiIdeStatusAction', 'Server Status...', ActionStatus);

   FRootMenu := TMenuItem.Create(MainMenu);
   FRootMenu.Name := 'Mcp2DelphiIdeMenu';
   FRootMenu.Caption := 'MCP2Delphi';

   Item := TMenuItem.Create(FRootMenu);
   Item.Action := FStatusAction;
   FRootMenu.Add(Item);

   Item := TMenuItem.Create(FRootMenu);
   Item.Caption := '-';
   FRootMenu.Add(Item);

   Item := TMenuItem.Create(FRootMenu);
   Item.Action := FStartAction;
   FRootMenu.Add(Item);

   Item := TMenuItem.Create(FRootMenu);
   Item.Action := FStopAction;
   FRootMenu.Add(Item);

   Item := TMenuItem.Create(FRootMenu);
   Item.Action := FRestartAction;
   FRootMenu.Add(Item);

   MainMenu.Items.Add(FRootMenu);
end;

procedure TMcpIdeBridge.UnregisterIdeMenu;
begin
   if FRootMenu <> nil then begin
      FRootMenu.Free;
      FRootMenu := nil;
   end;
   FreeAndNil(FActionList);
end;

procedure TMcpIdeBridge.ActionStart(Sender: TObject);
begin
   Start;
   ShowMessage(StatusText);
end;

procedure TMcpIdeBridge.ActionStop(Sender: TObject);
begin
   Stop;
   ShowMessage(StatusText);
end;

procedure TMcpIdeBridge.ActionRestart(Sender: TObject);
begin
   Stop;
   Start;
   ShowMessage(StatusText);
end;

procedure TMcpIdeBridge.ActionStatus(Sender: TObject);
begin
   ShowMessage(StatusText);
end;

function TMcpIdeBridge.ActiveProject: IOTAProject;
begin
   result := ModuleServices.GetActiveProject;
   if result = nil then begin
      raise Exception.Create('Kein aktives Delphi-Projekt gefunden.');
   end;
end;

function TMcpIdeBridge.JsonProject(const Project: IOTAProject): TJSONObject;
begin
   result := TJSONObject.Create;
   if Project = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;
   result.AddPair('available', McpBoolValue(true));
   result.AddPair('fileName', Project.FileName);
   result.AddPair('applicationType', Project.ApplicationType);
   result.AddPair('moduleCount', TJSONNumber.Create(Project.GetModuleCount));
   if Project.GetProjectBuilder <> nil then begin
      result.AddPair('shouldBuild', McpBoolValue(Project.GetProjectBuilder.GetShouldBuild));
   end;
end;

function TMcpIdeBridge.JsonModuleInfo(const ModuleInfo: IOTAModuleInfo): TJSONObject;
begin
   result := TJSONObject.Create;
   if ModuleInfo = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;
   result.AddPair('available', McpBoolValue(true));
   result.AddPair('name', ModuleInfo.Name);
   result.AddPair('fileName', ModuleInfo.FileName);
   result.AddPair('formName', ModuleInfo.FormName);
   result.AddPair('designClass', ModuleInfo.DesignClass);
   result.AddPair('moduleType', TJSONNumber.Create(Ord(ModuleInfo.ModuleType)));
   result.AddPair('buildAction', ModuleInfo.BuildAction);
end;

function TMcpIdeBridge.JsonModule(const Module: IOTAModule): TJSONObject;
begin
   result := TJSONObject.Create;
   if Module = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;
   result.AddPair('available', McpBoolValue(true));
   result.AddPair('fileName', Module.FileName);
   result.AddPair('fileSystem', Module.FileSystem);
   result.AddPair('moduleFileCount', TJSONNumber.Create(Module.GetModuleFileCount));
end;

function TMcpIdeBridge.JsonProcess(const Process: IOTAProcess): TJSONObject;
begin
   result := TJSONObject.Create;
   if Process = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;
   result.AddPair('available', McpBoolValue(true));
   result.AddPair('processType', TJSONNumber.Create(Ord(Process.GetProcessType)));
end;

function TMcpIdeBridge.JsonThread(const Thread: IOTAThread; const CurrentThread: IOTAThread; Index: integer): TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('index', TJSONNumber.Create(Index));
   if Thread = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;

   result.AddPair('available', McpBoolValue(true));
   result.AddPair('isCurrent', McpBoolValue((CurrentThread <> nil) and (Thread = CurrentThread)));
   try
      result.AddPair('osThreadId', TJSONNumber.Create(Thread.OSThreadID));
   except
      on E: Exception do begin
         result.AddPair('osThreadIdError', E.Message);
      end;
   end;
   try
      result.AddPair('displayString', Thread.DisplayString);
   except
      on E: Exception do begin
         result.AddPair('displayStringError', E.Message);
      end;
   end;
   try
      result.AddPair('threadName', Thread.ThreadName);
   except
      on E: Exception do begin
         result.AddPair('threadNameError', E.Message);
      end;
   end;
   try
      result.AddPair('state', TJSONNumber.Create(Ord(Thread.State)));
      result.AddPair('stateName', GetEnumName(TypeInfo(TOTAThreadState), Ord(Thread.State)));
   except
      on E: Exception do begin
         result.AddPair('stateError', E.Message);
      end;
   end;
   try
      result.AddPair('stateString', Thread.StateString);
   except
      on E: Exception do begin
         result.AddPair('stateStringError', E.Message);
      end;
   end;
   try
      result.AddPair('status', Thread.Status);
   except
      on E: Exception do begin
         result.AddPair('statusError', E.Message);
      end;
   end;
   try
      result.AddPair('location', Thread.Location);
   except
      on E: Exception do begin
         result.AddPair('locationError', E.Message);
      end;
   end;
   try
      result.AddPair('currentFile', Thread.CurrentFile);
      result.AddPair('currentLine', TJSONNumber.Create(Thread.CurrentLine));
   except
      on E: Exception do begin
         result.AddPair('currentLocationError', E.Message);
      end;
   end;
   try
      result.AddPair('callCount', TJSONNumber.Create(Thread.CallCount));
   except
      on E: Exception do begin
         result.AddPair('callCountError', E.Message);
      end;
   end;
end;

function TMcpIdeBridge.JsonBreakpoint(const Breakpoint: IOTABreakpoint): TJSONObject;
begin
   result := TJSONObject.Create;
   if Breakpoint = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;
   result.AddPair('available', McpBoolValue(true));
   result.AddPair('fileName', Breakpoint.FileName);
   result.AddPair('lineNumber', TJSONNumber.Create(Breakpoint.LineNumber));
   result.AddPair('enabled', McpBoolValue(Breakpoint.Enabled));
   result.AddPair('expression', Breakpoint.Expression);
   result.AddPair('passCount', TJSONNumber.Create(Breakpoint.PassCount));
   result.AddPair('currentPassCount', TJSONNumber.Create(Breakpoint.CurPassCount));
end;

function TMcpIdeBridge.JsonWindow(const Wnd: HWND; IncludeText: boolean): TJSONObject;
var
   Rect: TRect;
   Bounds: TJSONObject;
   ParentWnd: HWND;
   ProcessId: DWORD;
   ThreadId: DWORD;
begin
   result := TJSONObject.Create;
   result.AddPair('hwnd', IntToHex(NativeUInt(Wnd), SizeOf(HWND) * 2));
   ParentWnd := GetParent(Wnd);
   if ParentWnd <> 0 then begin
      result.AddPair('parentHwnd', IntToHex(NativeUInt(ParentWnd), SizeOf(HWND) * 2));
   end;
   result.AddPair('className', McpWindowClassName(Wnd));
   if IncludeText then begin
      result.AddPair('text', McpWindowText(Wnd));
   end;
   result.AddPair('visible', McpBoolValue(IsWindowVisible(Wnd)));
   result.AddPair('enabled', McpBoolValue(IsWindowEnabled(Wnd)));
   if GetWindowRect(Wnd, Rect) then begin
      Bounds := TJSONObject.Create;
      Bounds.AddPair('left', TJSONNumber.Create(Rect.Left));
      Bounds.AddPair('top', TJSONNumber.Create(Rect.Top));
      Bounds.AddPair('right', TJSONNumber.Create(Rect.Right));
      Bounds.AddPair('bottom', TJSONNumber.Create(Rect.Bottom));
      Bounds.AddPair('width', TJSONNumber.Create(Rect.Right - Rect.Left));
      Bounds.AddPair('height', TJSONNumber.Create(Rect.Bottom - Rect.Top));
      result.AddPair('bounds', Bounds);
   end;
   ProcessId := 0;
   ThreadId := GetWindowThreadProcessId(Wnd, @ProcessId);
   result.AddPair('threadId', TJSONNumber.Create(ThreadId));
   result.AddPair('processId', TJSONNumber.Create(ProcessId));
end;

function TMcpIdeBridge.JsonVclComponent(const Component: TComponent; Depth, MaxDepth: integer;
   IncludeProperties: boolean): TJSONObject;
const
   PropertyNames: array[0..20] of string = (
      'Name', 'Caption', 'Text', 'Hint', 'Visible', 'Enabled', 'Align', 'TabOrder', 'TabStop',
      'Left', 'Top', 'Width', 'Height', 'ClientWidth', 'ClientHeight', 'RootNodeCount',
      'TotalCount', 'VisibleCount', 'Focused', 'SimpleText', 'ModalResult'
   );
var
   Control: TControl;
   WinControl: TWinControl;
   Bounds: TJSONObject;
   Props: TJSONObject;
   Children: TJSONArray;
   Controls: TJSONArray;
   PropInfo: PPropInfo;
   PropName: string;
   i: integer;
begin
   result := TJSONObject.Create;
   if Component = nil then begin
      result.AddPair('available', McpBoolValue(false));
      exit;
   end;

   result.AddPair('available', McpBoolValue(true));
   result.AddPair('className', Component.ClassName);
   result.AddPair('name', Component.Name);
   if Component.Owner <> nil then begin
      result.AddPair('ownerClassName', Component.Owner.ClassName);
      result.AddPair('ownerName', Component.Owner.Name);
   end;
   result.AddPair('componentCount', TJSONNumber.Create(Component.ComponentCount));

   if Component is TControl then begin
      Control := TControl(Component);
      result.AddPair('visible', McpBoolValue(Control.Visible));
      result.AddPair('enabled', McpBoolValue(Control.Enabled));
      if Control.Parent <> nil then begin
         result.AddPair('parentClassName', Control.Parent.ClassName);
         result.AddPair('parentName', Control.Parent.Name);
      end;
      Bounds := TJSONObject.Create;
      Bounds.AddPair('left', TJSONNumber.Create(Control.Left));
      Bounds.AddPair('top', TJSONNumber.Create(Control.Top));
      Bounds.AddPair('width', TJSONNumber.Create(Control.Width));
      Bounds.AddPair('height', TJSONNumber.Create(Control.Height));
      result.AddPair('bounds', Bounds);
   end;

   if Component is TWinControl then begin
      WinControl := TWinControl(Component);
      result.AddPair('controlCount', TJSONNumber.Create(WinControl.ControlCount));
      if WinControl.HandleAllocated then begin
         result.AddPair('hwnd', IntToHex(NativeUInt(WinControl.Handle), SizeOf(HWND) * 2));
      end;
   end;

   if IncludeProperties then begin
      Props := TJSONObject.Create;
      for PropName in PropertyNames do begin
         PropInfo := GetPropInfo(Component.ClassInfo, PropName);
         if PropInfo <> nil then begin
            try
               case PropInfo.PropType^.Kind of
                  tkInteger, tkChar, tkWChar, tkEnumeration, tkSet:
                     Props.AddPair(PropName, VarToStr(GetPropValue(Component, PropName, true)));
                  tkString, tkLString, tkWString, tkUString:
                     Props.AddPair(PropName, GetStrProp(Component, PropInfo));
                  tkInt64:
                     Props.AddPair(PropName, TJSONNumber.Create(GetInt64Prop(Component, PropInfo)));
               else
                  Props.AddPair(PropName, '<unsupported ' + GetEnumName(TypeInfo(TTypeKind), Ord(PropInfo.PropType^.Kind)) + '>');
               end;
            except
               on E: Exception do begin
                  Props.AddPair(PropName, '<error: ' + E.Message + '>');
               end;
            end;
         end;
      end;
      result.AddPair('publishedProperties', Props);
   end;

   if Depth < MaxDepth then begin
      Children := TJSONArray.Create;
      for i := 0 to Component.ComponentCount - 1 do begin
         Children.AddElement(JsonVclComponent(Component.Components[i], Depth + 1, MaxDepth, IncludeProperties));
      end;
      result.AddPair('components', Children);

      if Component is TWinControl then begin
         Controls := TJSONArray.Create;
         WinControl := TWinControl(Component);
         for i := 0 to WinControl.ControlCount - 1 do begin
            Controls.AddElement(JsonVclComponent(WinControl.Controls[i], Depth + 1, MaxDepth, IncludeProperties));
         end;
         result.AddPair('controls', Controls);
      end;
   end;
end;

procedure TMcpIdeBridge.CollectVclDiagnosticTexts(const Component: TComponent; Depth, MaxDepth, MaxItems: integer;
   Texts: TJSONArray; var Total: integer);
const
   TextPropertyNames: array[0..3] of string = ('Caption', 'Text', 'SimpleText', 'Hint');
var
   PropInfo: PPropInfo;
   PropName, Value: string;
   Obj: TJSONObject;
   WinControl: TWinControl;
   i: integer;
begin
   if (Component = nil) or (Depth > MaxDepth) then begin
      exit;
   end;

   for PropName in TextPropertyNames do begin
      PropInfo := GetPropInfo(Component.ClassInfo, PropName);
      if PropInfo = nil then begin
         continue;
      end;
      try
         Value := Trim(VarToStr(GetPropValue(Component, PropName, true)));
      except
         Value := '';
      end;
      if Value = '' then begin
         continue;
      end;

      Inc(Total);
      if Texts.Count < MaxItems then begin
         Obj := TJSONObject.Create;
         Obj.AddPair('className', Component.ClassName);
         Obj.AddPair('name', Component.Name);
         Obj.AddPair('property', PropName);
         Obj.AddPair('text', Value);
         Texts.AddElement(Obj);
      end;
   end;

   if Depth >= MaxDepth then begin
      exit;
   end;

   for i := 0 to Component.ComponentCount - 1 do begin
      CollectVclDiagnosticTexts(Component.Components[i], Depth + 1, MaxDepth, MaxItems, Texts, Total);
   end;

   if Component is TWinControl then begin
      WinControl := TWinControl(Component);
      for i := 0 to WinControl.ControlCount - 1 do begin
         CollectVclDiagnosticTexts(WinControl.Controls[i], Depth + 1, MaxDepth, MaxItems, Texts, Total);
      end;
   end;
end;

function TMcpIdeBridge.JsonVclDiagnosticForm(const Form: TCustomForm; MaxDepth, MaxTextItems: integer): TJSONObject;
var
   Texts: TJSONArray;
   Total: integer;
begin
   result := JsonVclComponent(Form, 0, 1, true);
   Texts := TJSONArray.Create;
   Total := 0;
   CollectVclDiagnosticTexts(Form, 0, MaxDepth, MaxTextItems, Texts, Total);
   result.AddPair('diagnosticTextCount', TJSONNumber.Create(Total));
   result.AddPair('diagnosticTextsTruncated', McpBoolValue(Total > Texts.Count));
   result.AddPair('diagnosticTexts', Texts);
end;

function TMcpIdeBridge.JsonRttiSummary(const Instance: TObject; const NameContains: string; MaxItems: integer): TJSONObject;
var
   RttiContext: TRttiContext;
   RttiType: TRttiType;
   RttiProp: TRttiProperty;
   RttiMethod: TRttiMethod;
   RttiParam: TRttiParameter;
   Props, Methods, Params: TJSONArray;
   Obj, ParamObj: TJSONObject;
   Filter: string;
   PropCount, MethodCount: integer;
begin
   result := TJSONObject.Create;
   result.AddPair('available', McpBoolValue(Instance <> nil));
   if Instance = nil then begin
      exit;
   end;

   if MaxItems < 1 then begin
      MaxItems := 1;
   end;
   Filter := LowerCase(NameContains);
   result.AddPair('className', Instance.ClassName);
   result.AddPair('filter', Filter);

   Props := TJSONArray.Create;
   Methods := TJSONArray.Create;
   RttiContext := TRttiContext.Create;
   RttiType := RttiContext.GetType(Instance.ClassType);
   if RttiType <> nil then begin
      PropCount := 0;
      for RttiProp in RttiType.GetProperties do begin
         if (Filter <> '') and (Pos(Filter, LowerCase(RttiProp.Name)) <= 0) then begin
            continue;
         end;
         if PropCount >= MaxItems then begin
            break;
         end;
         Obj := TJSONObject.Create;
         Obj.AddPair('name', RttiProp.Name);
         if RttiProp.PropertyType <> nil then begin
            Obj.AddPair('typeName', RttiProp.PropertyType.ToString);
         end;
         Obj.AddPair('visibility', GetEnumName(TypeInfo(TMemberVisibility), Ord(RttiProp.Visibility)));
         Obj.AddPair('readable', McpBoolValue(RttiProp.IsReadable));
         Obj.AddPair('writable', McpBoolValue(RttiProp.IsWritable));
         Props.AddElement(Obj);
         Inc(PropCount);
      end;

      MethodCount := 0;
      for RttiMethod in RttiType.GetMethods do begin
         if (Filter <> '') and (Pos(Filter, LowerCase(RttiMethod.Name)) <= 0) then begin
            continue;
         end;
         if MethodCount >= MaxItems then begin
            break;
         end;
         Obj := TJSONObject.Create;
         Obj.AddPair('name', RttiMethod.Name);
         Obj.AddPair('visibility', GetEnumName(TypeInfo(TMemberVisibility), Ord(RttiMethod.Visibility)));
         if RttiMethod.ReturnType <> nil then begin
            Obj.AddPair('returnType', RttiMethod.ReturnType.ToString);
         end;
         Params := TJSONArray.Create;
         for RttiParam in RttiMethod.GetParameters do begin
            ParamObj := TJSONObject.Create;
            ParamObj.AddPair('name', RttiParam.Name);
            if RttiParam.ParamType <> nil then begin
               ParamObj.AddPair('typeName', RttiParam.ParamType.ToString);
            end;
            ParamObj.AddPair('flags', McpParamFlagsText(RttiParam.Flags));
            Params.AddElement(ParamObj);
         end;
         Obj.AddPair('parameters', Params);
         Methods.AddElement(Obj);
         Inc(MethodCount);
      end;
   end;

   result.AddPair('properties', Props);
   result.AddPair('methods', Methods);
end;

function TMcpIdeBridge.FindVclWinControl(const Root: TWinControl; const NameContains, ClassContains: string): TWinControl;
var
   i: integer;
   ChildControl: TControl;
   WinChild: TWinControl;
begin
   result := nil;
   if Root = nil then begin
      exit;
   end;

   if ((NameContains = '') or (Pos(NameContains, LowerCase(Root.Name)) > 0)) and
      ((ClassContains = '') or (Pos(ClassContains, LowerCase(Root.ClassName)) > 0)) then begin
      result := Root;
      exit;
   end;

   for i := 0 to Root.ControlCount - 1 do begin
      ChildControl := Root.Controls[i];
      if ChildControl is TWinControl then begin
         WinChild := FindVclWinControl(TWinControl(ChildControl), NameContains, ClassContains);
         if WinChild <> nil then begin
            result := WinChild;
            exit;
         end;
      end;
   end;

   for i := 0 to Root.ComponentCount - 1 do begin
      if Root.Components[i] is TWinControl then begin
         WinChild := FindVclWinControl(TWinControl(Root.Components[i]), NameContains, ClassContains);
         if WinChild <> nil then begin
            result := WinChild;
            exit;
         end;
      end;
   end;
end;

function TMcpIdeBridge.VclTreeTextByForm(const FormClassContains, FormNameContains, FormCaptionContains,
   ControlNameContains, ControlClassContains: string; VisibleOnly: boolean; MaxRows, MaxColumns: integer): TJSONValue;
var
   Form: TCustomForm;
   Control: TWinControl;
   Component: TComponent;
   Rows: TJSONArray;
   i, j, RowCount: integer;
   Truncated: boolean;
   ControlClassName, ControlName: string;
begin
   if MaxRows < 1 then begin
      MaxRows := 1;
   end;
   if MaxColumns < 1 then begin
      MaxColumns := 1;
   end;

   for i := 0 to Screen.FormCount - 1 do begin
      Form := Screen.Forms[i];
      if VisibleOnly and not Form.Visible then begin
         continue;
      end;
      if (FormClassContains <> '') and (Pos(FormClassContains, LowerCase(Form.ClassName)) <= 0) then begin
         continue;
      end;
      if (FormNameContains <> '') and (Pos(FormNameContains, LowerCase(Form.Name)) <= 0) then begin
         continue;
      end;
      if (FormCaptionContains <> '') and (Pos(FormCaptionContains, LowerCase(Form.Caption)) <= 0) then begin
         continue;
      end;

      Control := nil;
      for j := 0 to Form.ComponentCount - 1 do begin
         Component := Form.Components[j];
         if not (Component is TWinControl) then begin
            continue;
         end;
         if ((ControlNameContains = '') or (Pos(ControlNameContains, LowerCase(Component.Name)) > 0)) and
            ((ControlClassContains = '') or (Pos(ControlClassContains, LowerCase(Component.ClassName)) > 0)) then begin
            Control := TWinControl(Component);
            break;
         end;
      end;
      if Control = nil then begin
         Control := FindVclWinControl(Form, ControlNameContains, ControlClassContains);
      end;
      if Control = nil then begin
         continue;
      end;

      result := TJSONObject.Create;
      TJSONObject(result).AddPair('found', McpBoolValue(true));
      TJSONObject(result).AddPair('formClassName', Form.ClassName);
      TJSONObject(result).AddPair('formName', Form.Name);
      TJSONObject(result).AddPair('formCaption', Form.Caption);
      if Control.HandleAllocated then begin
         TJSONObject(result).AddPair('treeWindow', JsonWindow(Control.Handle, true));
      end;
      TJSONObject(result).AddPair('controlClassName', Control.ClassName);
      TJSONObject(result).AddPair('controlName', Control.Name);
      try
         Rows := ExtractVirtualTreeRowsFromControl(Control, MaxRows, MaxColumns, RowCount, Truncated, ControlClassName, ControlName);
         TJSONObject(result).AddPair('textSupported', McpBoolValue(true));
         TJSONObject(result).AddPair('rowCount', TJSONNumber.Create(RowCount));
         TJSONObject(result).AddPair('truncated', McpBoolValue(Truncated));
         TJSONObject(result).AddPair('rows', Rows);
      except
         on E: Exception do begin
            TJSONObject(result).AddPair('textSupported', McpBoolValue(false));
            TJSONObject(result).AddPair('error', E.Message);
            TJSONObject(result).AddPair('rowCount', TJSONNumber.Create(0));
            TJSONObject(result).AddPair('truncated', McpBoolValue(false));
            TJSONObject(result).AddPair('rows', TJSONArray.Create);
            TJSONObject(result).AddPair('rttiTextSummary', JsonRttiSummary(Control, 'text', 80));
            TJSONObject(result).AddPair('rttiNodeSummary', JsonRttiSummary(Control, 'node', 80));
            TJSONObject(result).AddPair('rttiFirstSummary', JsonRttiSummary(Control, 'first', 80));
            TJSONObject(result).AddPair('rttiNextSummary', JsonRttiSummary(Control, 'next', 80));
            TJSONObject(result).AddPair('rttiClipboardSummary', JsonRttiSummary(Control, 'clip', 80));
         end;
      end;
      exit;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('found', McpBoolValue(false));
   TJSONObject(result).AddPair('formCount', TJSONNumber.Create(Screen.FormCount));
end;

function TMcpIdeBridge.ExtractVirtualTreeRowsFromControl(const Control: TWinControl; MaxRows, MaxColumns: integer;
   out RowCount: integer; out Truncated: boolean; out ControlClassName, ControlName: string): TJSONArray;
var
   RttiContext: TRttiContext;
   RttiType: TRttiType;
   RttiMethod, GetFirstMethod, GetNextMethod, GetTextMethod, GetTextInfoMethod: TRttiMethod;
   Node: Pointer;
   Cells: TJSONArray;
   Row: TJSONObject;
   CellText: string;
   RowIndex, ColumnIndex: integer;
   TextInfoArgs: TArray<TValue>;
   TextInfoFont: TFont;
   TextInfoRect: TRect;
   TextInfoText: WideString;
   HasAnyCellText: boolean;
   ClipboardRows: TJSONArray;
   OriginalRowCount: integer;
   OriginalTruncated: boolean;
begin
   if Control = nil then begin
      raise Exception.Create('Kein VCL-Control angegeben.');
   end;

   if MaxRows < 1 then begin
      MaxRows := 1;
   end;
   if MaxColumns < 1 then begin
      MaxColumns := 1;
   end;

   ControlClassName := Control.ClassName;
   ControlName := Control.Name;
   GetFirstMethod := nil;
   GetNextMethod := nil;
   GetTextMethod := nil;
   GetTextInfoMethod := nil;
   RttiContext := TRttiContext.Create;
   RttiType := RttiContext.GetType(Control.ClassType);
   if RttiType <> nil then begin
      for RttiMethod in RttiType.GetMethods do begin
         if SameText(RttiMethod.Name, 'GetFirst') and (Length(RttiMethod.GetParameters) = 0) then begin
            GetFirstMethod := RttiMethod;
         end
         else if SameText(RttiMethod.Name, 'GetNext') and (Length(RttiMethod.GetParameters) = 1) then begin
            GetNextMethod := RttiMethod;
         end
         else if SameText(RttiMethod.Name, 'ZombieGetText') and (Length(RttiMethod.GetParameters) = 2) then begin
            GetTextMethod := RttiMethod;
         end
         else if (GetTextMethod = nil) and SameText(RttiMethod.Name, 'GetText') and
            (Length(RttiMethod.GetParameters) = 2) then begin
            GetTextMethod := RttiMethod;
         end
         else if SameText(RttiMethod.Name, 'GetTextInfo') and (Length(RttiMethod.GetParameters) = 5) then begin
            GetTextInfoMethod := RttiMethod;
         end;
      end;
   end;

   if (GetFirstMethod = nil) or (GetNextMethod = nil) or (GetTextMethod = nil) then begin
      raise Exception.Create('VirtualTree-Methoden GetFirst/GetNext und ZombieGetText/GetText wurden per RTTI nicht gefunden.');
   end;

   result := TJSONArray.Create;
   Node := GetFirstMethod.Invoke(Control, []).AsType<Pointer>;
   RowIndex := 0;
   HasAnyCellText := false;
   TextInfoFont := TFont.Create;
   try
   while (Node <> nil) and (RowIndex < MaxRows) do begin
      Row := TJSONObject.Create;
      Row.AddPair('node', IntToHex(NativeUInt(Node), SizeOf(Pointer) * 2));
      Cells := TJSONArray.Create;
      for ColumnIndex := 0 to MaxColumns - 1 do begin
         try
            CellText := GetTextMethod.Invoke(Control, [TValue.From<Pointer>(Node), TValue.From<integer>(ColumnIndex)]).AsType<string>;
         except
            on E: Exception do begin
               CellText := '<error: ' + E.Message + '>';
            end;
         end;
         if (CellText = '') and (GetTextInfoMethod <> nil) then begin
            try
               TextInfoRect.Left := 0;
               TextInfoRect.Top := 0;
               TextInfoRect.Right := Control.Width;
               TextInfoRect.Bottom := Control.Height;
               TextInfoText := '';
               SetLength(TextInfoArgs, 5);
               TextInfoArgs[0] := TValue.From<Pointer>(Node);
               TextInfoArgs[1] := TValue.From<integer>(ColumnIndex);
               TextInfoArgs[2] := TValue.From<TFont>(TextInfoFont);
               TValue.Make(@TextInfoRect, TypeInfo(TRect), TextInfoArgs[3]);
               TValue.Make(@TextInfoText, TypeInfo(WideString), TextInfoArgs[4]);
               GetTextInfoMethod.Invoke(Control, TextInfoArgs);
               CellText := TextInfoText;
            except
               on E: Exception do begin
                  CellText := '<gettextinfo error: ' + E.Message + '>';
               end;
            end;
         end;
         if CellText <> '' then begin
            HasAnyCellText := true;
         end;
         Cells.AddElement(TJSONString.Create(CellText));
      end;
      Row.AddPair('cells', Cells);
      result.AddElement(Row);
      Inc(RowIndex);
      Node := GetNextMethod.Invoke(Control, [TValue.From<Pointer>(Node)]).AsType<Pointer>;
   end;
   finally
      TextInfoFont.Free;
   end;

   RowCount := RowIndex;
   Truncated := Node <> nil;

   if (not HasAnyCellText) and SameText(Control.ClassName, 'TVirtualDrawTree') then begin
      OriginalRowCount := RowCount;
      OriginalTruncated := Truncated;
      ClipboardRows := ExtractVirtualTreeRowsViaClipboard(Control, MaxRows, MaxColumns, RowCount, Truncated);
      if (ClipboardRows <> nil) and (RowCount > 0) then begin
         result.Free;
         result := ClipboardRows;
      end
      else begin
         ClipboardRows.Free;
         RowCount := OriginalRowCount;
         Truncated := OriginalTruncated;
      end;
   end;
end;

function TMcpIdeBridge.ExtractVirtualTreeRowsViaClipboard(const Control: TWinControl; MaxRows, MaxColumns: integer;
   out RowCount: integer; out Truncated: boolean): TJSONArray;
var
   RttiContext: TRttiContext;
   RttiType: TRttiType;
   RttiMethod, SelectAllMethod, CopyMethod, ClearSelectionMethod: TRttiMethod;
   HadClipboardText: boolean;
   OldClipboardText, ClipboardText, Line: string;
   Lines: TStringList;
   Parts: TArray<string>;
   Row: TJSONObject;
   Cells: TJSONArray;
   LineIndex, ColumnIndex: integer;
begin
   result := nil;
   RowCount := 0;
   Truncated := false;
   if Control = nil then begin
      exit;
   end;

   SelectAllMethod := nil;
   CopyMethod := nil;
   ClearSelectionMethod := nil;
   RttiContext := TRttiContext.Create;
   RttiType := RttiContext.GetType(Control.ClassType);
   if RttiType <> nil then begin
      for RttiMethod in RttiType.GetMethods do begin
         if SameText(RttiMethod.Name, 'SelectAll') and (Length(RttiMethod.GetParameters) = 1) then begin
            SelectAllMethod := RttiMethod;
         end
         else if SameText(RttiMethod.Name, 'CopyToClipBoard') and (Length(RttiMethod.GetParameters) = 0) then begin
            CopyMethod := RttiMethod;
         end
         else if SameText(RttiMethod.Name, 'ClearSelection') and (Length(RttiMethod.GetParameters) = 0) then begin
            ClearSelectionMethod := RttiMethod;
         end;
      end;
   end;

   if (SelectAllMethod = nil) or (CopyMethod = nil) then begin
      exit;
   end;

   HadClipboardText := Clipboard.HasFormat(CF_UNICODETEXT) or Clipboard.HasFormat(CF_TEXT);
   OldClipboardText := '';
   if HadClipboardText then begin
      OldClipboardText := Clipboard.AsText;
   end;

   try
      Clipboard.Clear;
      SelectAllMethod.Invoke(Control, [TValue.From<boolean>(false)]);
      CopyMethod.Invoke(Control, []);
      ClipboardText := Clipboard.AsText;
      if ClearSelectionMethod <> nil then begin
         ClearSelectionMethod.Invoke(Control, []);
      end;
   finally
      if HadClipboardText then begin
         Clipboard.AsText := OldClipboardText;
      end
      else begin
         Clipboard.Clear;
      end;
   end;

   if ClipboardText = '' then begin
      exit;
   end;

   Lines := TStringList.Create;
   try
      Lines.Text := ClipboardText;
      result := TJSONArray.Create;
      for LineIndex := 0 to Lines.Count - 1 do begin
         if RowCount >= MaxRows then begin
            Truncated := true;
            break;
         end;
         Line := Lines[LineIndex];
         if Line = '' then begin
            continue;
         end;
         Parts := Line.Split([#9]);
         Row := TJSONObject.Create;
         Row.AddPair('source', 'clipboard');
         Cells := TJSONArray.Create;
         for ColumnIndex := 0 to MaxColumns - 1 do begin
            if ColumnIndex < Length(Parts) then begin
               Cells.AddElement(TJSONString.Create(Parts[ColumnIndex]));
            end
            else begin
               Cells.AddElement(TJSONString.Create(''));
            end;
         end;
         Row.AddPair('cells', Cells);
         result.AddElement(Row);
         Inc(RowCount);
      end;
   finally
      Lines.Free;
   end;
end;

function TMcpIdeBridge.ExtractVirtualTreeRows(const Wnd: HWND; MaxRows, MaxColumns: integer; out RowCount: integer;
   out Truncated: boolean; out ControlClassName, ControlName: string): TJSONArray;
var
   Control: TWinControl;
begin
   if not IsWindow(Wnd) then begin
      raise Exception.Create('hwnd ist kein gueltiges Fenster-Handle.');
   end;

   Control := FindControl(Wnd);
   if Control = nil then begin
      raise Exception.Create('Zu diesem HWND wurde kein VCL-Control gefunden.');
   end;

   result := ExtractVirtualTreeRowsFromControl(Control, MaxRows, MaxColumns, RowCount, Truncated,
      ControlClassName, ControlName);
end;

function TMcpIdeBridge.JsonSourceLineInfo(const FileName: string; Line: integer): TJSONObject;
var
   Bytes: TBytes;
   Encoding: TEncoding;
   BomLength: integer;
   Text, LineText, Trimmed, Mode: string;
   i, CurrentLine, LineStart, CrlfCount, LfCount, CrCount, TotalLines: integer;
   HasCrlf, HasLf, HasCr, FoundLine, LooksExecutable, LooksStatement: boolean;
begin
   result := TJSONObject.Create;
   result.AddPair('fileName', FileName);
   result.AddPair('requestedLine', TJSONNumber.Create(Line));
   result.AddPair('exists', McpBoolValue(TFile.Exists(FileName)));
   if not TFile.Exists(FileName) then begin
      result.AddPair('available', McpBoolValue(false));
      result.AddPair('warning', 'Datei wurde nicht gefunden.');
      exit;
   end;
   if Line <= 0 then begin
      result.AddPair('available', McpBoolValue(false));
      result.AddPair('warning', 'Zeilennummer muss groesser als 0 sein.');
      exit;
   end;

   Bytes := TFile.ReadAllBytes(FileName);
   Encoding := TEncoding.Default;
   BomLength := TEncoding.GetBufferEncoding(Bytes, Encoding, TEncoding.Default);
   Text := Encoding.GetString(Bytes, BomLength, Length(Bytes) - BomLength);

   CrlfCount := 0;
   LfCount := 0;
   CrCount := 0;
   i := 1;
   while i <= Length(Text) do begin
      if Text[i] = #13 then begin
         if (i < Length(Text)) and (Text[i + 1] = #10) then begin
            Inc(CrlfCount);
            Inc(i);
         end
         else begin
            Inc(CrCount);
         end;
      end
      else if Text[i] = #10 then begin
         Inc(LfCount);
      end;
      Inc(i);
   end;

   HasCrlf := CrlfCount > 0;
   HasLf := LfCount > 0;
   HasCr := CrCount > 0;
   if (not HasCrlf) and (not HasLf) and (not HasCr) then begin
      Mode := 'none';
   end
   else if HasCrlf and (not HasLf) and (not HasCr) then begin
      Mode := 'CRLF';
   end
   else if HasLf and (not HasCrlf) and (not HasCr) then begin
      Mode := 'LF';
   end
   else if HasCr and (not HasCrlf) and (not HasLf) then begin
      Mode := 'CR';
   end
   else begin
      Mode := 'mixed';
   end;

   CurrentLine := 1;
   LineStart := 1;
   TotalLines := 1;
   FoundLine := false;
   LineText := '';
   i := 1;
   while i <= Length(Text) + 1 do begin
      if (i > Length(Text)) or (Text[i] = #13) or (Text[i] = #10) then begin
         if CurrentLine = Line then begin
            LineText := Copy(Text, LineStart, i - LineStart);
            FoundLine := true;
         end;
         if i <= Length(Text) then begin
            Inc(TotalLines);
            if (Text[i] = #13) and (i < Length(Text)) and (Text[i + 1] = #10) then begin
               Inc(i);
            end;
         end;
         Inc(CurrentLine);
         LineStart := i + 1;
      end;
      Inc(i);
   end;

   Trimmed := Trim(LineText);
   LooksExecutable := (Trimmed <> '') and (Trimmed[1] <> '{') and (Copy(Trimmed, 1, 2) <> '//') and
      (Copy(Trimmed, 1, 2) <> '(*');
   LooksStatement := LooksExecutable and (not SameText(Trimmed, 'begin')) and (not SameText(Trimmed, 'try')) and
      (not SameText(Trimmed, 'finally')) and (not SameText(Trimmed, 'except')) and
      (not SameText(Trimmed, 'end')) and (not SameText(Trimmed, 'end;')) and
      (not SameText(Trimmed, 'end.'));

   result.AddPair('available', McpBoolValue(FoundLine));
   result.AddPair('encoding', Encoding.EncodingName);
   result.AddPair('bomLength', TJSONNumber.Create(BomLength));
   result.AddPair('lineEndingMode', Mode);
   result.AddPair('crlfCount', TJSONNumber.Create(CrlfCount));
   result.AddPair('lfCount', TJSONNumber.Create(LfCount));
   result.AddPair('crCount', TJSONNumber.Create(CrCount));
   result.AddPair('mixedLineEndings', McpBoolValue(Mode = 'mixed'));
   result.AddPair('delphiPreferredLineEndings', McpBoolValue(Mode = 'CRLF'));
   result.AddPair('totalLines', TJSONNumber.Create(TotalLines));
   result.AddPair('lineText', LineText);
   result.AddPair('trimmedLineText', Trimmed);
   result.AddPair('looksBreakpointCandidate', McpBoolValue(LooksExecutable));
   result.AddPair('looksExecutableStatement', McpBoolValue(LooksStatement));
   if Mode <> 'CRLF' then begin
      result.AddPair('lineEndingWarning', 'Delphi-Breakpoints sind mit CRLF-Zeilenenden am zuverlaessigsten.');
   end;
   if FoundLine and (not LooksStatement) then begin
      result.AddPair('lineWarning', 'Die Zielzeile wirkt nicht wie eine ausfuehrbare Delphi-Anweisung.');
   end;
end;

function TMcpIdeBridge.CompileModeFromText(const Value: string): TOTACompileMode;
begin
   if SameText(Value, 'build') then begin
      result := cmOTABuild;
   end
   else if SameText(Value, 'check') then begin
      result := cmOTACheck;
   end
   else if SameText(Value, 'clean') then begin
      result := cmOTAClean;
   end
   else if SameText(Value, 'link') then begin
      result := cmOTALink;
   end
   else begin
      result := cmOTAMake;
   end;
end;

function TMcpIdeBridge.CompileModeText(Mode: TOTACompileMode): string;
begin
   case Mode of
      cmOTAMake: result := 'make';
      cmOTABuild: result := 'build';
      cmOTACheck: result := 'check';
      cmOTAClean: result := 'clean';
      cmOTALink: result := 'link';
   else result := IntToStr(Ord(Mode));
   end;
end;

function TMcpIdeBridge.CompileResultText(Value: TOTACompileResult): string;
begin
   case Value of
      crOTAFailed: result := 'failed';
      crOTASucceeded: result := 'succeeded';
      crOTABackground: result := 'background';
   else result := IntToStr(Ord(Value));
   end;
end;

procedure TMcpIdeBridge.AddCompileEvent(const EventName: string; const Project: IOTAProject; Mode: TOTACompileMode);
var
   Event: TMcpCompileEvent;
begin
   Event := TMcpCompileEvent.Create;
   Event.EventName := EventName;
   if Project <> nil then begin
      Event.ProjectFileName := Project.FileName;
   end;
   Event.ModeText := CompileModeText(Mode);
   FCompileEvents.Add(Event);
end;

procedure TMcpIdeBridge.AddCompileEvent(const EventName: string; const Project: IOTAProject; Value: TOTACompileResult);
var
   Event: TMcpCompileEvent;
begin
   Event := TMcpCompileEvent.Create;
   Event.EventName := EventName;
   if Project <> nil then begin
      Event.ProjectFileName := Project.FileName;
   end;
   Event.ResultText := CompileResultText(Value);
   FCompileEvents.Add(Event);
end;

procedure TMcpIdeBridge.AddProjectCompileInfoEvent(const EventName, ProjectFileName: string; const CompileInfo: TOTAProjectCompileInfo;
   IncludeResult: boolean);
var
   Event: TMcpCompileEvent;
begin
   Event := TMcpCompileEvent.Create;
   Event.EventName := EventName;
   Event.ProjectFileName := ProjectFileName;
   Event.ModeText := CompileModeText(CompileInfo.Mode);
   Event.Configuration := CompileInfo.Configuration;
   Event.Platform := CompileInfo.Platform;
   Event.SuccessKnown := IncludeResult;
   Event.Success := CompileInfo.Result;
   FCompileEvents.Add(Event);
end;

procedure TMcpIdeBridge.AddProjectGroupCompileEvent(const EventName: string; Mode: TOTACompileMode);
var
   Event: TMcpCompileEvent;
begin
   Event := TMcpCompileEvent.Create;
   Event.EventName := EventName;
   Event.ModeText := CompileModeText(Mode);
   FCompileEvents.Add(Event);
end;

procedure TMcpIdeBridge.AddProjectGroupCompileEvent(const EventName: string; Value: TOTACompileResult);
var
   Event: TMcpCompileEvent;
begin
   Event := TMcpCompileEvent.Create;
   Event.EventName := EventName;
   Event.ResultText := CompileResultText(Value);
   FCompileEvents.Add(Event);
end;

procedure TMcpIdeBridge.ClearCompileEvents;
begin
   FCompileEvents.Clear;
end;

function TMcpIdeBridge.JsonCompileEvents: TJSONArray;
var
   Event: TMcpCompileEvent;
begin
   result := TJSONArray.Create;
   for Event in FCompileEvents do begin
      result.AddElement(Event.ToJson);
   end;
end;

procedure TMcpIdeBridge.RegisterCompileNotifier;
begin
   if FCompileNotifierIndex >= 0 then begin
      exit;
   end;
   FCompileNotifier := TMcpIdeCompileNotifier.Create(Self);
   FCompileNotifierIndex := CompileServices.AddNotifier(FCompileNotifier);
   if FCompileNotifierIndex < 0 then begin
      FCompileNotifier := nil;
      raise Exception.Create('IOTACompileNotifier konnte nicht registriert werden.');
   end;
end;

procedure TMcpIdeBridge.UnregisterCompileNotifier;
begin
   if FCompileNotifierIndex >= 0 then begin
      try
         CompileServices.RemoveNotifier(FCompileNotifierIndex);
      except
         // IDE shutdown may already have torn down compile services.
      end;
      FCompileNotifierIndex := -1;
   end;
   FCompileNotifier := nil;
end;

function TMcpIdeBridge.IsSelfPackageProject(const ProjectFileName: string): boolean;
var
   BaseName: string;
begin
   BaseName := ExtractFileName(ProjectFileName);
   result := SameText(BaseName, 'MCP2Delphi.dproj') or SameText(BaseName, 'MCP2DelphiDesign.dproj');
end;

function TMcpIdeBridge.DebugCommandResult(const Command: string): TJSONValue;
begin
   result := ToolDebugStatus(nil);
   TJSONObject(result).AddPair('command', Command);
   TJSONObject(result).AddPair('supported', McpBoolValue(true));
end;

function TMcpIdeBridge.UnsupportedDebugCommandResult(const Command, Reason: string): TJSONValue;
begin
   result := ToolDebugStatus(nil);
   TJSONObject(result).AddPair('command', Command);
   TJSONObject(result).AddPair('supported', McpBoolValue(false));
   TJSONObject(result).AddPair('executed', McpBoolValue(false));
   TJSONObject(result).AddPair('reason', Reason);
end;

function TMcpIdeBridge.IdeControlGuideText: string;
begin
   result :=
      '# Delphi IDE ueber MCP steuern' + sLineBreak +
      sLineBreak +
      'Nutze zuerst den aktiven Endpoint aus HKCU\Software\MCP2Delphi\IDE, Wert Url. ' +
      'Der Standard-Port ist 8776, die IDE kann aber auf den naechsten freien Port ausweichen.' + sLineBreak +
      sLineBreak +
      'Grundregeln:' + sLineBreak +
      '- Vor externen Datei-Aenderungen `ide_close_file` fuer die betroffene Datei verwenden.' + sLineBreak +
      '- Danach Datei extern aendern und mit CRLF/UTF-8 speichern.' + sLineBreak +
      '- Fuer IDE-Builds `ide_build_project` mit `method=action` verwenden; fuer Define-/Include-Tests `mode=build` statt `mode=make`.' + sLineBreak +
      '- Nach fehlgeschlagenen Builds `ide_close_build_dialogs` ausfuehren und Diagnosen aus `buildMessages` oder `ide_get_diagnostics` lesen.' + sLineBreak +
      '- Den direkten `method=toolsapi`-Build nur als Diagnosepfad verwenden, weil er in RAD Studio beim Dependency-Check instabil sein kann.' + sLineBreak +
      '- Keine IDE hart beenden, solange ein Debugprozess laeuft. Zuerst `debug_stop`, danach `ide_exit`.' + sLineBreak +
      '- Wenn `ide_exit saveAll=false` wegen eines Speichern-Dialogs haengen bleibt, `ide_close_save_dialogs` mit `action=discard` ausfuehren.' + sLineBreak +
      sLineBreak +
      'Empfohlener Build-/Diagnoseablauf:' + sLineBreak +
      '1. `ide_ping` und `ide_status` pruefen.' + sLineBreak +
      '2. Projekt per `ide_open_file` laden und mit `ide_set_active_project` aktivieren.' + sLineBreak +
      '3. Offene Testdateien mit `ide_close_file` schliessen.' + sLineBreak +
      '4. `ide_build_project` mit `method=action`, `mode=build`, `wait=true` ausfuehren.' + sLineBreak +
      '5. `ide_close_build_dialogs` ausfuehren.' + sLineBreak +
      '6. `buildMessages.diagnostics` oder `ide_get_diagnostics` auswerten.' + sLineBreak +
      sLineBreak +
      'Wiederholbare Tests liegen unter `Source\TestProjects\IdeMcpDiagnostics`:' + sLineBreak +
      '- `Run-IdeMcpDiagnosticsViaIde.ps1` fuer die Build-/Compilerdiagnose-Matrix.' + sLineBreak +
      '- `Run-IdeMcpDebugWorkflow.ps1` fuer den Debugger-End-to-End-Pfad.';
end;

function TMcpIdeBridge.IdeDebugWorkflowGuideText: string;
begin
   result :=
      '# Delphi Debugger ueber MCP steuern' + sLineBreak +
      sLineBreak +
      'Der stabile Debug-Pfad ist ToolsAPI-basiert:' + sLineBreak +
      '- `debug_start` startet oder setzt fort.' + sLineBreak +
      '- `debug_stop` beendet den Debugprozess.' + sLineBreak +
      '- `debug_get_callstack` liest den Callstack aus dem IDE-Fenster.' + sLineBreak +
      '- `debug_get_threads` liest Threads direkt ueber `IOTAProcess.Threads`.' + sLineBreak +
      '- `debug_evaluate_expression` wertet Ausdruecke ueber `IOTAThread.Evaluate` aus.' + sLineBreak +
      '- `debug_get_current_source_location` liest Datei/Zeile aus dem aktuellen Thread.' + sLineBreak +
      sLineBreak +
      'Nach `debug_start`, `debug_step_over` oder `debug_step_into` kurz auf `debug_get_current_source_location.available=true` pollen. ' +
      'Direkt nach einem Kommando kann die IDE-Position einen UI-Takt nachlaufen.' + sLineBreak +
      sLineBreak +
      'Empfohlener Debug-Testablauf:' + sLineBreak +
      '1. Breakpoint mit `debug_add_breakpoint` setzen.' + sLineBreak +
      '2. `debug_start` ausfuehren.' + sLineBreak +
      '3. `debug_get_current_source_location` pollen, bis die erwartete Zeile erreicht ist.' + sLineBreak +
      '4. `debug_get_callstack`, `debug_get_threads` und `debug_evaluate_expression` pruefen.' + sLineBreak +
      '5. `debug_step_over` oder `debug_step_into` ausfuehren.' + sLineBreak +
      '6. Erneut Source-Location pollen.' + sLineBreak +
      '7. Cleanup: `debug_stop`, danach temporaere Breakpoints entfernen.';
end;

function TMcpIdeBridge.ListIdeResources: TJSONArray;
begin
   result := TJSONArray.Create;
   result.AddElement(TJSONObject.Create
      .AddPair('uri', 'mcp2delphi://ide/how-to-control-delphi')
      .AddPair('name', 'Delphi IDE ueber MCP steuern')
      .AddPair('description', 'Praxisregeln fuer Build, Diagnose, Dialoge und Datei-Aenderungen in RAD Studio.')
      .AddPair('mimeType', 'text/markdown'));
   result.AddElement(TJSONObject.Create
      .AddPair('uri', 'mcp2delphi://ide/debug-workflow')
      .AddPair('name', 'Delphi Debugger Workflow ueber MCP')
      .AddPair('description', 'Empfohlener Ablauf fuer Breakpoint, Step, Callstack, Threads und Expression Evaluation.')
      .AddPair('mimeType', 'text/markdown'));
end;

function TMcpIdeBridge.ReadIdeResource(const Uri: string): TJSONObject;
var
   Text: string;
begin
   if SameText(Uri, 'mcp2delphi://ide/how-to-control-delphi') then begin
      Text := IdeControlGuideText;
   end
   else if SameText(Uri, 'mcp2delphi://ide/debug-workflow') then begin
      Text := IdeDebugWorkflowGuideText;
   end
   else begin
      raise Exception.Create('Unbekannte IDE-MCP Resource: ' + Uri);
   end;

   result := TJSONObject.Create;
   result.AddPair('uri', Uri);
   result.AddPair('mimeType', 'text/markdown');
   result.AddPair('text', Text);
end;

function TMcpIdeBridge.ListIdePrompts: TJSONArray;
begin
   result := TJSONArray.Create;
   result.AddElement(TJSONObject.Create
      .AddPair('name', 'delphi-ide-control-guide')
      .AddPair('description', 'Kontext fuer Agenten, die Delphi ueber IDE-MCP steuern sollen.'));
end;

function TMcpIdeBridge.GetIdePrompt(const PromptName: string): TJSONObject;
begin
   if not SameText(PromptName, 'delphi-ide-control-guide') then begin
      raise Exception.Create('Unbekannter IDE-MCP Prompt: ' + PromptName);
   end;

   result := TJSONObject.Create;
   result.AddPair('text',
      'Arbeite mit der laufenden Delphi-IDE ueber IDE-MCP. ' +
      'Lies zuerst die Resources `mcp2delphi://ide/how-to-control-delphi` und `mcp2delphi://ide/debug-workflow`. ' +
      'Nutze den Registry-Endpoint, vermeide direkte ToolsAPI-Builds ausser zur Diagnose, schliesse Dateien vor externen Aenderungen, ' +
      'poll Debugger-Source-Locations nach Run/Step und stoppe Debugprozesse vor `ide_exit`.');
end;

procedure TMcpIdeBridge.RegisterTools;
begin
   FServer.UnregisterOwner(FOwnerId);
   FServer.RegisterTool('ide_ping', 'IDE MCP Server pruefen.', [], [], ToolIdePing, true, FOwnerId);
   FServer.RegisterTool('ide_status', 'Status des IDE MCP Servers lesen.', [], [], ToolIdeStatus, true, FOwnerId);
   FServer.RegisterTool('ide_list_actions', 'IDE-Actions nach Name, Caption und Hint auflisten.', [], ['textContains', 'max'], ToolListActions, true, FOwnerId);
   FServer.RegisterTool('ide_execute_action', 'IDE-Action anhand ihres Namens ausfuehren.', ['name'], ['name', 'waitMs'], ToolExecuteAction, false, FOwnerId);
   FServer.RegisterTool('ide_get_active_project', 'Aktives Delphi-Projekt lesen.', [], [], ToolGetActiveProject, true, FOwnerId);
   FServer.RegisterTool('ide_set_active_project', 'Projekt der aktuellen Projektgruppe aktivieren.', ['fileName'], ['fileName'], ToolSetActiveProject, true, FOwnerId);
   FServer.RegisterTool('ide_list_projects', 'Projekte der aktuellen Projektgruppe auflisten.', [], [], ToolListProjects, true, FOwnerId);
   FServer.RegisterTool('ide_list_project_modules', 'Units/Module des aktiven Projekts auflisten.', [], [], ToolListProjectModules, true, FOwnerId);
   FServer.RegisterTool('ide_get_current_module', 'Aktuell geoeffnetes IDE-Modul lesen.', [], [], ToolGetCurrentModule, true, FOwnerId);
   FServer.RegisterTool('ide_open_file', 'Datei in der Delphi-IDE oeffnen.', ['fileName'], ['fileName', 'show'], ToolOpenFile, true, FOwnerId);
   FServer.RegisterTool('ide_close_file', 'Datei/Modul in der Delphi-IDE schliessen, damit externe Aenderungen keine Reload-Dialoge erzeugen.', ['fileName'], ['fileName', 'force'], ToolCloseFile, true, FOwnerId);
   FServer.RegisterTool('ide_save_all', 'Alle geoeffneten IDE-Module speichern.', [], [], ToolSaveAll, true, FOwnerId);
   FServer.RegisterTool('ide_exit', 'Delphi-IDE nach optionalem Speichern geordnet schliessen.', [], ['saveAll'], ToolExitIde, true, FOwnerId);
   FServer.RegisterTool('ide_close_save_dialogs', 'Offene Speichern-/Bestaetigungsdialoge der IDE schliessen.', [], ['action'], ToolCloseSaveDialogs, true, FOwnerId);
   FServer.RegisterTool('ide_list_windows', 'IDE-Fenster und Child-Controls per Win32-Enumeration auflisten.', [], ['scope', 'rootHwnd', 'includeInvisible', 'includeText', 'textContains', 'classContains', 'max'], ToolListWindows, true, FOwnerId);
   FServer.RegisterTool('ide_inspect_window', 'Ein IDE-Fenster anhand seines HWND mit Win32-Standardmessages inspizieren.', ['hwnd'], ['hwnd'], ToolInspectWindow, true, FOwnerId);
   FServer.RegisterTool('ide_inspect_vcl_control', 'Ein IDE-Fenster per VCL FindControl, published Properties und RTTI inspizieren.', ['hwnd'], ['hwnd', 'includeRtti', 'maxRtti', 'rttiContains'], ToolInspectVclControl, true, FOwnerId);
   FServer.RegisterTool('ide_list_vcl_components', 'VCL-Komponenten und child Controls eines IDE-Fensters auslesen, auch ohne eigenes HWND.', ['hwnd'], ['hwnd', 'maxDepth', 'includeProperties'], ToolListVclComponents, true, FOwnerId);
   FServer.RegisterTool('ide_list_vcl_forms', 'Aktuelle VCL-Forms der IDE mit Komponentenbaum auflisten.', [], ['visibleOnly', 'classContains', 'nameContains', 'captionContains', 'maxDepth', 'includeProperties'], ToolListVclForms, true, FOwnerId);
   FServer.RegisterTool('ide_get_vcl_tree_text', 'Textzellen eines VirtualTree Controls in einer IDE-Form lesen.', [], ['formClassContains', 'formNameContains', 'formCaptionContains', 'controlNameContains', 'controlClassContains', 'visibleOnly', 'maxRows', 'maxColumns'], ToolGetVclTreeText, true, FOwnerId);
   FServer.RegisterTool('ide_get_virtual_tree_text', 'Textzellen eines VCL VirtualTree Controls per RTTI auslesen.', ['hwnd'], ['hwnd', 'maxRows', 'maxColumns'], ToolGetVirtualTreeText, true, FOwnerId);
   FServer.RegisterTool('ide_get_build_messages', 'Buildausgabe aus dem IDE-Meldungsfenster lesen.', [], ['maxRows'], ToolGetBuildMessages, true, FOwnerId);
   FServer.RegisterTool('ide_get_diagnostics', 'Build-Messages und sichtbare IDE-Fehler-/Diagnose-Forms zusammenfassen.', [], ['maxRows', 'includeForms', 'includeAllForms', 'maxForms', 'maxDepth', 'maxTextItems'], ToolGetDiagnostics, true, FOwnerId);
   FServer.RegisterTool('ide_close_build_dialogs', 'Fehlgeschlagene IDE-Build-Fortschrittsdialoge schliessen.', [], [], ToolCloseBuildDialogs, true, FOwnerId);
   FServer.RegisterTool('ide_build_project', 'Aktives Delphi-Projekt bauen.', [], ['method', 'mode', 'actionName', 'wait', 'clearMessages', 'allowSelfBuild', 'buildWaitMs'], ToolBuildProject, false, FOwnerId);
   FServer.RegisterTool('ide_get_build_events', 'Zuletzt erfasste IDE-Compile-Events lesen.', [], [], ToolGetBuildEvents, true, FOwnerId);
   FServer.RegisterTool('ide_debug_status', 'Debugger-Status und aktive Prozesse lesen.', [], [], ToolDebugStatus, true, FOwnerId);
   FServer.RegisterTool('ide_list_breakpoints', 'Source-Breakpoints der IDE auflisten.', [], [], ToolListBreakpoints, true, FOwnerId);
   FServer.RegisterTool('ide_inspect_source_line', 'Source-Zeile mit Encoding, Zeilenenden und Breakpoint-Hinweisen pruefen.', ['fileName', 'line'], ['fileName', 'line'], ToolInspectSourceLine, true, FOwnerId);
   FServer.RegisterTool('ide_add_source_breakpoint', 'Source-Breakpoint in der IDE setzen.', ['fileName', 'line'], ['fileName', 'line'], ToolAddSourceBreakpoint, true, FOwnerId);
   FServer.RegisterTool('ide_remove_source_breakpoint', 'Source-Breakpoint nach Datei und Zeile entfernen.', ['fileName', 'line'], ['fileName', 'line'], ToolRemoveSourceBreakpoint, true, FOwnerId);
   FServer.RegisterTool('ide_run_program', 'Aktives Projekt im Debugger starten oder fortsetzen.', [], [], ToolRunProgram, true, FOwnerId);
   FServer.RegisterTool('ide_stop', 'Laufendes Debug-Programm stoppen.', [], [], ToolProgramReset, true, FOwnerId);
   FServer.RegisterTool('ide_program_reset', 'Laufendes Debug-Programm zuruecksetzen.', [], [], ToolProgramReset, true, FOwnerId);
   FServer.RegisterTool('ide_step_over', 'Debugger Step Over ausfuehren.', [], [], ToolStepOver, true, FOwnerId);
   FServer.RegisterTool('ide_trace_into', 'Debugger Trace Into ausfuehren.', [], [], ToolTraceInto, true, FOwnerId);
   FServer.RegisterTool('ide_run_to_cursor', 'Debugger bis zur Cursor-Position laufen lassen.', [], [], ToolRunToCursor, true, FOwnerId);
   FServer.RegisterTool('debug_start', 'Debug-Programm starten oder fortsetzen.', [], [], ToolRunProgram, true, FOwnerId);
   FServer.RegisterTool('debug_stop', 'Debug-Programm stoppen.', [], [], ToolProgramReset, true, FOwnerId);
   FServer.RegisterTool('debug_pause', 'Debug-Programm pausieren.', [], [], ToolPauseProgram, true, FOwnerId);
   FServer.RegisterTool('debug_continue', 'Debug-Programm fortsetzen.', [], [], ToolRunProgram, true, FOwnerId);
   FServer.RegisterTool('debug_step_over', 'Debugger Step Over ausfuehren.', [], [], ToolStepOver, true, FOwnerId);
   FServer.RegisterTool('debug_step_into', 'Debugger Step Into ausfuehren.', [], [], ToolTraceInto, true, FOwnerId);
   FServer.RegisterTool('debug_step_out', 'Debugger Step Out ausfuehren.', [], [], ToolStepOut, true, FOwnerId);
   FServer.RegisterTool('debug_add_breakpoint', 'Source-Breakpoint in der IDE setzen.', ['fileName', 'line'], ['fileName', 'line'], ToolAddSourceBreakpoint, true, FOwnerId);
   FServer.RegisterTool('debug_remove_breakpoint', 'Source-Breakpoint nach Datei und Zeile entfernen.', ['fileName', 'line'], ['fileName', 'line'], ToolRemoveSourceBreakpoint, true, FOwnerId);
   FServer.RegisterTool('debug_list_breakpoints', 'Source-Breakpoints der IDE auflisten.', [], [], ToolListBreakpoints, true, FOwnerId);
   FServer.RegisterTool('debug_get_callstack', 'Callstack-Fenster der IDE auslesen.', [], ['maxRows', 'maxColumns'], ToolGetDebugCallstack, true, FOwnerId);
   FServer.RegisterTool('debug_get_threads', 'Thread-Fenster der IDE auslesen.', [], ['maxRows', 'maxColumns'], ToolGetDebugThreads, true, FOwnerId);
   FServer.RegisterTool('debug_evaluate_expression', 'Ausdruck im aktuellen Debug-Thread auswerten.', ['expression'], ['expression', 'allowSideEffects', 'formatSpecifiers', 'fileName', 'line'], ToolEvaluateExpression, true, FOwnerId);
   FServer.RegisterTool('debug_get_current_source_location', 'Aktuelle Source-Position des Debuggers lesen.', [], [], ToolGetCurrentSourceLocation, true, FOwnerId);
   FServer.RegisterResourceHandlers(ListIdeResources, ReadIdeResource, FOwnerId);
   FServer.RegisterPromptHandlers(ListIdePrompts, GetIdePrompt, FOwnerId);
end;

procedure TMcpIdeBridge.Start;
begin
   RegisterCompileNotifier;
   RegisterTools;
   FServer.Start;
   PublishServerDiscovery(true);
   AddSplashInfo;
   RegisterIdeMenu;
end;

procedure TMcpIdeBridge.Stop;
begin
   PublishServerDiscovery(false);
   if FServer <> nil then begin
      FServer.UnregisterOwner(FOwnerId);
      FServer.Stop;
   end;
end;

function TMcpIdeBridge.ToolIdePing(const Arguments: TJSONObject): TJSONValue;
begin
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('status', 'ok');
   TJSONObject(result).AddPair('serverName', FServer.ServerName);
   TJSONObject(result).AddPair('url', FServer.Url);
   TJSONObject(result).AddPair('configuredPort', TJSONNumber.Create(FServer.Port));
   TJSONObject(result).AddPair('activePort', TJSONNumber.Create(FServer.ActivePort));
   TJSONObject(result).AddPair('process', ExtractFileName(ParamStr(0)));
end;

function TMcpIdeBridge.ToolIdeStatus(const Arguments: TJSONObject): TJSONValue;
begin
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('active', McpBoolValue(FServer.Active));
   TJSONObject(result).AddPair('url', FServer.Url);
   TJSONObject(result).AddPair('configuredPort', TJSONNumber.Create(FServer.Port));
   TJSONObject(result).AddPair('activePort', TJSONNumber.Create(FServer.ActivePort));
   TJSONObject(result).AddPair('activeProject', JsonProject(ModuleServices.GetActiveProject));
   TJSONObject(result).AddPair('currentModule', JsonModule(ModuleServices.CurrentModule));
   TJSONObject(result).AddPair('debug', ToolDebugStatus(nil));
end;

function TMcpIdeBridge.ToolListActions(const Arguments: TJSONObject): TJSONValue;
var
   Actions: TJSONArray;
   Seen: TList<TComponent>;
   TextContains: string;
   MaxItems, Total, i: integer;

   procedure AddAction(Action: TBasicAction);
   var
      Obj: TJSONObject;
      Caption, Hint: string;
   begin
      if Seen.Contains(Action) then begin
         exit;
      end;
      Seen.Add(Action);
      Inc(Total);

      Caption := '';
      Hint := '';
      if Action is TCustomAction then begin
         Caption := TCustomAction(Action).Caption;
         Hint := TCustomAction(Action).Hint;
      end;

      if (TextContains <> '') and
         (Pos(TextContains, LowerCase(Action.Name + ' ' + Caption + ' ' + Hint + ' ' + Action.ClassName)) <= 0) then begin
         exit;
      end;
      if Actions.Count >= MaxItems then begin
         exit;
      end;

      Obj := TJSONObject.Create;
      Obj.AddPair('name', Action.Name);
      Obj.AddPair('className', Action.ClassName);
      Obj.AddPair('caption', Caption);
      Obj.AddPair('hint', Hint);
      if Action is TCustomAction then begin
         Obj.AddPair('enabled', McpBoolValue(TCustomAction(Action).Enabled));
      end;
      Actions.AddElement(Obj);
   end;

   procedure Visit(Component: TComponent);
   var
      i: integer;
   begin
      if Component = nil then begin
         exit;
      end;
      if Component is TBasicAction then begin
         AddAction(TBasicAction(Component));
      end;
      for i := 0 to Component.ComponentCount - 1 do begin
         Visit(Component.Components[i]);
      end;
   end;

begin
   TextContains := LowerCase(McpJsonString(Arguments, 'textContains', ''));
   MaxItems := Round(McpJsonNumber(Arguments, 'max', 200));
   if MaxItems < 1 then begin
      MaxItems := 1;
   end;
   Actions := TJSONArray.Create;
   Seen := TList<TComponent>.Create;
   try
      Total := 0;
      for i := 0 to Screen.FormCount - 1 do begin
         Visit(Screen.Forms[i]);
      end;
      Visit(Application);

      result := TJSONObject.Create;
      TJSONObject(result).AddPair('totalVisited', TJSONNumber.Create(Total));
      TJSONObject(result).AddPair('returned', TJSONNumber.Create(Actions.Count));
      TJSONObject(result).AddPair('truncated', McpBoolValue(Actions.Count >= MaxItems));
      TJSONObject(result).AddPair('actions', Actions);
      Actions := nil;
   finally
      Actions.Free;
      Seen.Free;
   end;
end;

function TMcpIdeBridge.ToolExecuteAction(const Arguments: TJSONObject): TJSONValue;
var
   ActionName: string;
   Found: TBasicAction;
   i: integer;
   Caption, Hint: string;
   Done: TEvent;
   ToolResult: TJSONValue;
   ErrorText: string;
   WaitMs: Cardinal;

   procedure Visit(Component: TComponent);
   var
      i: integer;
   begin
      if (Component = nil) or (Found <> nil) then begin
         exit;
      end;
      if (Component is TBasicAction) and SameText(Component.Name, ActionName) then begin
         Found := TBasicAction(Component);
         exit;
      end;
      for i := 0 to Component.ComponentCount - 1 do begin
         Visit(Component.Components[i]);
      end;
   end;

begin
   if GetCurrentThreadId <> MainThreadID then begin
      ToolResult := nil;
      ErrorText := '';
      WaitMs := Cardinal(Round(McpJsonNumber(Arguments, 'waitMs', 180000)));
      if WaitMs < 1000 then begin
         WaitMs := 1000;
      end;
      Done := TEvent.Create(nil, true, false, '');
      try
         TThread.Queue(nil,
            procedure
            begin
               try
                  ToolResult := ToolExecuteAction(Arguments);
               except
                  on E: Exception do begin
                     ErrorText := E.Message;
                  end;
               end;
               Done.SetEvent;
            end);
         if Done.WaitFor(WaitMs) <> wrSignaled then begin
            raise Exception.CreateFmt('Timeout beim Ausfuehren der IDE-Action "%s" nach %d ms.',
               [McpJsonString(Arguments, 'name', ''), WaitMs]);
         end;
      finally
         Done.Free;
      end;
      if ErrorText <> '' then begin
         raise Exception.Create(ErrorText);
      end;
      result := ToolResult;
      exit;
   end;

   ActionName := McpJsonString(Arguments, 'name', '');
   if ActionName = '' then begin
      raise Exception.Create('ide_execute_action erwartet name.');
   end;

   Found := nil;
   for i := 0 to Screen.FormCount - 1 do begin
      Visit(Screen.Forms[i]);
      if Found <> nil then begin
         break;
      end;
   end;
   if Found = nil then begin
      Visit(Application);
   end;
   if Found = nil then begin
      raise Exception.CreateFmt('IDE-Action nicht gefunden: %s', [ActionName]);
   end;

   Caption := '';
   Hint := '';
   if Found is TCustomAction then begin
      Caption := TCustomAction(Found).Caption;
      Hint := TCustomAction(Found).Hint;
   end;

   Found.Execute;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('executed', McpBoolValue(true));
   TJSONObject(result).AddPair('name', Found.Name);
   TJSONObject(result).AddPair('className', Found.ClassName);
   TJSONObject(result).AddPair('caption', Caption);
   TJSONObject(result).AddPair('hint', Hint);
end;

function TMcpIdeBridge.ToolGetActiveProject(const Arguments: TJSONObject): TJSONValue;
begin
   result := JsonProject(ActiveProject);
end;

function TMcpIdeBridge.ToolSetActiveProject(const Arguments: TJSONObject): TJSONValue;
var
   Group: IOTAProjectGroup;
   Project: IOTAProject;
   FileName, ProjectFileName: string;
   i: integer;
begin
   FileName := ExpandFileName(McpJsonString(Arguments, 'fileName', ''));
   if FileName = '' then begin
      raise Exception.Create('ide_set_active_project erwartet fileName.');
   end;

   Group := ModuleServices.GetMainProjectGroup;
   if Group = nil then begin
      raise Exception.Create('Keine Projektgruppe geladen.');
   end;

   for i := 0 to Group.ProjectCount - 1 do begin
      Project := Group.Projects[i];
      ProjectFileName := ExpandFileName(Project.FileName);
      if SameText(ProjectFileName, FileName) then begin
         Group.ActiveProject := Project;
         result := TJSONObject.Create;
         TJSONObject(result).AddPair('activeProject', JsonProject(Project));
         exit;
      end;
   end;

   raise Exception.CreateFmt('Projekt ist nicht in der aktuellen Projektgruppe: %s', [FileName]);
end;

function TMcpIdeBridge.ToolListProjects(const Arguments: TJSONObject): TJSONValue;
var
   Group: IOTAProjectGroup;
   Arr: TJSONArray;
   i: integer;
begin
   Group := ModuleServices.GetMainProjectGroup;
   Arr := TJSONArray.Create;
   if Group <> nil then begin
      for i := 0 to Group.ProjectCount - 1 do begin
         Arr.AddElement(JsonProject(Group.Projects[i]));
      end;
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('projects', Arr);
end;

function TMcpIdeBridge.ToolListProjectModules(const Arguments: TJSONObject): TJSONValue;
var
   Project: IOTAProject;
   Arr: TJSONArray;
   i: integer;
begin
   Project := ActiveProject;
   Arr := TJSONArray.Create;
   for i := 0 to Project.GetModuleCount - 1 do begin
      Arr.AddElement(JsonModuleInfo(Project.GetModule(i)));
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('project', JsonProject(Project));
   TJSONObject(result).AddPair('modules', Arr);
end;

function TMcpIdeBridge.ToolGetCurrentModule(const Arguments: TJSONObject): TJSONValue;
begin
   result := JsonModule(ModuleServices.CurrentModule);
end;

function TMcpIdeBridge.ToolOpenFile(const Arguments: TJSONObject): TJSONValue;
var
   FileName: string;
   ShowModule: boolean;
   Module: IOTAModule;
begin
   FileName := McpJsonString(Arguments, 'fileName', '');
   if FileName = '' then begin
      raise Exception.Create('ide_open_file erwartet fileName.');
   end;
   ShowModule := McpJsonBool(Arguments, 'show', true);
   Module := ModuleServices.OpenModule(FileName);
   if (Module <> nil) and ShowModule then begin
      Module.Show;
   end
   else if Module = nil then begin
      if not ActionServices.OpenFile(FileName) then begin
         raise Exception.CreateFmt('Datei konnte nicht geoeffnet werden: %s', [FileName]);
      end;
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('opened', McpBoolValue(true));
   TJSONObject(result).AddPair('fileName', FileName);
end;

function TMcpIdeBridge.ToolCloseFile(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTAModuleServices;
   Module: IOTAModule;
   FileName, ModuleFileName: string;
   ForceClose, Closed: boolean;
   i: integer;
begin
   FileName := ExpandFileName(McpJsonString(Arguments, 'fileName', ''));
   if FileName = '' then begin
      raise Exception.Create('ide_close_file erwartet fileName.');
   end;

   ForceClose := McpJsonBool(Arguments, 'force', true);
   Services := ModuleServices;
   Module := nil;

   for i := 0 to Services.GetModuleCount - 1 do begin
      ModuleFileName := ExpandFileName(Services.GetModule(i).FileName);
      if SameFileName(ModuleFileName, FileName) then begin
         Module := Services.GetModule(i);
         break;
      end;
   end;

   Closed := false;
   if Module <> nil then begin
      Closed := Module.CloseModule(ForceClose);
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('fileName', FileName);
   TJSONObject(result).AddPair('found', McpBoolValue(Module <> nil));
   TJSONObject(result).AddPair('closed', McpBoolValue(Closed));
   TJSONObject(result).AddPair('force', McpBoolValue(ForceClose));
end;

function TMcpIdeBridge.ToolSaveAll(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTAModuleServices;
   Arr: TJSONArray;
   Obj: TJSONObject;
   Module: IOTAModule;
   i: integer;
   Saved: boolean;
begin
   Services := ModuleServices;
   Arr := TJSONArray.Create;
   for i := 0 to Services.GetModuleCount - 1 do begin
      Module := Services.GetModule(i);
      Obj := TJSONObject.Create;
      Obj.AddPair('fileName', Module.FileName);
      Saved := Module.Save(false, true);
      Obj.AddPair('saved', McpBoolValue(Saved));
      Arr.AddElement(Obj);
   end;
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('modules', Arr);
end;

function TMcpIdeBridge.ToolExitIde(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTAModuleServices;
   Module: IOTAModule;
   SaveAll: boolean;
   i: integer;
begin
   if (Application = nil) or (Application.MainForm = nil) or (not Application.MainForm.HandleAllocated) then begin
      raise Exception.Create('IDE-Hauptfenster ist nicht verfuegbar.');
   end;

   SaveAll := McpJsonBool(Arguments, 'saveAll', true);
   if SaveAll then begin
      Services := ModuleServices;
      for i := 0 to Services.GetModuleCount - 1 do begin
         Module := Services.GetModule(i);
         Module.Save(false, true);
      end;
   end;

   PostMessage(Application.MainForm.Handle, WM_CLOSE, 0, 0);

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('closing', McpBoolValue(true));
   TJSONObject(result).AddPair('saveAll', McpBoolValue(SaveAll));
end;

function TMcpIdeBridge.ToolCloseSaveDialogs(const Arguments: TJSONObject): TJSONValue;
var
   Context: TMcpCloseSaveDialogContext;
   Action: string;
begin
   Action := LowerCase(McpJsonString(Arguments, 'action', 'discard'));
   if (Action <> 'discard') and (Action <> 'no') and (Action <> 'save') and (Action <> 'cancel') then begin
      raise Exception.Create('action muss discard, save oder cancel sein.');
   end;

   Context.ProcessId := GetCurrentProcessId;
   Context.Action := Action;
   Context.OpenCount := 0;
   Context.ClosedCount := 0;
   EnumWindows(@McpCloseSaveDialogEnumProc, LPARAM(@Context));

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('action', Action);
   TJSONObject(result).AddPair('openCount', TJSONNumber.Create(Context.OpenCount));
   TJSONObject(result).AddPair('closedCount', TJSONNumber.Create(Context.ClosedCount));
end;

function TMcpIdeBridge.ToolListWindows(const Arguments: TJSONObject): TJSONValue;
var
   Context: TMcpWindowEnumContext;
   Scope: string;
   RootWnd: HWND;
begin
   if (Application = nil) or (Application.MainForm = nil) or (not Application.MainForm.HandleAllocated) then begin
      raise Exception.Create('IDE-Hauptfenster ist nicht verfuegbar.');
   end;

   Scope := LowerCase(McpJsonString(Arguments, 'scope', 'ide'));
   Context.Bridge := Self;
   Context.Windows := TJSONArray.Create;
   Context.Seen := TList<HWND>.Create;
   Context.IncludeInvisible := McpJsonBool(Arguments, 'includeInvisible', false);
   Context.IncludeText := McpJsonBool(Arguments, 'includeText', true);
   Context.TextContains := LowerCase(McpJsonString(Arguments, 'textContains', ''));
   Context.ClassContains := LowerCase(McpJsonString(Arguments, 'classContains', ''));
   Context.MaxItems := Round(McpJsonNumber(Arguments, 'max', 300));
   Context.TotalVisited := 0;
   Context.TotalMatched := 0;
   if Context.MaxItems < 0 then begin
      Context.MaxItems := 0;
   end;

   try
      if McpJsonString(Arguments, 'rootHwnd', '') <> '' then begin
         RootWnd := HWND(StrToInt64('$' + McpJsonString(Arguments, 'rootHwnd', '')));
         if not IsWindow(RootWnd) then begin
            raise Exception.Create('rootHwnd ist kein gueltiges Fenster-Handle.');
         end;
      end
      else begin
         RootWnd := Application.MainForm.Handle;
      end;
      if Scope = 'thread' then begin
         EnumThreadWindows(GetCurrentThreadId, @McpEnumThreadWindowsProc, LPARAM(@Context));
      end
      else begin
         McpAddWindowToContext(RootWnd, @Context);
         EnumChildWindows(RootWnd, @McpEnumChildWindowsProc, LPARAM(@Context));
      end;

      result := TJSONObject.Create;
      TJSONObject(result).AddPair('scope', Scope);
      TJSONObject(result).AddPair('rootHwnd', IntToHex(NativeUInt(RootWnd), SizeOf(HWND) * 2));
      TJSONObject(result).AddPair('totalVisited', TJSONNumber.Create(Context.TotalVisited));
      TJSONObject(result).AddPair('totalMatched', TJSONNumber.Create(Context.TotalMatched));
      TJSONObject(result).AddPair('truncated', McpBoolValue((Context.MaxItems > 0) and (Context.TotalMatched >= Context.MaxItems)));
      TJSONObject(result).AddPair('windows', Context.Windows);
      Context.Windows := nil;
   finally
      Context.Windows.Free;
      Context.Seen.Free;
   end;
end;

function TMcpIdeBridge.ToolInspectWindow(const Arguments: TJSONObject): TJSONValue;
var
   Wnd: HWND;
   HwndText: string;
   StandardMessages: TJSONObject;
   Tree: TJSONObject;
   List: TJSONObject;
begin
   HwndText := McpJsonString(Arguments, 'hwnd', '');
   if HwndText = '' then begin
      raise Exception.Create('ide_inspect_window erwartet hwnd.');
   end;

   Wnd := HWND(StrToInt64('$' + HwndText));
   if not IsWindow(Wnd) then begin
      raise Exception.Create('hwnd ist kein gueltiges Fenster-Handle.');
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('window', JsonWindow(Wnd, true));

   StandardMessages := TJSONObject.Create;
   StandardMessages.AddPair('wmGetTextLength', TJSONNumber.Create(GetWindowTextLength(Wnd)));
   StandardMessages.AddPair('wmGetDlgCtrlId', TJSONNumber.Create(GetDlgCtrlID(Wnd)));
   TJSONObject(result).AddPair('standardMessages', StandardMessages);

   Tree := TJSONObject.Create;
   Tree.AddPair('count', TJSONNumber.Create(SendMessage(Wnd, TVM_GETCOUNT, 0, 0)));
   Tree.AddPair('itemHeight', TJSONNumber.Create(SendMessage(Wnd, TVM_GETITEMHEIGHT, 0, 0)));
   Tree.AddPair('rootItem', IntToHex(NativeUInt(SendMessage(Wnd, TVM_GETNEXTITEM, TVGN_ROOT, 0)), SizeOf(Pointer) * 2));
   Tree.AddPair('caretItem', IntToHex(NativeUInt(SendMessage(Wnd, TVM_GETNEXTITEM, TVGN_CARET, 0)), SizeOf(Pointer) * 2));
   TJSONObject(result).AddPair('treeViewMessages', Tree);

   List := TJSONObject.Create;
   List.AddPair('itemCount', TJSONNumber.Create(SendMessage(Wnd, LVM_GETITEMCOUNT, 0, 0)));
   List.AddPair('selectedCount', TJSONNumber.Create(SendMessage(Wnd, LVM_GETSELECTEDCOUNT, 0, 0)));
   List.AddPair('nextSelected', TJSONNumber.Create(SendMessage(Wnd, LVM_GETNEXTITEM, WPARAM(-1), LVNI_SELECTED)));
   TJSONObject(result).AddPair('listViewMessages', List);
end;

function TMcpIdeBridge.ToolInspectVclControl(const Arguments: TJSONObject): TJSONValue;
const
   PropertyNames: array[0..18] of string = (
      'Name', 'Caption', 'Text', 'Hint', 'Visible', 'Enabled', 'Align', 'TabOrder', 'TabStop',
      'Left', 'Top', 'Width', 'Height', 'ClientWidth', 'ClientHeight', 'RootNodeCount',
      'TotalCount', 'VisibleCount', 'Focused'
   );
var
   Wnd: HWND;
   HwndText: string;
   Control: TWinControl;
   Obj: TJSONObject;
   Props: TJSONObject;
   RttiProps: TJSONArray;
   RttiMethods: TJSONArray;
   RttiObj: TJSONObject;
   RttiContext: TRttiContext;
   RttiType: TRttiType;
   RttiProp: TRttiProperty;
   RttiMethod: TRttiMethod;
   RttiParam: TRttiParameter;
   Params: TJSONArray;
   PropInfo: PPropInfo;
   PropName: string;
   RttiContains: string;
   IncludeRtti: boolean;
   MaxRtti, Count: integer;
begin
   HwndText := McpJsonString(Arguments, 'hwnd', '');
   if HwndText = '' then begin
      raise Exception.Create('ide_inspect_vcl_control erwartet hwnd.');
   end;

   Wnd := HWND(StrToInt64('$' + HwndText));
   if not IsWindow(Wnd) then begin
      raise Exception.Create('hwnd ist kein gueltiges Fenster-Handle.');
   end;

   Control := FindControl(Wnd);

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('window', JsonWindow(Wnd, true));
   TJSONObject(result).AddPair('found', McpBoolValue(Control <> nil));
   if Control = nil then begin
      exit;
   end;
   IncludeRtti := McpJsonBool(Arguments, 'includeRtti', true);
   MaxRtti := Round(McpJsonNumber(Arguments, 'maxRtti', 120));
   RttiContains := LowerCase(McpJsonString(Arguments, 'rttiContains', ''));
   if MaxRtti < 0 then begin
      MaxRtti := 0;
   end;

   Obj := TJSONObject.Create;
   Obj.AddPair('className', Control.ClassName);
   Obj.AddPair('name', Control.Name);
   if Control.Owner <> nil then begin
      Obj.AddPair('ownerClassName', Control.Owner.ClassName);
      if Control.Owner is TComponent then begin
         Obj.AddPair('ownerName', TComponent(Control.Owner).Name);
      end;
   end;
   if Control.Parent <> nil then begin
      Obj.AddPair('parentClassName', Control.Parent.ClassName);
      Obj.AddPair('parentName', Control.Parent.Name);
   end;
   Obj.AddPair('controlCount', TJSONNumber.Create(Control.ControlCount));
   Obj.AddPair('componentCount', TJSONNumber.Create(Control.ComponentCount));
   TJSONObject(result).AddPair('control', Obj);

   Props := TJSONObject.Create;
   for PropName in PropertyNames do begin
      PropInfo := GetPropInfo(Control.ClassInfo, PropName);
      if PropInfo <> nil then begin
         try
            case PropInfo.PropType^.Kind of
               tkInteger, tkChar, tkWChar, tkEnumeration, tkSet:
                  Props.AddPair(PropName, VarToStr(GetPropValue(Control, PropName, true)));
               tkString, tkLString, tkWString, tkUString:
                  Props.AddPair(PropName, GetStrProp(Control, PropInfo));
               tkInt64:
                  Props.AddPair(PropName, TJSONNumber.Create(GetInt64Prop(Control, PropInfo)));
            else
               Props.AddPair(PropName, '<unsupported ' + GetEnumName(TypeInfo(TTypeKind), Ord(PropInfo.PropType^.Kind)) + '>');
            end;
         except
            on E: Exception do begin
               Props.AddPair(PropName, '<error: ' + E.Message + '>');
            end;
         end;
      end;
   end;
   TJSONObject(result).AddPair('publishedProperties', Props);

   if IncludeRtti then begin
      RttiProps := TJSONArray.Create;
      RttiMethods := TJSONArray.Create;
      RttiContext := TRttiContext.Create;
      RttiType := RttiContext.GetType(Control.ClassType);
      if RttiType <> nil then begin
         Count := 0;
         for RttiProp in RttiType.GetProperties do begin
            if (RttiContains <> '') and (Pos(RttiContains, LowerCase(RttiProp.Name)) <= 0) then begin
               continue;
            end;
            if (MaxRtti > 0) and (Count >= MaxRtti) then begin
               break;
            end;
            RttiObj := TJSONObject.Create;
            RttiObj.AddPair('name', RttiProp.Name);
            if RttiProp.PropertyType <> nil then begin
               RttiObj.AddPair('typeName', RttiProp.PropertyType.ToString);
            end;
            RttiObj.AddPair('visibility', GetEnumName(TypeInfo(TMemberVisibility), Ord(RttiProp.Visibility)));
            RttiObj.AddPair('readable', McpBoolValue(RttiProp.IsReadable));
            RttiObj.AddPair('writable', McpBoolValue(RttiProp.IsWritable));
            RttiProps.AddElement(RttiObj);
            Inc(Count);
         end;

         Count := 0;
         for RttiMethod in RttiType.GetMethods do begin
            if (RttiContains <> '') and (Pos(RttiContains, LowerCase(RttiMethod.Name)) <= 0) then begin
               continue;
            end;
            if (MaxRtti > 0) and (Count >= MaxRtti) then begin
               break;
            end;
            RttiObj := TJSONObject.Create;
            RttiObj.AddPair('name', RttiMethod.Name);
            RttiObj.AddPair('visibility', GetEnumName(TypeInfo(TMemberVisibility), Ord(RttiMethod.Visibility)));
            if RttiMethod.ReturnType <> nil then begin
               RttiObj.AddPair('returnType', RttiMethod.ReturnType.ToString);
            end;
            Params := TJSONArray.Create;
            for RttiParam in RttiMethod.GetParameters do begin
               Obj := TJSONObject.Create;
               Obj.AddPair('name', RttiParam.Name);
               if RttiParam.ParamType <> nil then begin
                  Obj.AddPair('typeName', RttiParam.ParamType.ToString);
               end;
               Obj.AddPair('flags', McpParamFlagsText(RttiParam.Flags));
               Params.AddElement(Obj);
            end;
            RttiObj.AddPair('parameters', Params);
            RttiMethods.AddElement(RttiObj);
            Inc(Count);
         end;
      end;
      TJSONObject(result).AddPair('rttiProperties', RttiProps);
      TJSONObject(result).AddPair('rttiMethods', RttiMethods);
   end;
end;

function TMcpIdeBridge.ToolListVclComponents(const Arguments: TJSONObject): TJSONValue;
var
   Wnd: HWND;
   HwndText: string;
   Control: TWinControl;
   MaxDepth: integer;
   IncludeProperties: boolean;
begin
   HwndText := McpJsonString(Arguments, 'hwnd', '');
   if HwndText = '' then begin
      raise Exception.Create('ide_list_vcl_components erwartet hwnd.');
   end;

   Wnd := HWND(StrToInt64('$' + HwndText));
   if not IsWindow(Wnd) then begin
      raise Exception.Create('hwnd ist kein gueltiges Fenster-Handle.');
   end;

   Control := FindControl(Wnd);
   MaxDepth := Round(McpJsonNumber(Arguments, 'maxDepth', 2));
   IncludeProperties := McpJsonBool(Arguments, 'includeProperties', true);
   if MaxDepth < 0 then begin
      MaxDepth := 0;
   end;
   if MaxDepth > 5 then begin
      MaxDepth := 5;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('window', JsonWindow(Wnd, true));
   TJSONObject(result).AddPair('found', McpBoolValue(Control <> nil));
   TJSONObject(result).AddPair('maxDepth', TJSONNumber.Create(MaxDepth));
   TJSONObject(result).AddPair('includeProperties', McpBoolValue(IncludeProperties));
   if Control <> nil then begin
      TJSONObject(result).AddPair('componentTree', JsonVclComponent(Control, 0, MaxDepth, IncludeProperties));
   end;
end;

function TMcpIdeBridge.ToolListVclForms(const Arguments: TJSONObject): TJSONValue;
var
   Forms: TJSONArray;
   FormObj: TJSONObject;
   Form: TCustomForm;
   MaxDepth: integer;
   i, Matched: integer;
   VisibleOnly: boolean;
   IncludeProperties: boolean;
   ClassContains: string;
   NameContains: string;
   CaptionContains: string;
begin
   VisibleOnly := McpJsonBool(Arguments, 'visibleOnly', true);
   IncludeProperties := McpJsonBool(Arguments, 'includeProperties', true);
   MaxDepth := Round(McpJsonNumber(Arguments, 'maxDepth', 1));
   ClassContains := LowerCase(McpJsonString(Arguments, 'classContains', ''));
   NameContains := LowerCase(McpJsonString(Arguments, 'nameContains', ''));
   CaptionContains := LowerCase(McpJsonString(Arguments, 'captionContains', ''));
   if MaxDepth < 0 then begin
      MaxDepth := 0;
   end;
   if MaxDepth > 5 then begin
      MaxDepth := 5;
   end;

   Forms := TJSONArray.Create;
   Matched := 0;
   for i := 0 to Screen.FormCount - 1 do begin
      Form := Screen.Forms[i];
      if VisibleOnly and not Form.Visible then begin
         continue;
      end;
      if (ClassContains <> '') and (Pos(ClassContains, LowerCase(Form.ClassName)) <= 0) then begin
         continue;
      end;
      if (NameContains <> '') and (Pos(NameContains, LowerCase(Form.Name)) <= 0) then begin
         continue;
      end;
      if (CaptionContains <> '') and (Pos(CaptionContains, LowerCase(Form.Caption)) <= 0) then begin
         continue;
      end;

      FormObj := JsonVclComponent(Form, 0, MaxDepth, IncludeProperties);
      FormObj.AddPair('formIndex', TJSONNumber.Create(i));
      Forms.AddElement(FormObj);
      Inc(Matched);
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('formCount', TJSONNumber.Create(Screen.FormCount));
   TJSONObject(result).AddPair('matchedCount', TJSONNumber.Create(Matched));
   TJSONObject(result).AddPair('visibleOnly', McpBoolValue(VisibleOnly));
   TJSONObject(result).AddPair('maxDepth', TJSONNumber.Create(MaxDepth));
   TJSONObject(result).AddPair('includeProperties', McpBoolValue(IncludeProperties));
   TJSONObject(result).AddPair('forms', Forms);
end;

function TMcpIdeBridge.ToolGetVclTreeText(const Arguments: TJSONObject): TJSONValue;
begin
   result := VclTreeTextByForm(
      LowerCase(McpJsonString(Arguments, 'formClassContains', '')),
      LowerCase(McpJsonString(Arguments, 'formNameContains', '')),
      LowerCase(McpJsonString(Arguments, 'formCaptionContains', '')),
      LowerCase(McpJsonString(Arguments, 'controlNameContains', '')),
      LowerCase(McpJsonString(Arguments, 'controlClassContains', 'virtual')),
      McpJsonBool(Arguments, 'visibleOnly', false),
      Round(McpJsonNumber(Arguments, 'maxRows', 100)),
      Round(McpJsonNumber(Arguments, 'maxColumns', 8))
   );
end;

function TMcpIdeBridge.ToolGetVirtualTreeText(const Arguments: TJSONObject): TJSONValue;
var
   Wnd: HWND;
   HwndText: string;
   Rows: TJSONArray;
   MaxRows, MaxColumns, RowCount: integer;
   Truncated: boolean;
   ControlClassName, ControlName: string;
begin
   HwndText := McpJsonString(Arguments, 'hwnd', '');
   if HwndText = '' then begin
      raise Exception.Create('ide_get_virtual_tree_text erwartet hwnd.');
   end;

   Wnd := HWND(StrToInt64('$' + HwndText));
   if not IsWindow(Wnd) then begin
      raise Exception.Create('hwnd ist kein gueltiges Fenster-Handle.');
   end;

   MaxRows := Round(McpJsonNumber(Arguments, 'maxRows', 100));
   MaxColumns := Round(McpJsonNumber(Arguments, 'maxColumns', 8));
   Rows := ExtractVirtualTreeRows(Wnd, MaxRows, MaxColumns, RowCount, Truncated, ControlClassName, ControlName);

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('window', JsonWindow(Wnd, true));
   TJSONObject(result).AddPair('controlClassName', ControlClassName);
   TJSONObject(result).AddPair('controlName', ControlName);
   TJSONObject(result).AddPair('rowCount', TJSONNumber.Create(RowCount));
   TJSONObject(result).AddPair('truncated', McpBoolValue(Truncated));
   TJSONObject(result).AddPair('rows', Rows);
end;

function TMcpIdeBridge.ToolGetBuildMessages(const Arguments: TJSONObject): TJSONValue;
var
   MessageWnd, TreeWnd, CandidateWnd: HWND;
   Context: TMcpWindowEnumContext;
   Rows, Messages, Diagnostics: TJSONArray;
   RowObj, Diagnostic: TJSONObject;
   Cells: TJSONArray;
   CellValue: TJSONValue;
   MaxRows, RowCount, i, Area, BestArea, WarningCount, ErrorCount: integer;
   Truncated: boolean;
   BuildSucceeded: boolean;
   ControlClassName, ControlName, Text: string;
   Rect: TRect;
begin
   MessageWnd := McpFindThreadWindow('MessageView', 'Meldungen', true);
   if MessageWnd = 0 then begin
      MessageWnd := McpFindThreadWindow('MessageView', '', true);
   end;
   if MessageWnd = 0 then begin
      raise Exception.Create('IDE-Meldungsfenster wurde nicht gefunden.');
   end;

   TreeWnd := 0;
   BestArea := -1;
   Context.Bridge := Self;
   Context.Windows := TJSONArray.Create;
   Context.Seen := TList<HWND>.Create;
   Context.IncludeInvisible := false;
   Context.IncludeText := true;
   Context.TextContains := '';
   Context.ClassContains := LowerCase('VirtualDrawTree');
   Context.MaxItems := 20;
   Context.TotalVisited := 0;
   Context.TotalMatched := 0;
   try
      EnumChildWindows(MessageWnd, @McpEnumChildWindowsProc, LPARAM(@Context));
      for i := 0 to Context.Windows.Count - 1 do begin
         if Context.Windows.Items[i] is TJSONObject then begin
            CandidateWnd := HWND(StrToInt64('$' + TJSONObject(Context.Windows.Items[i]).GetValue<string>('hwnd')));
            Area := 0;
            if GetWindowRect(CandidateWnd, Rect) then begin
               Area := (Rect.Right - Rect.Left) * (Rect.Bottom - Rect.Top);
            end;
            if Area > BestArea then begin
               TreeWnd := CandidateWnd;
               BestArea := Area;
            end;
         end;
      end;
   finally
      Context.Windows.Free;
      Context.Seen.Free;
   end;

   if TreeWnd = 0 then begin
      TreeWnd := McpFindChildWindow(MessageWnd, 'VirtualDrawTree', '', false);
   end;
   if TreeWnd = 0 then begin
      raise Exception.Create('VirtualTree im IDE-Meldungsfenster wurde nicht gefunden.');
   end;

   MaxRows := Round(McpJsonNumber(Arguments, 'maxRows', 300));
   Rows := ExtractVirtualTreeRows(TreeWnd, MaxRows, 1, RowCount, Truncated, ControlClassName, ControlName);
   Messages := TJSONArray.Create;
   Diagnostics := TJSONArray.Create;
   WarningCount := -1;
   ErrorCount := -1;
   BuildSucceeded := false;
   for i := 0 to Rows.Count - 1 do begin
      Text := '';
      if Rows.Items[i] is TJSONObject then begin
         RowObj := TJSONObject(Rows.Items[i]);
         Cells := RowObj.GetValue<TJSONArray>('cells');
         if (Cells <> nil) and (Cells.Count > 0) then begin
            CellValue := Cells.Items[0];
            if CellValue is TJSONString then begin
               Text := TJSONString(CellValue).Value;
            end
            else if CellValue <> nil then begin
               Text := CellValue.Value;
            end;
         end;
      end;
      Messages.AddElement(TJSONString.Create(Text));
      Diagnostic := McpParseBuildDiagnostic(Text);
      if Diagnostic <> nil then begin
         Diagnostics.AddElement(Diagnostic);
      end;
      if Pos('Warnung(en)', Text) > 0 then begin
         WarningCount := McpSummaryCount(Text, 'Warnung(en)', WarningCount);
      end;
      if Pos('Fehler', Text) > 0 then begin
         ErrorCount := McpSummaryCount(Text, 'Fehler', ErrorCount);
      end;
      if Pos('Das Erstellen war erfolgreich', Text) > 0 then begin
         BuildSucceeded := true;
      end;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('messageWindow', JsonWindow(MessageWnd, true));
   TJSONObject(result).AddPair('treeWindow', JsonWindow(TreeWnd, true));
   TJSONObject(result).AddPair('controlClassName', ControlClassName);
   TJSONObject(result).AddPair('controlName', ControlName);
   TJSONObject(result).AddPair('rowCount', TJSONNumber.Create(RowCount));
   TJSONObject(result).AddPair('truncated', McpBoolValue(Truncated));
   TJSONObject(result).AddPair('success', McpBoolValue(BuildSucceeded or (ErrorCount = 0)));
   TJSONObject(result).AddPair('warningCount', TJSONNumber.Create(WarningCount));
   TJSONObject(result).AddPair('errorCount', TJSONNumber.Create(ErrorCount));
   TJSONObject(result).AddPair('diagnosticCount', TJSONNumber.Create(Diagnostics.Count));
   TJSONObject(result).AddPair('diagnostics', Diagnostics);
   TJSONObject(result).AddPair('messages', Messages);
   TJSONObject(result).AddPair('rows', Rows);
end;

function TMcpIdeBridge.ToolGetDiagnostics(const Arguments: TJSONObject): TJSONValue;
var
   Forms: TJSONArray;
   Form: TCustomForm;
   BuildMessages: TJSONValue;
   IncludeForms, IncludeAllForms, LooksRelevant: boolean;
   MaxForms, MaxDepth, MaxTextItems: integer;
   i, Matched: integer;
   ClassText, NameText, CaptionText, Combined: string;
begin
   IncludeForms := McpJsonBool(Arguments, 'includeForms', true);
   IncludeAllForms := McpJsonBool(Arguments, 'includeAllForms', false);
   MaxForms := Round(McpJsonNumber(Arguments, 'maxForms', 12));
   MaxDepth := Round(McpJsonNumber(Arguments, 'maxDepth', 4));
   MaxTextItems := Round(McpJsonNumber(Arguments, 'maxTextItems', 80));
   if MaxForms < 1 then begin
      MaxForms := 1;
   end;
   if MaxDepth < 0 then begin
      MaxDepth := 0;
   end;
   if MaxDepth > 8 then begin
      MaxDepth := 8;
   end;
   if MaxTextItems < 1 then begin
      MaxTextItems := 1;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('tool', 'ide_get_diagnostics');

   try
      BuildMessages := ToolGetBuildMessages(Arguments);
      TJSONObject(result).AddPair('buildMessagesAvailable', McpBoolValue(true));
      TJSONObject(result).AddPair('buildMessages', BuildMessages);
   except
      on E: Exception do begin
         TJSONObject(result).AddPair('buildMessagesAvailable', McpBoolValue(false));
         TJSONObject(result).AddPair('buildMessagesError', E.Message);
      end;
   end;

   Forms := TJSONArray.Create;
   Matched := 0;
   if IncludeForms then begin
      for i := 0 to Screen.FormCount - 1 do begin
         Form := Screen.Forms[i];
         if not Form.Visible then begin
            continue;
         end;

         ClassText := LowerCase(Form.ClassName);
         NameText := LowerCase(Form.Name);
         CaptionText := LowerCase(Form.Caption);
         Combined := ClassText + ' ' + NameText + ' ' + CaptionText;
         LooksRelevant := IncludeAllForms
            or (Pos('progress', Combined) > 0)
            or (Pos('message', Combined) > 0)
            or (Pos('meldung', Combined) > 0)
            or (Pos('error', Combined) > 0)
            or (Pos('fehler', Combined) > 0)
            or (Pos('exception', Combined) > 0)
            or (Pos('except', Combined) > 0)
            or (Pos('dialog', Combined) > 0)
            or (Pos('compiler', Combined) > 0)
            or (Pos('compile', Combined) > 0)
            or (Pos('build', Combined) > 0);
         if not LooksRelevant then begin
            continue;
         end;

         if Forms.Count < MaxForms then begin
            Forms.AddElement(JsonVclDiagnosticForm(Form, MaxDepth, MaxTextItems));
         end;
         Inc(Matched);
      end;
   end;

   TJSONObject(result).AddPair('formsIncluded', McpBoolValue(IncludeForms));
   TJSONObject(result).AddPair('includeAllForms', McpBoolValue(IncludeAllForms));
   TJSONObject(result).AddPair('formCount', TJSONNumber.Create(Screen.FormCount));
   TJSONObject(result).AddPair('matchedFormCount', TJSONNumber.Create(Matched));
   TJSONObject(result).AddPair('formsTruncated', McpBoolValue(Matched > Forms.Count));
   TJSONObject(result).AddPair('forms', Forms);
end;

function TMcpIdeBridge.ToolCloseBuildDialogs(const Arguments: TJSONObject): TJSONValue;
var
   Closer: TMcpBuildProgressCloser;
   OpenCount, ClosedCount: integer;
begin
   Closer := TMcpBuildProgressCloser.Create;
   try
      ClosedCount := Closer.CloseFailedProgressDialogs;
      OpenCount := Closer.OpenCount;
   finally
      Closer.Free;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('open', McpBoolValue(OpenCount > 0));
   TJSONObject(result).AddPair('closed', McpBoolValue(ClosedCount > 0));
   TJSONObject(result).AddPair('openCount', TJSONNumber.Create(OpenCount));
   TJSONObject(result).AddPair('closedCount', TJSONNumber.Create(ClosedCount));
end;

function TMcpIdeBridge.ToolBuildProjectByAction(const Arguments: TJSONObject): TJSONValue;
var
   ModeText, ActionName, ActionError, MainThreadError: string;
   BuildWaitMs, DiagnosticCount: integer;
   ActionArgs: TJSONObject;
   ActionResult, CloseResult, BuildMessages: TJSONValue;
   Done: TEvent;
   ActionStarted, ActionWaitTimedOut, BuildMessagesAvailable, DialogCloseAttempted: boolean;
begin
   ModeText := McpJsonString(Arguments, 'mode', 'make');
   ActionName := McpJsonString(Arguments, 'actionName', '');
   if ActionName = '' then begin
      if SameText(ModeText, 'build') then begin
         ActionName := 'ProjectBuildCommand';
      end
      else begin
         ActionName := 'ProjectCompileCommand';
      end;
   end;

   BuildWaitMs := Round(McpJsonNumber(Arguments, 'buildWaitMs', 120000));
   if BuildWaitMs < 1000 then begin
      BuildWaitMs := 1000;
   end;

   ActionStarted := false;
   ActionWaitTimedOut := false;
   ActionResult := nil;
   ActionError := '';
   ActionArgs := TJSONObject.Create;
   try
      ActionArgs.AddPair('name', ActionName);
      ActionArgs.AddPair('waitMs', TJSONNumber.Create(BuildWaitMs));
      try
         ActionResult := ToolExecuteAction(ActionArgs);
         ActionStarted := true;
      except
         on E: Exception do begin
            ActionError := E.Message;
            ActionWaitTimedOut := Pos('Timeout', ActionError) > 0;
         end;
      end;
   finally
      ActionArgs.Free;
   end;

   CloseResult := nil;
   BuildMessages := nil;
   MainThreadError := '';
   DialogCloseAttempted := false;
   Done := TEvent.Create(nil, true, false, '');
   try
      TThread.Queue(nil,
         procedure
         begin
            try
               DialogCloseAttempted := true;
               CloseResult := ToolCloseBuildDialogs(nil);
               BuildMessages := ToolGetBuildMessages(Arguments);
            except
               on E: Exception do begin
                  MainThreadError := E.Message;
               end;
            end;
            Done.SetEvent;
         end);
      if Done.WaitFor(30000) <> wrSignaled then begin
         MainThreadError := 'Timeout beim Lesen der Builddiagnosen nach Action-Build.';
      end;
   finally
      Done.Free;
   end;

   BuildMessagesAvailable := BuildMessages <> nil;
   DiagnosticCount := 0;
   if BuildMessagesAvailable and (BuildMessages is TJSONObject) then begin
      DiagnosticCount := Round(McpJsonNumber(TJSONObject(BuildMessages), 'diagnosticCount', 0));
   end;
   if (not ActionStarted) and BuildMessagesAvailable then begin
      ActionStarted := true;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('method', 'action');
   TJSONObject(result).AddPair('mode', ModeText);
   TJSONObject(result).AddPair('actionName', ActionName);
   TJSONObject(result).AddPair('actionStarted', McpBoolValue(ActionStarted));
   TJSONObject(result).AddPair('actionWaitTimedOut', McpBoolValue(ActionWaitTimedOut));
   TJSONObject(result).AddPair('dialogCloseAttempted', McpBoolValue(DialogCloseAttempted));
   TJSONObject(result).AddPair('diagnosticsAvailable', McpBoolValue(DiagnosticCount > 0));
   TJSONObject(result).AddPair('diagnosticCount', TJSONNumber.Create(DiagnosticCount));
   TJSONObject(result).AddPair('actionExecuted', McpBoolValue(ActionStarted));
   if ActionResult <> nil then begin
      TJSONObject(result).AddPair('actionResult', ActionResult);
      ActionResult := nil;
   end;
   if ActionError <> '' then begin
      TJSONObject(result).AddPair('actionError', ActionError);
   end;
   if CloseResult <> nil then begin
      TJSONObject(result).AddPair('closeBuildDialogs', CloseResult);
      CloseResult := nil;
   end;
   if BuildMessages <> nil then begin
      TJSONObject(result).AddPair('success', McpBoolValue(McpJsonBool(TJSONObject(BuildMessages), 'success', false)));
      TJSONObject(result).AddPair('compileFinished', McpBoolValue(true));
      TJSONObject(result).AddPair('waitTimedOut', McpBoolValue(ActionWaitTimedOut));
      TJSONObject(result).AddPair('buildMessagesAvailable', McpBoolValue(true));
      TJSONObject(result).AddPair('buildMessages', BuildMessages);
      BuildMessages := nil;
   end
   else begin
      TJSONObject(result).AddPair('success', McpBoolValue(false));
      TJSONObject(result).AddPair('compileFinished', McpBoolValue(false));
      TJSONObject(result).AddPair('waitTimedOut', McpBoolValue(ActionWaitTimedOut));
      TJSONObject(result).AddPair('buildMessagesAvailable', McpBoolValue(false));
   end;
   if MainThreadError <> '' then begin
      TJSONObject(result).AddPair('buildMessagesError', MainThreadError);
   end;
   TJSONObject(result).AddPair('compileEvents', JsonCompileEvents);

   CloseResult.Free;
   BuildMessages.Free;
   ActionResult.Free;
end;

function TMcpIdeBridge.ToolBuildProject(const Arguments: TJSONObject): TJSONValue;
var
   Project: IOTAProject;
   Builder: IOTAProjectBuilder;
   ModeText, MethodText: string;
   Wait, ClearMessages, AllowSelfBuild, Ok: boolean;
   ProjectNotifier: IOTAProjectCompileNotifier;
   ProjectNotifierIndex, BuildWaitMs: integer;
   ProgressCloser: TMcpBuildProgressCloser;
   BuildStarter: TMcpIdeBuildStarter;
   ClosedProgressDialogCount: integer;
   Deadline: UInt64;
   CompileFinished, WaitTimedOut: boolean;
   Event: TMcpCompileEvent;
   BuildMessages: TJSONValue;
   Done: TEvent;
   ToolResult: TJSONValue;
   ErrorText: string;
   MainThreadTimeoutMs: Cardinal;
begin
   MethodText := McpJsonString(Arguments, 'method', 'action');
   if SameText(MethodText, 'action') then begin
      result := ToolBuildProjectByAction(Arguments);
      exit;
   end;

   if GetCurrentThreadId <> MainThreadID then begin
      ToolResult := nil;
      ErrorText := '';
      BuildWaitMs := Round(McpJsonNumber(Arguments, 'buildWaitMs', 120000));
      if BuildWaitMs < 1000 then begin
         BuildWaitMs := 1000;
      end;
      MainThreadTimeoutMs := Cardinal(BuildWaitMs + 30000);
      Done := TEvent.Create(nil, true, false, '');
      try
         TThread.Queue(nil,
            procedure
            begin
               try
                  ToolResult := ToolBuildProject(Arguments);
               except
                  on E: Exception do begin
                     ErrorText := E.Message;
                  end;
               end;
               Done.SetEvent;
            end);
         if Done.WaitFor(MainThreadTimeoutMs) <> wrSignaled then begin
            raise Exception.CreateFmt('Timeout beim IDE-Build nach %d ms.', [MainThreadTimeoutMs]);
         end;
      finally
         Done.Free;
      end;

      if ErrorText <> '' then begin
         raise Exception.Create(ErrorText);
      end;
      result := ToolResult;
      exit;
   end;

   Project := ActiveProject;
   Builder := Project.GetProjectBuilder;
   if Builder = nil then begin
      raise Exception.Create('Aktives Projekt hat keinen IOTAProjectBuilder.');
   end;
   ModeText := McpJsonString(Arguments, 'mode', 'make');
   Wait := McpJsonBool(Arguments, 'wait', true);
   ClearMessages := McpJsonBool(Arguments, 'clearMessages', true);
   AllowSelfBuild := McpJsonBool(Arguments, 'allowSelfBuild', false);
   BuildWaitMs := Round(McpJsonNumber(Arguments, 'buildWaitMs', 120000));
   if BuildWaitMs < 1000 then begin
      BuildWaitMs := 1000;
   end;
   if IsSelfPackageProject(Project.FileName) and (not AllowSelfBuild) then begin
      result := TJSONObject.Create;
      TJSONObject(result).AddPair('success', McpBoolValue(false));
      TJSONObject(result).AddPair('blocked', McpBoolValue(true));
      TJSONObject(result).AddPair('reason',
         'Selbst-Build von MCP2Delphi im geladenen IDE-MCP-Server ist blockiert. Extern bauen oder allowSelfBuild=true setzen.');
      TJSONObject(result).AddPair('project', JsonProject(Project));
      exit;
   end;
   ClearCompileEvents;
   ProjectNotifier := nil;
   ProjectNotifierIndex := -1;
   ProgressCloser := nil;
   BuildStarter := nil;
   ClosedProgressDialogCount := 0;
   Ok := false;
   CompileFinished := false;
   WaitTimedOut := false;
   if Wait then begin
      ProjectNotifier := TMcpIdeProjectCompileNotifier.Create(Self, Project.FileName);
      ProjectNotifierIndex := Builder.AddCompileNotifier(ProjectNotifier);
      if ProjectNotifierIndex < 0 then begin
         ProjectNotifier := nil;
      end;
   end;
   try
      if Wait then begin
         ProgressCloser := TMcpBuildProgressCloser.Create;
         ProgressCloser.CloseFailedProgressDialogs;
         Application.ProcessMessages;
         ProgressCloser.Start;
      end;
      BuildStarter := TMcpIdeBuildStarter.Create(Builder, CompileModeFromText(ModeText), ClearMessages);
      BuildStarter.Start;
      if Wait then begin
         Deadline := GetTickCount64 + UInt64(BuildWaitMs);
         repeat
            Application.ProcessMessages;
            if (BuildStarter <> nil) and BuildStarter.Finished then begin
               Ok := BuildStarter.Ok;
               if BuildStarter.Error <> '' then begin
                  raise Exception.Create(BuildStarter.Error);
               end;
            end;
            if ProgressCloser <> nil then begin
               ProgressCloser.CloseFailedProgressDialogs;
            end;
            if FCompileEvents.Count > 0 then begin
               Event := FCompileEvents[FCompileEvents.Count - 1];
               CompileFinished := SameText(Event.EventName, 'project_group_compile_finished');
               if CompileFinished then begin
                  Ok := SameText(Event.ResultText, 'succeeded');
                  break;
               end;
             end;
             Sleep(50);
          until GetTickCount64 >= Deadline;
          WaitTimedOut := not CompileFinished;
          if WaitTimedOut then begin
             Ok := false;
          end;
      end
      else begin
         Application.ProcessMessages;
         Ok := (BuildStarter <> nil) and BuildStarter.Started;
      end;
   finally
      if BuildStarter <> nil then begin
         BuildStarter.Free;
      end;
      if ProgressCloser <> nil then begin
         ClosedProgressDialogCount := ProgressCloser.ClosedCount;
         ProgressCloser.Stop;
         ProgressCloser.Free;
      end;
      if ProjectNotifierIndex >= 0 then begin
         Builder.RemoveCompileNotifier(ProjectNotifierIndex);
      end;
      ProjectNotifier := nil;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('success', McpBoolValue(Ok));
   TJSONObject(result).AddPair('mode', ModeText);
   TJSONObject(result).AddPair('project', JsonProject(Project));
   TJSONObject(result).AddPair('projectCompileInfoAttached', McpBoolValue(ProjectNotifierIndex >= 0));
   if Wait then begin
      TJSONObject(result).AddPair('progressDialogsClosed', TJSONNumber.Create(ClosedProgressDialogCount));
      TJSONObject(result).AddPair('compileFinished', McpBoolValue(CompileFinished));
      TJSONObject(result).AddPair('waitTimedOut', McpBoolValue(WaitTimedOut));
      try
         BuildMessages := ToolGetBuildMessages(Arguments);
         TJSONObject(result).AddPair('buildMessagesAvailable', McpBoolValue(true));
         TJSONObject(result).AddPair('buildMessages', BuildMessages);
      except
         on E: Exception do begin
            TJSONObject(result).AddPair('buildMessagesAvailable', McpBoolValue(false));
            TJSONObject(result).AddPair('buildMessagesError', E.Message);
         end;
      end;
   end;
   TJSONObject(result).AddPair('compileEvents', JsonCompileEvents);
end;

function TMcpIdeBridge.ToolGetBuildEvents(const Arguments: TJSONObject): TJSONValue;
begin
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('compileEvents', JsonCompileEvents);
end;

function TMcpIdeBridge.ToolDebugStatus(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTADebuggerServices;
   Processes: TJSONArray;
   i: integer;
begin
   Services := DebuggerServices;
   Processes := TJSONArray.Create;
   for i := 0 to Services.ProcessCount - 1 do begin
      Processes.AddElement(JsonProcess(Services.Processes[i]));
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('processCount', TJSONNumber.Create(Services.ProcessCount));
   TJSONObject(result).AddPair('sourceBreakpointCount', TJSONNumber.Create(Services.SourceBkptCount));
   TJSONObject(result).AddPair('addressBreakpointCount', TJSONNumber.Create(Services.AddressBkptCount));
   TJSONObject(result).AddPair('currentProcess', JsonProcess(Services.CurrentProcess));
   TJSONObject(result).AddPair('processes', Processes);
end;

function TMcpIdeBridge.ToolListBreakpoints(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTADebuggerServices;
   Arr: TJSONArray;
   i: integer;
begin
   Services := DebuggerServices;
   Arr := TJSONArray.Create;
   for i := 0 to Services.SourceBkptCount - 1 do begin
      Arr.AddElement(JsonBreakpoint(Services.SourceBkpts[i]));
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('breakpoints', Arr);
end;

function TMcpIdeBridge.ToolInspectSourceLine(const Arguments: TJSONObject): TJSONValue;
var
   FileName: string;
   Line: integer;
begin
   FileName := ExpandFileName(McpJsonString(Arguments, 'fileName', ''));
   Line := Round(McpJsonNumber(Arguments, 'line', 0));
   if FileName = '' then begin
      raise Exception.Create('ide_inspect_source_line erwartet fileName.');
   end;
   if Line <= 0 then begin
      raise Exception.Create('ide_inspect_source_line erwartet line > 0.');
   end;

   result := JsonSourceLineInfo(FileName, Line);
end;

function TMcpIdeBridge.ToolAddSourceBreakpoint(const Arguments: TJSONObject): TJSONValue;
var
   FileName: string;
   Line: integer;
   Breakpoint: IOTABreakpoint;
begin
   FileName := ExpandFileName(McpJsonString(Arguments, 'fileName', ''));
   Line := Round(McpJsonNumber(Arguments, 'line', 0));
   if FileName = '' then begin
      raise Exception.Create('ide_add_source_breakpoint erwartet fileName.');
   end;
   if Line <= 0 then begin
      raise Exception.Create('ide_add_source_breakpoint erwartet line > 0.');
   end;

   Breakpoint := DebuggerServices.NewSourceBreakpoint(FileName, Line, nil);
   result := TJSONObject.Create;
   TJSONObject(result).AddPair('breakpoint', JsonBreakpoint(Breakpoint));
   TJSONObject(result).AddPair('sourceLine', JsonSourceLineInfo(FileName, Line));
   if Breakpoint.LineNumber <> Line then begin
      TJSONObject(result).AddPair('lineMismatchWarning',
         Format('Delphi meldet den Breakpoint auf Zeile %d statt der angefragten Zeile %d.',
         [Breakpoint.LineNumber, Line]));
   end;
end;

function TMcpIdeBridge.ToolRemoveSourceBreakpoint(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTADebuggerServices;
   FileName, BpFileName: string;
   Line, i: integer;
   Breakpoint: IOTABreakpoint;
   Removed: boolean;
begin
   Services := DebuggerServices;
   FileName := ExpandFileName(McpJsonString(Arguments, 'fileName', ''));
   Line := Round(McpJsonNumber(Arguments, 'line', 0));
   if FileName = '' then begin
      raise Exception.Create('ide_remove_source_breakpoint erwartet fileName.');
   end;
   if Line <= 0 then begin
      raise Exception.Create('ide_remove_source_breakpoint erwartet line > 0.');
   end;

   Removed := false;
   for i := Services.SourceBkptCount - 1 downto 0 do begin
      Breakpoint := Services.SourceBkpts[i];
      BpFileName := ExpandFileName(Breakpoint.FileName);
      if SameText(BpFileName, FileName) and (Breakpoint.LineNumber = Line) then begin
         Services.RemoveBreakpoint(Breakpoint);
         Removed := true;
      end;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('removed', McpBoolValue(Removed));
   TJSONObject(result).AddPair('fileName', FileName);
   TJSONObject(result).AddPair('line', TJSONNumber.Create(Line));
end;

function TMcpIdeBridge.ToolRunProgram(const Arguments: TJSONObject): TJSONValue;
begin
   EditActions.RunProgram;
   result := DebugCommandResult('run_program');
end;

function TMcpIdeBridge.ToolProgramReset(const Arguments: TJSONObject): TJSONValue;
begin
   EditActions.ProgramReset;
   result := DebugCommandResult('program_reset');
end;

function TMcpIdeBridge.ToolPauseProgram(const Arguments: TJSONObject): TJSONValue;
begin
   result := UnsupportedDebugCommandResult('pause_program',
      'IOTAEditActions in der lokalen ToolsAPI 23.0 bietet kein stabiles Pause-Kommando.');
end;

function TMcpIdeBridge.ToolGetDebugCallstack(const Arguments: TJSONObject): TJSONValue;
begin
   result := VclTreeTextByForm(
      'callstackwindow', '', '', 'callstacktree', 'virtual',
      false,
      Round(McpJsonNumber(Arguments, 'maxRows', 100)),
      Round(McpJsonNumber(Arguments, 'maxColumns', 8))
   );
end;

function TMcpIdeBridge.ToolGetDebugThreads(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTADebuggerServices;
   Process: IOTAProcess;
   CurrentThread: IOTAThread;
   Threads: TJSONArray;
   i, ThreadCount: integer;
begin
   Services := DebuggerServices;
   Process := Services.CurrentProcess;
   Threads := TJSONArray.Create;
   CurrentThread := nil;
   ThreadCount := 0;
   if Process <> nil then begin
      CurrentThread := Process.CurrentThread;
      ThreadCount := Process.ThreadCount;
      for i := 0 to ThreadCount - 1 do begin
         Threads.AddElement(JsonThread(Process.Threads[i], CurrentThread, i));
      end;
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('source', 'toolsapi');
   TJSONObject(result).AddPair('processAvailable', McpBoolValue(Process <> nil));
   TJSONObject(result).AddPair('process', JsonProcess(Process));
   TJSONObject(result).AddPair('threadCount', TJSONNumber.Create(ThreadCount));
   TJSONObject(result).AddPair('threads', Threads);
end;

function TMcpIdeBridge.ToolEvaluateExpression(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTADebuggerServices;
   Process: IOTAProcess;
   Thread: IOTAThread;
   Expression, FormatSpecifiers, FileName: string;
   Line: integer;
   AllowSideEffects, CanModify: boolean;
   ResultBuffer: array[0..4095] of Char;
   FormatBuffer: TBytes;
   FormatPtr: PAnsiChar;
   EvalResult: TOTAEvaluateResult;
   ResultAddr: TOTAAddress;
   ResultSize, ResultVal: LongWord;
begin
   Expression := McpJsonString(Arguments, 'expression', '');
   if Expression = '' then begin
      raise Exception.Create('debug_evaluate_expression erwartet expression.');
   end;

   Services := DebuggerServices;
   Process := Services.CurrentProcess;
   if Process = nil then begin
      raise Exception.Create('Es ist kein aktueller Debug-Prozess vorhanden.');
   end;
   Thread := Process.CurrentThread;
   if Thread = nil then begin
      raise Exception.Create('Es ist kein aktueller Debug-Thread vorhanden.');
   end;

   AllowSideEffects := McpJsonBool(Arguments, 'allowSideEffects', false);
   FormatSpecifiers := McpJsonString(Arguments, 'formatSpecifiers', '');
   FileName := McpJsonString(Arguments, 'fileName', '');
   Line := Round(McpJsonNumber(Arguments, 'line', 0));
   FormatPtr := nil;
   if FormatSpecifiers <> '' then begin
      FormatBuffer := TEncoding.ANSI.GetBytes(FormatSpecifiers + #0);
      FormatPtr := PAnsiChar(@FormatBuffer[0]);
   end;

   FillChar(ResultBuffer, SizeOf(ResultBuffer), 0);
   ResultAddr := 0;
   ResultSize := 0;
   ResultVal := 0;
   CanModify := false;
   if (FileName <> '') and (Line > 0) then begin
      EvalResult := Thread.Evaluate(Expression, @ResultBuffer[0], Length(ResultBuffer), CanModify,
         eseNone, FormatPtr, ResultAddr, ResultSize, ResultVal, FileName, Line);
   end
   else begin
      EvalResult := Thread.Evaluate(Expression, @ResultBuffer[0], Length(ResultBuffer), CanModify,
         AllowSideEffects, FormatPtr, ResultAddr, ResultSize, ResultVal);
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('expression', Expression);
   TJSONObject(result).AddPair('result', string(ResultBuffer));
   TJSONObject(result).AddPair('evaluateResult', TJSONNumber.Create(Ord(EvalResult)));
   TJSONObject(result).AddPair('evaluateResultName', GetEnumName(TypeInfo(TOTAEvaluateResult), Ord(EvalResult)));
   TJSONObject(result).AddPair('success', McpBoolValue(EvalResult = erOK));
   TJSONObject(result).AddPair('canModify', McpBoolValue(CanModify));
   TJSONObject(result).AddPair('allowSideEffects', McpBoolValue(AllowSideEffects));
   TJSONObject(result).AddPair('formatSpecifiers', FormatSpecifiers);
   TJSONObject(result).AddPair('resultAddress', TJSONNumber.Create(ResultAddr));
   TJSONObject(result).AddPair('resultSize', TJSONNumber.Create(ResultSize));
   TJSONObject(result).AddPair('resultValue', TJSONNumber.Create(ResultVal));
   TJSONObject(result).AddPair('thread', JsonThread(Thread, Thread, -1));
   if FileName <> '' then begin
      TJSONObject(result).AddPair('scopeFileName', FileName);
      TJSONObject(result).AddPair('scopeLine', TJSONNumber.Create(Line));
   end;
end;

function TMcpIdeBridge.ToolGetCurrentSourceLocation(const Arguments: TJSONObject): TJSONValue;
var
   Services: IOTADebuggerServices;
   Process: IOTAProcess;
   Thread: IOTAThread;
   FileName, SourceText: string;
   Line, CallCount: integer;
   StackState: TOTACallStackState;
begin
   Services := DebuggerServices;
   Process := Services.CurrentProcess;
   Thread := nil;
   FileName := '';
   Line := 0;
   StackState := csInaccessible;
   if Process <> nil then begin
      Thread := Process.CurrentThread;
   end;
   if Thread <> nil then begin
      try
         FileName := Thread.CurrentFile;
         Line := Thread.CurrentLine;
      except
         FileName := '';
         Line := 0;
      end;

      if (FileName = '') or (Line <= 0) then begin
         try
            StackState := Thread.StartCallStackAccess;
            if StackState = csAccessible then begin
               CallCount := Thread.CallCount;
               if CallCount > 0 then begin
                  Thread.GetCallPos(1, FileName, Line);
               end;
            end;
         finally
            try
               Thread.EndCallStackAccess;
            except
            end;
         end;
      end;
   end;

   if (FileName <> '') and (Line > 0) then begin
      SourceText := 'toolsapi';
   end
   else begin
      SourceText := 'none';
   end;

   result := TJSONObject.Create;
   TJSONObject(result).AddPair('processAvailable', McpBoolValue(Process <> nil));
   TJSONObject(result).AddPair('threadAvailable', McpBoolValue(Thread <> nil));
   TJSONObject(result).AddPair('available', McpBoolValue((FileName <> '') and (Line > 0)));
   TJSONObject(result).AddPair('fileName', FileName);
   TJSONObject(result).AddPair('line', TJSONNumber.Create(Line));
   TJSONObject(result).AddPair('source', SourceText);
   TJSONObject(result).AddPair('callStackState', GetEnumName(TypeInfo(TOTACallStackState), Ord(StackState)));
   TJSONObject(result).AddPair('thread', JsonThread(Thread, Thread, -1));
end;

function TMcpIdeBridge.ToolStepOut(const Arguments: TJSONObject): TJSONValue;
begin
   result := UnsupportedDebugCommandResult('step_out',
      'IOTAEditActions in der lokalen ToolsAPI 23.0 bietet kein stabiles Step-Out-Kommando.');
end;

function TMcpIdeBridge.ToolStepOver(const Arguments: TJSONObject): TJSONValue;
begin
   EditActions.StepOver;
   result := DebugCommandResult('step_over');
end;

function TMcpIdeBridge.ToolTraceInto(const Arguments: TJSONObject): TJSONValue;
begin
   EditActions.TraceInto;
   result := DebugCommandResult('trace_into');
end;

function TMcpIdeBridge.ToolRunToCursor(const Arguments: TJSONObject): TJSONValue;
begin
   EditActions.RunToCursor;
   result := DebugCommandResult('run_to_cursor');
end;

initialization

finalization
   UnregisterIdeMcpBridge;

end.
