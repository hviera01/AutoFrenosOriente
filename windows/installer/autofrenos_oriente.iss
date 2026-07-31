; Instalador de Windows para Auto Frenos Oriente, generado con Inno Setup 6.
;
; AppId recuperado del registro de Windows de una PC con la instalación real
; (HKLM\...\Uninstall\{8060EE83-CA1B-4C0F-8CC0-1D56A4523EC1}_is1) para que
; esta y las próximas actualizaciones sigan reemplazando en el mismo lugar en
; vez de crear una instalación duplicada -no generar un GUID nuevo-.
;
; Uso: compilar con
;   flutter build windows --release
;   iscc windows\installer\autofrenos_oriente.iss
; El .exe resultante queda en windows\installer\Output\AutoFrenosOriente<version>.exe
; -subirlo a mano al release de GitHub, ver ActualizacionService y version_app.dart-.

#define MyAppName "Auto Frenos Oriente"
#define MyAppVersion "12"
#define MyAppExeName "sistema_ventas.exe"
#define MyReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8060EE83-CA1B-4C0F-8CC0-1D56A4523EC1}
AppName={#MyAppName}
AppVerName={#MyAppName} version {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher=My Company, Inc.
AppPublisherURL=https://www.example.com/
AppSupportURL=https://www.example.com/
AppUpdatesURL=https://www.example.com/
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=Output
OutputBaseFilename=AutoFrenosOriente{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion; Excludes: "data\*"
Source: "{#MyReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir {#MyAppName}"; Flags: nowait postinstall skipifsilent
