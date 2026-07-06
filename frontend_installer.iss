[Setup]
AppName=TIS RMS Client
AppVersion=1.0
DefaultDirName={pf}\TIS RMS Client
DefaultGroupName=TIS RMS Client
OutputDir=f:\SumbrerongBato\tis_rms_server\installers
OutputBaseFilename=TIS_RMS_Client_Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "f:\SumbrerongBato\tis_rms_server\frontend\build\windows\x64\runner\Release\frontend.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "f:\SumbrerongBato\tis_rms_server\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\TIS RMS Client"; Filename: "{app}\frontend.exe"
Name: "{group}\Uninstall TIS RMS Client"; Filename: "{uninstallexe}"
Name: "{commondesktop}\TIS RMS Client"; Filename: "{app}\frontend.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\frontend.exe"; Description: "Launch TIS RMS Client"; Flags: nowait postinstall skipifsilent
