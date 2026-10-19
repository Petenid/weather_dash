; Inno Setup script for the Weather Dash installer.
; GitHub Actions runs this after building the app (see .github/workflows/build.yml).
; To build it yourself: install Inno Setup 6, run `flutter build windows --release`,
; then:  "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=1.0.0 installer\weather_dash.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Weather Dash"
#define AppExe "weather_dash.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; A fixed ID, so new versions install over old ones instead of side by side.
AppId={{6F1E5D3A-2B7C-4E8F-9A41-7C2D8B5E3F10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Petenid
AppPublisherURL=https://github.com/Petenid/weather_dash
AppSupportURL=https://github.com/Petenid/weather_dash/issues
; Installs just for the current person, so no administrator password is needed.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
OutputDir=..\dist
OutputBaseFilename=WeatherDash-{#AppVersion}-windows-setup

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
