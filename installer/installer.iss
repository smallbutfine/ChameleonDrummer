[Setup]
AppId={{#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={code:GetPfDir}\{#MyAppName}

; ANPASSUNG: Die Setup.exe soll wieder ganz vorne im Hauptverzeichnis landen
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

; ANPASSUNG: Verweist auf den assets-Ordner eine Ebene weiter oben
LicenseFile=..\assets\LICENSE.txt
WizardStyle=modern

[Files]
; ANPASSUNG: Alle Source-Pfade holen sich die Dateien aus den neuen Unterordnern (..\)
Source: "..\{#MyExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\mappings\*.json"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{app}\Readme.txt"; Description: "View Readme (How to use in DAW)"; Flags: postinstall shellexec skipifsilent unchecked

[Code]
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

    SaveStringsToFile(ExpandConstant('{app}\Readme.txt'), ReadmeLines, False);
  end;
end;

function GetPfDir(Param: String): String;
begin
  if IsAdminInstallMode then
    // ERZWINGT den echten 64-Bit-Ordner (C:\Program Files\Common Files), selbst ohne Admin-Rechte
    Result := ExpandConstant('{commonpf64}')
  else
    Result := ExpandConstant('{userappdata}');
end;

function InitializeSetup(): Boolean;
var
  RegKey: String;
  UninstallPath: String;
  ResultCode: Integer;
begin
  Result := True;
  RegKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + ExpandConstant('{#SetupSetting("AppId")}') + '_is1';

  // KORREKTUR: Wir prüfen die Existenz direkt über RegQueryStringValue
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, RegKey, 'UninstallString', UninstallPath) then
  begin
    RegQueryStringValue(HKEY_CURRENT_USER, RegKey, 'UninstallString', UninstallPath);
  end;

  if UninstallPath <> '' then
  begin
    UninstallPath := RemoveQuotes(UninstallPath);
    Exec(UninstallPath, '/SILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(1000);
  end;
end;
