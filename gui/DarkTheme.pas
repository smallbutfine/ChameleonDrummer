unit DarkTheme;

{$mode objfpc}{$H+}

{ Dark mode for the GUI.

  The LCL of Lazarus 4.4 has no dark mode on Windows, so this unit does what
  Windows' own dark apps do:

    * every control gets dark colours (form, labels, edits, lists, the log);
    * the native controls (buttons, combo boxes, spin buttons, scroll bars,
      track bars) get Windows' dark control theme, picked by window class, so
      controls the LCL creates later are covered too (ThemeControlTree);
    * the title bar is switched to dark (DWM immersive dark mode);
    * the menus are drawn here: the LCL makes every item owner-drawn and asks
      TMenu.OnDrawItem, so the bar and the drop-downs get dark items, and the
      empty strip of the bar is painted from the form's WM_NCPAINT;
    * uxtheme's preferred app mode is set to dark.

  The choice is system (follow Windows, also while the program runs), light
  or dark. It is kept in %APPDATA%\ChameleonDrummer\gui.ini. Everything is
  looked up at run time, so on a Windows without these features the program
  simply stays light. }

interface

{$IFDEF MSWINDOWS}
  Windows;
{$ENDIF}

uses
  Classes, SysUtils, LCLType, Controls, Forms, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  Spin, Menus, IniFiles, Registry;

type
  TThemeChoice = (tcSystem, tcLight, tcDark);

const
  { Dark palette, as the user sees it. }
  DARK_FORM = $202020;       { window background }
  DARK_PANEL = $2B2B2B;      { edits, lists, the log }
  DARK_TEXT = $E6E6E6;
  DARK_DISABLED = $808080;
  DARK_BORDER = $4A4A4A;
  DARK_HOT = $3C3C3C;        { menu item under the mouse }

function ThemeChoiceFromText(const AText: string): TThemeChoice;
function ThemeChoiceName(AChoice: TThemeChoice): string;

{ True when Windows is set to dark apps (Settings > Colors). }
function SystemUsesDarkApps: Boolean;

{ The choice made last time ('system' on the first run). }
function LoadThemeChoice: TThemeChoice;
procedure SaveThemeChoice(AChoice: TThemeChoice);

{ AChoice as light or dark. }
function ResolveDark(AChoice: TThemeChoice): Boolean;

{ Sets how Windows draws menus and common controls for this program. Call it
  before the first window is created and again when the theme changes. }
procedure SetAppDarkMode(ADark: Boolean);

{ Dresses AForm: colours, native control themes, title bar, menu bar. }
procedure ApplyTheme(AForm: TCustomForm; ADark: Boolean);

{ Dresses a control and everything inside it - for controls made after
  ApplyTheme (the section list). }
procedure ThemeControlTree(ARoot: TControl; ADark: Boolean);

var
  { Called when Windows switches between light and dark apps while the program
    runs (only the form that was given to ApplyTheme reports it). }
  OnSystemThemeChange: TNotifyEvent = nil;

implementation

{$IFDEF MSWINDOWS}

const
  OBJID_MENU = LONG($FFFFFFFD);
  PROP_OLD_PROC = 'ChameleonDrummerOldProc';
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;

type
  TSetPreferredAppMode = function(AMode: Integer): Integer; stdcall;
  TFlushMenuThemes = procedure; stdcall;
  TAllowDarkModeForWindow = function(AWnd: HWND; AAllow: BOOL): BOOL; stdcall;
  TDwmSetWindowAttribute = function(AWnd: HWND; AAttr: DWORD; AValue: Pointer;
    ASize: DWORD): HRESULT; stdcall;

  TMenuBarInfoRec = record
    cbSize: DWORD;
    rcBar: TRect;
    hMenu: HMENU;
    hwndMenu: HWND;
    Flags: DWORD;        { fBarFocused, fFocused bits }
  end;

function SetWindowTheme(AWnd: HWND; ASubAppName, ASubIdList: PWideChar): HRESULT;
  stdcall; external 'uxtheme.dll';
function GetMenuBarInfoRec(AWnd: HWND; AObject, AItem: LONG;
  var AInfo: TMenuBarInfoRec): BOOL; stdcall; external 'user32.dll' name 'GetMenuBarInfo';

var
  GUxTheme, GDwmApi: HMODULE;
  GSetPreferredAppMode: TSetPreferredAppMode;
  GFlushMenuThemes: TFlushMenuThemes;
  GAllowDarkModeForWindow: TAllowDarkModeForWindow;
  GDwmSetWindowAttribute: TDwmSetWindowAttribute;
  GBarBrush, GHotBrush: HBRUSH;
  GDark: Boolean = False;
  GFormWnd: HWND = 0;

type
  { Window classes of the native controls, and the dark theme each one gets. }
  TThemeKind = (tkNone, tkExplorer, tkCFD);

{ ---- settings ----------------------------------------------------------- }

function ThemeChoiceFromText(const AText: string): TThemeChoice;
begin
  case LowerCase(Trim(AText)) of
    'dark': Result := tcDark;
    'light': Result := tcLight;
  else
    Result := tcSystem;
  end;
end;

function ThemeChoiceName(AChoice: TThemeChoice): string;
begin
  case AChoice of
    tcDark: Result := 'dark';
    tcLight: Result := 'light';
  else
    Result := 'system';
  end;
end;

function SettingsPath: string;
begin
  Result := SysUtils.GetEnvironmentVariable('APPDATA');
  if Result = '' then
    Result := GetUserDir;
  Result := IncludeTrailingPathDelimiter(Result) + 'ChameleonDrummer' + PathDelim + 'gui.ini';
end;

function LoadThemeChoice: TThemeChoice;
var
  Ini: TIniFile;
begin
  Result := tcSystem;
  if not FileExists(SettingsPath) then
    Exit;
  try
    Ini := TIniFile.Create(SettingsPath);
    try
      Result := ThemeChoiceFromText(Ini.ReadString('ui', 'theme', 'system'));
    finally
      Ini.Free;
    end;
  except
    Result := tcSystem;
  end;
end;

procedure SaveThemeChoice(AChoice: TThemeChoice);
var
  Ini: TIniFile;
begin
  try
    ForceDirectories(ExtractFilePath(SettingsPath));
    Ini := TIniFile.Create(SettingsPath);
    try
      Ini.WriteString('ui', 'theme', ThemeChoiceName(AChoice));
    finally
      Ini.Free;
    end;
  except
    { a read-only profile must not stop the program }
  end;
end;

function SystemUsesDarkApps: Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') then
    begin
      if Reg.ValueExists('AppsUseLightTheme') then
        Result := Reg.ReadInteger('AppsUseLightTheme') = 0;
      Reg.CloseKey;
    end;
  except
    Result := False;
  end;
  Reg.Free;
end;

function ResolveDark(AChoice: TThemeChoice): Boolean;
begin
  case AChoice of
    tcDark: Result := True;
    tcLight: Result := False;
  else
    Result := SystemUsesDarkApps;
  end;
end;

{ ---- Windows' dark mode ------------------------------------------------- }

procedure LoadApis;
begin
  if GUxTheme = 0 then
  begin
    GUxTheme := LoadLibrary('uxtheme.dll');
    if GUxTheme <> 0 then
    begin
      { uxtheme exports these by ordinal only. }
      GSetPreferredAppMode := TSetPreferredAppMode(GetProcAddress(GUxTheme, PChar(PtrUInt(135))));
      GFlushMenuThemes := TFlushMenuThemes(GetProcAddress(GUxTheme, PChar(PtrUInt(136))));
      GAllowDarkModeForWindow := TAllowDarkModeForWindow(GetProcAddress(GUxTheme, PChar(PtrUInt(133))));
    end;
  end;
  if GDwmApi = 0 then
  begin
    GDwmApi := LoadLibrary('dwmapi.dll');
    if GDwmApi <> 0 then
      GDwmSetWindowAttribute := TDwmSetWindowAttribute(GetProcAddress(GDwmApi, 'DwmSetWindowAttribute'));
  end;
end;

procedure SetAppDarkMode(ADark: Boolean);
const
  APPMODE_DEFAULT = 0;
  APPMODE_FORCE_DARK = 2;
  APPMODE_FORCE_LIGHT = 3;
begin
  LoadApis;
  if Assigned(GSetPreferredAppMode) then
  begin
    if ADark then
      GSetPreferredAppMode(APPMODE_FORCE_DARK)
    else
      GSetPreferredAppMode(APPMODE_FORCE_LIGHT);
  end;
  if Assigned(GFlushMenuThemes) then
    GFlushMenuThemes;
end;

procedure SetTitleBarDark(AWnd: HWND; ADark: Boolean);
var
  Value: BOOL;
begin
  if (AWnd = 0) or not Assigned(GDwmSetWindowAttribute) then
    Exit;
  Value := ADark;
  if GDwmSetWindowAttribute(AWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @Value, SizeOf(Value)) <> 0 then
    GDwmSetWindowAttribute(AWnd, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, @Value, SizeOf(Value));
end;

{ ---- native controls ---------------------------------------------------- }

function ThemeKindOfClass(const AClass: string): TThemeKind;
begin
  case LowerCase(AClass) of
    'button', 'scrollbar', 'msctls_updown32', 'msctls_trackbar32',
    'msctls_progress32', 'systabcontrol32', 'syslistview32', 'systreeview32',
    'listbox':
      Result := tkExplorer;
    'edit', 'combobox', 'comboboxex32':
      Result := tkCFD;
  else
    Result := tkNone;
  end;
end;

function EnumChildProc(AWnd: HWND; AParam: LPARAM): BOOL; stdcall;
var
  ClassName: array[0..63] of Char;
  Kind: TThemeKind;
begin
  Result := True;
  GetClassName(AWnd, @ClassName[0], Length(ClassName));
  Kind := ThemeKindOfClass(ClassName);
  if Kind = tkNone then
    Exit;
  if Assigned(GAllowDarkModeForWindow) then
    GAllowDarkModeForWindow(AWnd, AParam <> 0);
  if AParam <> 0 then
  begin
    if Kind = tkCFD then
      SetWindowTheme(AWnd, PWideChar(UnicodeString('DarkMode_CFD')), nil)
    else
      SetWindowTheme(AWnd, PWideChar(UnicodeString('DarkMode_Explorer')), nil);
  end
  else
    SetWindowTheme(AWnd, nil, nil);
  SendMessage(AWnd, WM_THEMECHANGED, 0, 0);
  InvalidateRect(AWnd, nil, True);
end;

procedure ThemeNativeWindows(ARoot: HWND; ADark: Boolean);
begin
  if ARoot = 0 then
    Exit;
  LoadApis;
  EnumChildProc(ARoot, LPARAM(Ord(ADark)));
  EnumChildWindows(ARoot, @EnumChildProc, LPARAM(Ord(ADark)));
end;

{ ---- LCL colours -------------------------------------------------------- }

type
  TControlAccess = class(TControl);

procedure ColorOne(AControl: TControl; ADark: Boolean);
var
  Access: TControlAccess;
begin
  Access := TControlAccess(AControl);
  if ADark then
  begin
    if (AControl is TCustomEdit) or (AControl is TCustomComboBox) or
       (AControl is TCustomFloatSpinEdit) or (AControl is TCustomListBox) then
    begin
      Access.Color := DARK_PANEL;
      Access.Font.Color := DARK_TEXT;
    end
    else if (AControl is TCustomLabel) then
    begin
      { a label is transparent: only its text colour matters }
      Access.Font.Color := DARK_TEXT;
    end
    else if (AControl is TCustomGroupBox) or (AControl is TCustomCheckBox) or
            (AControl is TRadioButton) or (AControl is TCustomPanel) then
    begin
      Access.Color := DARK_FORM;
      Access.Font.Color := DARK_TEXT;
    end
    else if (AControl is TCustomTrackBar) or (AControl is TProgressBar) then
      Access.Color := DARK_FORM
    else if not (AControl is TButtonControl) then
      Access.Font.Color := DARK_TEXT;
  end
  else
  begin
    { back to the system colours }
    if (AControl is TCustomEdit) or (AControl is TCustomComboBox) or
       (AControl is TCustomFloatSpinEdit) or (AControl is TCustomListBox) then
    begin
      Access.Color := clWindow;
      Access.Font.Color := clWindowText;
    end
    else if (AControl is TCustomLabel) then
      Access.Font.Color := clWindowText
    else if (AControl is TCustomGroupBox) or (AControl is TCustomCheckBox) or
            (AControl is TRadioButton) or (AControl is TCustomPanel) then
    begin
      Access.Color := clBtnFace;
      Access.Font.Color := clWindowText;
    end
    else if (AControl is TCustomTrackBar) or (AControl is TProgressBar) then
      Access.Color := clBtnFace
    else if not (AControl is TButtonControl) then
      Access.Font.Color := clWindowText;
  end;
end;

procedure ColorTree(ARoot: TControl; ADark: Boolean);
var
  I: Integer;
begin
  ColorOne(ARoot, ADark);
  if ARoot is TWinControl then
    for I := 0 to TWinControl(ARoot).ControlCount - 1 do
      ColorTree(TWinControl(ARoot).Controls[I], ADark);
end;

procedure ThemeControlTree(ARoot: TControl; ADark: Boolean);
begin
  if ARoot = nil then
    Exit;
  ColorTree(ARoot, ADark);
  if ARoot is TWinControl then
  begin
    TWinControl(ARoot).HandleNeeded;
    ThemeNativeWindows(TWinControl(ARoot).Handle, ADark);
  end;
end;

{ ---- the menu bar and the menus --------------------------------------------- }

{ The LCL turns every menu item into an owner-drawn one, so Windows paints
  nothing of the items itself; the LCL calls TMenu.OnDrawItem for each, and
  while that event is set it draws nothing else. The handler below draws the
  dark items (bar and drop-down). What it cannot reach is the empty strip of
  the bar right of the last item and the line under it: NCPaintMenuBar paints
  those. }

type
  { OnDrawItem is a method, so the handler needs an object to live in. }
  TMenuPainter = class
    procedure DrawItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect;
      AState: LCLType.TOwnerDrawState);
  end;

var
  GMenuPainter: TMenuPainter;

procedure TMenuPainter.DrawItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect;
  AState: LCLType.TOwnerDrawState);
var
  Item: TMenuItem;
  Back, Fore: TColor;
  Text: UnicodeString;
  Flags: UINT;
  Mark: TRect;
  Cx, Cy: Integer;
begin
  Item := Sender as TMenuItem;
  if (LCLType.odSelected in AState) or (LCLType.odHotLight in AState) then
    Back := DARK_HOT
  else
    Back := DARK_FORM;
  if (LCLType.odGrayed in AState) or (LCLType.odDisabled in AState) or not Item.Enabled then
    Fore := DARK_DISABLED
  else
    Fore := DARK_TEXT;

  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := Back;
  ACanvas.FillRect(ARect);

  if Item.Caption = '-' then
  begin
    ACanvas.Pen.Color := DARK_BORDER;
    Cy := (ARect.Top + ARect.Bottom) div 2;
    ACanvas.Line(ARect.Left + 4, Cy, ARect.Right - 4, Cy);
    Exit;
  end;

  SetBkMode(ACanvas.Handle, TRANSPARENT);
  SetTextColor(ACanvas.Handle, ColorToRGB(Fore));
  Text := UTF8Decode(Item.Caption);
  Flags := DT_SINGLELINE or DT_VCENTER;
  if LCLType.odNoAccel in AState then
    Flags := Flags or DT_HIDEPREFIX;
  Mark := ARect;
  if Item.IsInMenuBar then
    Flags := Flags or DT_CENTER
  else
  begin
    { room for the check / radio mark on the left }
    Mark.Right := Mark.Left + 24;
    Inc(ARect.Left, 28);
    Flags := Flags or DT_LEFT;
  end;
  DrawTextW(ACanvas.Handle, PWideChar(Text), Length(Text), ARect, Flags);

  if (not Item.IsInMenuBar) and Item.Checked then
  begin
    Cx := (Mark.Left + Mark.Right) div 2;
    Cy := (Mark.Top + Mark.Bottom) div 2;
    ACanvas.Pen.Color := Fore;
    ACanvas.Brush.Color := Fore;
    if Item.RadioItem then
      ACanvas.Ellipse(Cx - 3, Cy - 3, Cx + 4, Cy + 4)
    else
    begin
      ACanvas.Pen.Width := 2;
      ACanvas.MoveTo(Cx - 4, Cy);
      ACanvas.LineTo(Cx - 1, Cy + 3);
      ACanvas.LineTo(Cx + 4, Cy - 3);
      ACanvas.Pen.Width := 1;
    end;
  end;
end;

procedure SetMenuDark(AMenu: TMenu; ADark: Boolean);
begin
  if AMenu = nil then
    Exit;
  { With no handler the LCL draws the menu itself, in the system colours. }
  if ADark then
  begin
    if GMenuPainter = nil then
      GMenuPainter := TMenuPainter.Create;
    AMenu.OnDrawItem := @GMenuPainter.DrawItem;
  end
  else
    AMenu.OnDrawItem := nil;
end;

{ Paints the part of the menu bar no item covers, and the line under it. }
procedure NCPaintMenuBar(AWnd: HWND);
var
  Info: TMenuBarInfoRec;
  Win, Bar, Item: TRect;
  DC: HDC;
  I, Count: Integer;
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  if not GetMenuBarInfoRec(AWnd, OBJID_MENU, 0, Info) then
    Exit;
  GetWindowRect(AWnd, Win);
  Bar := Info.rcBar;
  OffsetRect(Bar, -Win.Left, -Win.Top);
  DC := GetWindowDC(AWnd);
  try
    { keep the items: they are drawn by DarkDrawMenuItem }
    Count := GetMenuItemCount(Info.hMenu);
    for I := 0 to Count - 1 do
      if GetMenuItemRect(AWnd, Info.hMenu, I, @Item) then
      begin
        OffsetRect(Item, -Win.Left, -Win.Top);
        ExcludeClipRect(DC, Item.Left, Item.Top, Item.Right, Item.Bottom);
      end;
    FillRect(DC, Bar, GBarBrush);
    SelectClipRgn(DC, 0);
    { the line Windows draws under the bar }
    Item := Bar;
    Item.Top := Bar.Bottom;
    Item.Bottom := Bar.Bottom + 1;
    FillRect(DC, Item, GBarBrush);
  finally
    ReleaseDC(AWnd, DC);
  end;
end;

function ThemeWndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  Old: WNDPROC;
begin
  Old := WNDPROC(GetProp(AWnd, PROP_OLD_PROC));
  Result := 0;
  if GDark and ((AMsg = WM_NCPAINT) or (AMsg = WM_NCACTIVATE)) then
  begin
    Result := CallWindowProc(Old, AWnd, AMsg, AWParam, ALParam);
    NCPaintMenuBar(AWnd);
    Exit;
  end;
  if (AMsg = WM_SETTINGCHANGE) and (ALParam <> 0) and Assigned(OnSystemThemeChange) then
    if WideCharToString(PWideChar(ALParam)) = 'ImmersiveColorSet' then
      PostMessage(AWnd, WM_APP + 77, 0, 0);
  if (AMsg = WM_APP + 77) and Assigned(OnSystemThemeChange) then
  begin
    OnSystemThemeChange(nil);
    Exit(0);
  end;
  Result := CallWindowProc(Old, AWnd, AMsg, AWParam, ALParam);
end;

procedure HookForm(AWnd: HWND);
begin
  if GetProp(AWnd, PROP_OLD_PROC) <> 0 then
    Exit;
  SetProp(AWnd, PROP_OLD_PROC, THandle(SetWindowLongPtr(AWnd, GWLP_WNDPROC, PtrInt(@ThemeWndProc))));
end;

{ ---- the form ----------------------------------------------------------- }

procedure ApplyTheme(AForm: TCustomForm; ADark: Boolean);
begin
  LoadApis;
  GDark := ADark;
  if GBarBrush <> 0 then DeleteObject(GBarBrush);
  if GHotBrush <> 0 then DeleteObject(GHotBrush);
  GBarBrush := CreateSolidBrush(DARK_FORM);
  GHotBrush := CreateSolidBrush(DARK_HOT);

  SetAppDarkMode(ADark);
  AForm.HandleNeeded;
  GFormWnd := AForm.Handle;
  HookForm(AForm.Handle);

  if ADark then
    AForm.Color := DARK_FORM
  else
    AForm.Color := clBtnFace;
  ThemeControlTree(AForm, ADark);
  SetTitleBarDark(AForm.Handle, ADark);
  SetMenuDark(AForm.Menu, ADark);
  if Assigned(GAllowDarkModeForWindow) then
    GAllowDarkModeForWindow(AForm.Handle, ADark);

  { make Windows repaint the menu bar and the frame with the new colours }
  DrawMenuBar(AForm.Handle);
  SetWindowPos(AForm.Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or
    SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED);
  RedrawWindow(AForm.Handle, nil, 0, RDW_INVALIDATE or RDW_ALLCHILDREN or
    RDW_FRAME or RDW_UPDATENOW);
end;

initialization
  { Windows reads the app mode when the first window is made, so it is set
    here, before the form exists. }
  SetAppDarkMode(ResolveDark(LoadThemeChoice));

finalization
  GMenuPainter.Free;
  if GBarBrush <> 0 then DeleteObject(GBarBrush);
  if GHotBrush <> 0 then DeleteObject(GHotBrush);
{$ENDIF}
end.
