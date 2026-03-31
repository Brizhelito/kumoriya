[Setup]
AppName=Kumoriya
AppVersion=0.1.2
AppPublisher=Kumoriya
AppPublisherURL=https://kumoriya.app
AppSupportURL=https://kumoriya.app
AppUpdatesURL=https://kumoriya.app
DefaultDirName={autopf}\Kumoriya
DefaultGroupName=Kumoriya
OutputDir=..\build\windows\installer
OutputBaseFilename=Kumoriya-0.1.2-windows-x64-setup
SetupIconFile=..\..\..\windows.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

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
