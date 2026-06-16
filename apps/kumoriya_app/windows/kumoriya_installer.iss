[Setup]
AppName=Kumoriya
AppVersion=0.4.1
AppPublisher=Kumoriya
AppPublisherURL=https://kumoriya.app
AppSupportURL=https://kumoriya.app
AppUpdatesURL=https://kumoriya.app
DefaultDirName={autopf}\Kumoriya
DefaultGroupName=Kumoriya
OutputDir=..\build\windows\installer
OutputBaseFilename=Kumoriya-0.4.1-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Registry]
; Register kumoriya:// custom URI protocol so Windows routes deep links to the app.
; HKCU avoids requiring admin rights. The keys are removed automatically on uninstall.
Root: HKCU; Subkey: "SOFTWARE\Classes\kumoriya"; ValueType: string; ValueName: ""; ValueData: "URL:Kumoriya Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\kumoriya"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\kumoriya\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\kumoriya_app.exe"" ""%1"""; Flags: uninsdeletekey

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Kumoriya"; Filename: "{app}\kumoriya_app.exe"
Name: "{group}\{cm:UninstallProgram,Kumoriya}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Kumoriya"; Filename: "{app}\kumoriya_app.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\kumoriya_app.exe"; Description: "{cm:LaunchProgram,Kumoriya}"; Flags: nowait postinstall skipifsilent
