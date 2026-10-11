; Script generated for Inno Setup 6
; TIS RMS Windows Desktop Client Installer
; Features: Ultra-compressed release, automated silent .NET & VC++ runtime installer, selectable install directory, desktop shortcut checkbox, uninstaller, no auto-start.

#define MyAppName "TIS RMS Client"
#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#ifndef OutputBaseFilename
#define OutputBaseFilename "TIS_RMS_Client_Setup_v" + MyAppVersion
#endif
#define MyAppPublisher "Talisay Integrated School"
#define MyAppURL "https://web.tis-rms.cc.cd"
#define MyAppExeName "frontend.exe"
#define MyAppIcon "windows\runner\resources\app_icon.ico"

[Setup]
; Unique application GUID
AppId={{D36F3B1A-58F9-4672-91EA-A2B095790FC4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Destination install directory (allows user to select destination install path)
DefaultDirName={autopf}\TIS RMS Client
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
DisableDirPage=no
DisableProgramGroupPage=no

; Output installer file configuration
OutputDir=..\installers
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; Ultra compression for the smallest release file size
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMADictionarySize=65536
LZMANumBlockThreads=6
WizardStyle=modern

; Architecture constraints (64-bit Windows 10/11)
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; Checkbox for adding shortcut to desktop
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application binaries and libraries (excludes unnecessary dev .lib/.exp and prevents app-local CRT poisoning)
Source: "build\windows\x64\runner\Release\*.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion; Excludes: "msvcp140*.dll,vcruntime140*.dll,concrt140.dll,vccorlib140.dll"
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyAppIcon}"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion
; Bundled official Microsoft Visual C++ 2015-2022 Redistributable (x64)
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: dontcopy

[InstallDelete]
; Clean up any legacy app-local MSVC CRT DLLs from older installations so app always uses C:\Windows\System32
Type: files; Name: "{app}\msvcp140*.dll"
Type: files; Name: "{app}\vcruntime140*.dll"
Type: files; Name: "{app}\concrt140.dll"
Type: files; Name: "{app}\vccorlib140.dll"

[Icons]
; Start menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
; Uninstaller shortcut in start menu group
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Desktop shortcut (optional via checkbox)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
; Launch application option after installation (no auto-start on boot)
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Helper function to verify Microsoft Visual C++ 2015-2022 Redistributable (x64, Minor >= 30 for VS 2022 compatibility)
function IsVCRedistCompatible: Boolean;
var
  installed: Cardinal;
  minor: Cardinal;
begin
  Result := False;
  if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', installed) and (installed = 1) then
  begin
    if RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Minor', minor) then
      Result := (minor >= 30) // Minor 30+ indicates Visual Studio 2022 or newer
    else
      Result := True;
  end;
  if not Result then
  begin
    if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', installed) and (installed = 1) then
    begin
      if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Minor', minor) then
        Result := (minor >= 30)
      else
        Result := True;
    end;
  end;
end;

// Helper function to verify Microsoft .NET Desktop Runtime
function IsDotNetRuntimeInstalled: Boolean;
begin
  Result := RegKeyExists(HKLM64, 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App') or
            RegKeyExists(HKLM64, 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost') or
            RegKeyExists(HKLM, 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedfx\Microsoft.WindowsDesktop.App');
end;

// Installs bundled Microsoft Visual C++ Redistributable silently and verifies installation
procedure InstallVCRedist;
var
  ResultCode: Integer;
  VCRedistPath: String;
  PrevStatus: String;
begin
  if not IsVCRedistCompatible then
  begin
    PrevStatus := WizardForm.StatusLabel.Caption;
    WizardForm.StatusLabel.Caption := 'Installing Microsoft Visual C++ 2015-2022 Redistributable...';
    try
      try
        ExtractTemporaryFile('vc_redist.x64.exe');
        VCRedistPath := ExpandConstant('{tmp}\vc_redist.x64.exe');

        // Run bundled installer silently (/install /quiet /norestart)
        if not Exec(VCRedistPath, '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        begin
          SuppressibleMsgBox(
            'Failed to execute bundled Microsoft Visual C++ Redistributable installer.' + #13#10 +
            'System Error Code: ' + IntToStr(ResultCode) + #13#10#13#10 +
            'The application requires this runtime component to function properly. Please install vc_redist.x64.exe manually.',
            mbError, MB_OK, MB_OK
          );
        end
        else
        begin
          // Exit codes: 0 = SUCCESS, 3010 = SUCCESS_REBOOT_REQUIRED, 1641 = SUCCESS_REBOOT_INITIATED, 1638 = ANOTHER_VERSION_ALREADY_INSTALLED
          if (ResultCode <> 0) and (ResultCode <> 3010) and (ResultCode <> 1641) and (ResultCode <> 1638) then
          begin
            SuppressibleMsgBox(
              'Microsoft Visual C++ 2015-2022 Redistributable installation failed.' + #13#10 +
              'Installer Exit Code: ' + IntToStr(ResultCode) + #13#10#13#10 +
              'The application requires this runtime component to function properly. Please install vc_redist.x64.exe manually.',
              mbError, MB_OK, MB_OK
            );
          end
          else if (not IsVCRedistCompatible) and (ResultCode <> 3010) then
          begin
            SuppressibleMsgBox(
              'Microsoft Visual C++ 2015-2022 Redistributable completed, but runtime verification in the system registry failed.' + #13#10#13#10 +
              'The application requires this runtime component to function properly. Please install vc_redist.x64.exe manually.',
              mbError, MB_OK, MB_OK
            );
          end;
        end;
      except
        SuppressibleMsgBox(
          'An error occurred while preparing the Visual C++ Redistributable: ' + GetExceptionMessage + #13#10#13#10 +
          'Please install Microsoft Visual C++ 2015-2022 Redistributable (x64) manually.',
          mbError, MB_OK, MB_OK
        );
      end;
    finally
      WizardForm.StatusLabel.Caption := PrevStatus;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Check and install Microsoft Visual C++ 2015-2022 Redistributable
    InstallVCRedist;

    // If .NET Desktop Runtime is not installed, automatically install it silently
    if not IsDotNetRuntimeInstalled then
    begin
      Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference = ''SilentlyContinue''; try { if (Get-Command winget -ErrorAction SilentlyContinue) { winget install --id Microsoft.DotNet.DesktopRuntime.8 --silent --accept-package-agreements --accept-source-agreements } else { $url = ''https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe''; $out = ''$env:TEMP\dotnet8_desktop.exe''; Invoke-WebRequest -Uri $url -OutFile $out; Start-Process -FilePath $out -ArgumentList ''/install /quiet /norestart'' -Wait } } catch {}"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;

function InitializeSetup: Boolean;
begin
  Result := True;
end;
