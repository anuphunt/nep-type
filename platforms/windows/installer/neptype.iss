#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef AppNumericVersion
  #error AppNumericVersion is required
#endif

[Setup]
; New machine-wide identity; the older per-user pad keeps its own uninstaller.
AppId={{36AC730E-43BC-4D6B-B6BB-38F712E24BF7}
AppName=NepType
AppVersion={#AppVersion}
VersionInfoVersion={#AppNumericVersion}
AppPublisher=NepType
AppPublisherURL=https://neptype.com
AppSupportURL=https://github.com/anuphunt/nep-type/issues
AppUpdatesURL=https://neptype.com/windows/
DefaultDirName={autopf}\NepType
UsePreviousAppDir=yes
DefaultGroupName=NepType
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=NepType-{#AppVersion}-windows-x64-setup
SetupIconFile=..\neptype.ico
UninstallDisplayIcon={app}\NepType.exe
LicenseFile={#PayloadDir}\LICENSE.txt
InfoBeforeFile=preview.txt
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
RestartApplications=no
SetupMutex=Global\NepType.Installer

[Files]
Source: "{#PayloadDir}\NepType.exe"; DestDir: "{app}"; Flags: ignoreversion restartreplace uninsrestartdelete
Source: "{#PayloadDir}\NepTypeEngine.dll"; DestDir: "{app}"; Flags: ignoreversion restartreplace uninsrestartdelete
Source: "{#PayloadDir}\keyboard\NepTypeTsf.dll"; DestDir: "{app}\keyboard-payload"; Flags: ignoreversion
Source: "{#PayloadDir}\keyboard\NepTypeEngine.dll"; DestDir: "{app}\keyboard-payload"; Flags: ignoreversion
Source: "{#PayloadDir}\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\dictionaries\*"; DestDir: "{app}\dictionaries"; Flags: ignoreversion recursesubdirs createallsubdirs
; Run registration inside file installation so an exception rolls back app files.
Source: "{#PayloadDir}\NepTypeKeyboardSetup.exe"; DestDir: "{app}"; Flags: ignoreversion uninsrestartdelete; AfterInstall: BeginKeyboard

[Icons]
Name: "{autoprograms}\NepType"; Filename: "{app}\NepType.exe"; WorkingDir: "{app}"

[Tasks]
Name: enableaccount; Description: "Make the NepType keyboard available for my Windows account (keeps my default keyboard)"; Check: IsFreshKeyboard

[Run]
Filename: "{app}\NepType.exe"; Description: "Open NepType"; Flags: nowait postinstall skipifsilent unchecked

[Code]
const
  LegacyUninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{5E4BC5AE-0272-4601-9D59-3018815A456C}_is1';
  KeyboardRegistry = 'Software\Classes\CLSID\{B6A68F96-5819-4B7F-8569-A11590D12001}\InprocServer32';
var
  KeyboardPending, KeyboardWasRegistered, KeyboardRestart, SetupFailed: Boolean;
  KeyboardToken, TemporaryHelper, RollbackHelper: String;

function IsFreshKeyboard: Boolean;
begin
  Result := not KeyboardWasRegistered;
end;

function InitializeSetup: Boolean;
begin
  KeyboardWasRegistered := RegKeyExists(HKLM64, KeyboardRegistry);
  Result := True;
end;

function RunHelper(const Helper, Parameters: String; var Code: Integer): Boolean;
begin
  Code := -1;
  Result := Exec(Helper, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code);
  Log(Format('Keyboard helper: %s; exit %d', [Parameters, Code]));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Code: Integer;
begin
  Result := '';
  if RegKeyExists(HKCU, LegacyUninstallKey) then begin
    Result := 'An older per-user NepType typing pad is installed. Remove that copy through Windows Settings > Apps first, then run this installer again. Your draft and spelling preferences are kept in your user account. The new installer will not run a user-writable uninstaller with administrator rights.';
    Exit;
  end;
  ExtractTemporaryFile('NepTypeKeyboardSetup.exe');
  TemporaryHelper := ExpandConstant('{tmp}\NepTypeKeyboardSetup.exe');
  if not RunHelper(TemporaryHelper, 'probe ' + AddQuotes(ExpandConstant('{app}')), Code) or (Code <> 0) then
    Result := 'Keyboard setup cannot continue. Use native Windows x64 and a protected Program Files installation, and repair any conflicting keyboard registration first.';
  KeyboardWasRegistered := RegKeyExists(HKLM64, KeyboardRegistry);
end;

procedure BeginKeyboard;
var Code: Integer; Target: String;
begin
  SetupFailed := True;
  KeyboardToken := GetSHA256OfUnicodeString(ExpandConstant('{tmp}') + GetDateTimeString('yyyymmddhhnnsszzz', '-', ':'));
  KeyboardPending := True;
  if not RunHelper(ExpandConstant('{app}\NepTypeKeyboardSetup.exe'),
    'begin ' + AddQuotes(ExpandConstant('{app}\keyboard-payload')) + ' "{#AppVersion}" ' + KeyboardToken, Code) or (Code <> 0) then
    RaiseException('Keyboard setup failed. The previous registration will be restored where possible; existing keyboard DLL folders are retained.');
  Target := GetIniString('setup', 'Target', '', ExpandConstant('{autopf}\NepType Keyboard\setup.ini'));
  RollbackHelper := AddBackslash(ExtractFileDir(Target)) + 'NepTypeKeyboardSetup.exe';
#ifdef TestRollback
  RaiseException('CI fixture: fail after keyboard registration to verify app and keyboard rollback.');
#endif
end;

procedure CurStepChanged(CurStep: TSetupStep);
var Code: Integer;
begin
  if (CurStep = ssDone) and KeyboardPending then begin
    if not RunHelper(ExpandConstant('{app}\NepTypeKeyboardSetup.exe'), 'commit ' + KeyboardToken, Code) or (Code <> 0) then
      RaiseException('Keyboard setup could not commit. The previous registration will be restored where possible.');
    KeyboardPending := False;
    SetupFailed := False;
    if not KeyboardWasRegistered and WizardIsTaskSelected('enableaccount') then begin
      if not ExecAsOriginalUser(ExpandConstant('{app}\NepTypeKeyboardSetup.exe'), 'enable-user', '', SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then
        Log('The keyboard is installed. This account must add/enable it in Windows language settings.');
    end;
  end;
end;

procedure DeinitializeSetup;
var Code: Integer;
begin
  if KeyboardPending then begin
    if not FileExists(RollbackHelper) then RollbackHelper := TemporaryHelper;
    if not RunHelper(RollbackHelper, 'rollback ' + KeyboardToken, Code) or (Code <> 0) then
      Log('Keyboard rollback could not complete. The protected recovery journal and version folders were kept.');
  end;
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := 0;
  if SetupFailed then Result := 8;
end;

function InitializeUninstall: Boolean;
var Code: Integer;
begin
  Result := RunHelper(ExpandConstant('{app}\NepTypeKeyboardSetup.exe'), 'probe', Code) and (Code = 0);
  if not Result then
    SuppressibleMsgBox('Keyboard setup is missing or conflicts with another registration. Repair NepType before uninstalling; no installed files have been removed.', mbError, MB_OK, IDOK);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var Code: Integer;
begin
  if CurUninstallStep = usUninstall then begin
    if not RunHelper(ExpandConstant('{app}\NepTypeKeyboardSetup.exe'), 'uninstall', Code) or ((Code <> 0) and (Code <> 3010)) then
      RaiseException('The Windows keyboard could not be unregistered. Installed files were kept. Repair NepType and try again.');
    KeyboardRestart := Code = 3010;
  end;
end;

function UninstallNeedRestart: Boolean;
begin
  Result := KeyboardRestart;
end;
