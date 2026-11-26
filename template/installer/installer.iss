[Setup]
AppId={{#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={code:GetPfDir}\{#MyAppName}

OutputBaseFilename={#MyAppName}_Setup_{#MyAppVersion}
OutputDir=..
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AppPublisher={#MyAppPublisher}
PrivilegesRequired=none
PrivilegesRequiredOverridesAllowed=dialog
DisableDirPage=no
DisableProgramGroupPage=yes
Compression=lzma
SolidCompression=yes

LicenseFile=..\LICENSE
WizardStyle=modern

[Files]
; TEMPLATE: Adjust the source paths to match your project's executables and assets.
Source: "..\{#MyAppName}_gui.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\{#MyExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Assets\*"; DestDir: "{app}\Assets"; Flags: ignoreversion
Source: "..\config\*.ini"; DestDir: "{app}\config"; Flags: ignoreversion
Source: "..\config\*.json"; DestDir: "{app}\config"; Flags: ignoreversion
Source: "..\config\*.txt"; DestDir: "{app}\config"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\CONTRIBUTING.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\NAME"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; TEMPLATE: Adjust the program group name.
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppName}_gui.exe"
Name: "{group}\{#MyAppName} CLI"; Filename: "{app}\{#MyExeName}"

[Run]
Filename: "{app}\README.md"; Description: "View README"; Flags: postinstall shellexec skipifsilent unchecked

[Code]
{ Uninstall any previous version (same AppId) before installing. }
function InitializeSetup(): Boolean;
var
  RegKey: String;
  UninstallPath: String;
  ResultCode: Integer;
begin
  Result := True;
  RegKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + ExpandConstant('{#SetupSetting("AppId")}') + '_is1';
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, RegKey, 'UninstallString', UninstallPath) then
    RegQueryStringValue(HKEY_CURRENT_USER, RegKey, 'UninstallString', UninstallPath);
  if UninstallPath <> '' then
  begin
    UninstallPath := RemoveQuotes(UninstallPath);
    Exec(UninstallPath, '/SILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(1000);
  end;
end;
procedure CurStepChanged(CurStep: TSetupStep);
var
  ReadmeLines: TArrayOfString;
begin
  if CurStep = ssPostInstall then
  begin
    SetArrayLength(ReadmeLines, 14);
    ReadmeLines[0]  := '==================================================';
    ReadmeLines[1]  := ' ' + ExpandConstant('{#MyAppName}') + ' v' + ExpandConstant('{#MyAppVersion}') ;
    ReadmeLines[2]  := '==================================================';
    ReadmeLines[3]  := '';
    ReadmeLines[4]  := 'Thank you for installing this software!';
    ReadmeLines[5]  := '';
    ReadmeLines[11] := 'INSTALLATION PATH:';
    ReadmeLines[12] := ExpandConstant('{app}');
    ReadmeLines[13] := '';
    SuppressibleMsgBox(
      string.Join(#13#10, ReadmeLines),
      mbInformation,
      MB_OK,
      IDOK
    );
  end;
end;

function GetPfDir(S: String): String;
begin
  if IsWin64 then
    Result := ExpandConstant('{pf64}')
  else
    Result := ExpandConstant('{pf32}');
end;