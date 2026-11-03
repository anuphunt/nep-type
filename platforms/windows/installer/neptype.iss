#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif

[Setup]
AppId={{5E4BC5AE-0272-4601-9D59-3018815A456C}
AppName=NepType
AppVersion={#AppVersion}
VersionInfoVersion=0.1.1.1
AppPublisher=NepType
AppPublisherURL=https://neptype.com
AppSupportURL=https://github.com/anuphunt/nep-type/issues
AppUpdatesURL=https://neptype.com/windows/
DefaultDirName={localappdata}\Programs\NepType
DefaultGroupName=NepType
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
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
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#PayloadDir}\NepType.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\NepTypeEngine.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\dictionaries\*"; DestDir: "{app}\dictionaries"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\NepType"; Filename: "{app}\NepType.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\NepType.exe"; Description: "Open NepType"; Flags: nowait postinstall skipifsilent unchecked
