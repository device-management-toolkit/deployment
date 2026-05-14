; Device Management Toolkit Console - NSIS Installer Script
; Copyright (c) Intel Corporation
; SPDX-License-Identifier: Apache-2.0

;--------------------------------
; Includes

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"
!include "StrFunc.nsh"
!include "nsDialogs.nsh"
!include "WordFunc.nsh"

; Declare string functions we'll use (for installer)
${StrStr}

; Declare string functions for uninstaller (must use un. prefix)
${UnStrRep}

;--------------------------------
; General Configuration

!ifndef VERSION
  !define VERSION "0.0.0"
!endif

!ifndef ARCH
  !define ARCH "x64"
!endif

; Edition: "ui" or "headless" — set at build time via -DEDITION=<value>
!ifndef EDITION
  !define EDITION "ui"
!endif

; Binary to install — set at build time via -DBINARY=<path>
!ifndef BINARY
  !define BINARY "..\dist\windows\console_windows_x64.exe"
!endif

; Edition-specific naming
!if "${EDITION}" == "headless"
  !define EDITION_LABEL "Headless"
  !define EDITION_SUFFIX "_headless"
!else
  !define EDITION_LABEL ""
  !define EDITION_SUFFIX ""
!endif

Name "Device Management Toolkit Console ${VERSION}"
OutFile "console_${VERSION}_windows_${ARCH}${EDITION_SUFFIX}_setup.exe"
InstallDir "$PROGRAMFILES64\Device Management Toolkit\Console"
InstallDirRegKey HKLM "Software\DeviceManagementToolkit\Console" "InstallDir"
RequestExecutionLevel admin
Unicode True

; Compression
SetCompressor /SOLID lzma
SetCompressorDictSize 64

;--------------------------------
; Version Information

; VI_VERSION must be numeric X.X.X.X format — passed from Makefile with
; pre-release suffixes stripped. Falls back to VERSION.0 if not provided.
!ifndef VI_VERSION
  !define VI_VERSION "${VERSION}.0"
!endif
VIProductVersion "${VI_VERSION}"
VIAddVersionKey "ProductName" "Device Management Toolkit Console"
VIAddVersionKey "CompanyName" "Intel Corporation"
VIAddVersionKey "LegalCopyright" "Copyright (c) Intel Corporation"
VIAddVersionKey "FileDescription" "Device Management Toolkit Console Installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"

;--------------------------------
; Variables

Var Dialog
Var PortLabel
Var PortText
Var PortValue
Var TLSCheckbox
Var TLSEnabled
Var UsernameLabel
Var UsernameText
Var UsernameValue
Var PasswordLabel
Var PasswordText
Var PasswordValue

;--------------------------------
; Interface Settings

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"

; Show installation details
ShowInstDetails show
ShowUnInstDetails show

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
Page custom ConfigPage ConfigPageLeave
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Languages

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Configuration Page

Function ConfigPage
  !insertmacro MUI_HEADER_TEXT "Configuration" "Configure essential settings for the Console."

  nsDialogs::Create 1018
  Pop $Dialog

  ${If} $Dialog == error
    Abort
  ${EndIf}

  ; Port
  ${NSD_CreateLabel} 0 0 60u 12u "HTTP Port:"
  Pop $PortLabel

  ${NSD_CreateText} 65u 0 50u 12u "8181"
  Pop $PortText

  ${NSD_CreateLabel} 120u 0 100% 12u "(default: 8181)"
  Pop $0

  ; TLS
  ${NSD_CreateCheckbox} 0 25u 100% 12u "Enable TLS/HTTPS (recommended)"
  Pop $TLSCheckbox
  ${NSD_SetState} $TLSCheckbox ${BST_CHECKED}

  ${NSD_CreateLabel} 15u 40u 100% 12u "A self-signed certificate will be generated if no certificate is provided."
  Pop $0

  ; Separator
  ${NSD_CreateHLine} 0 60u 100% 1u
  Pop $0

  ; Admin credentials section
  ${NSD_CreateLabel} 0 70u 100% 12u "Administrator Credentials (for standalone authentication):"
  Pop $0

  ; Username
  ${NSD_CreateLabel} 0 90u 60u 12u "Username:"
  Pop $UsernameLabel

  ${NSD_CreateText} 65u 88u 120u 14u "standalone"
  Pop $UsernameText

  ; Password
  ${NSD_CreateLabel} 0 112u 60u 12u "Password:"
  Pop $PasswordLabel

  ${NSD_CreatePassword} 65u 110u 120u 14u "G@ppm0ym"
  Pop $PasswordText

  ${NSD_CreateLabel} 190u 112u 100% 12u "(change from default!)"
  Pop $0

  nsDialogs::Show
FunctionEnd

Function ConfigPageLeave
  ${NSD_GetText} $PortText $PortValue
  ${NSD_GetState} $TLSCheckbox $TLSEnabled
  ${NSD_GetText} $UsernameText $UsernameValue
  ${NSD_GetText} $PasswordText $PasswordValue
FunctionEnd

;--------------------------------
; Installer Sections

Section "Console Application" SecApp
  SectionIn RO ; Required section

  SetOutPath "$INSTDIR"

  ; Install the edition-specific binary as console.exe
  File /oname=console.exe "${BINARY}"

  ; Create config directory
  CreateDirectory "$INSTDIR\config"

  ; Create data directory
  CreateDirectory "$INSTDIR\data"

  ; Generate config.yml
  Call WriteConfigFile

  ; Store installation folder and edition
  WriteRegStr HKLM "Software\DeviceManagementToolkit\Console" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\DeviceManagementToolkit\Console" "Version" "${VERSION}"
  WriteRegStr HKLM "Software\DeviceManagementToolkit\Console" "Edition" "${EDITION}"

  ; Create uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Add to Add/Remove Programs
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                   "DisplayName" "Device Management Toolkit Console"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                   "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                   "QuietUninstallString" "$\"$INSTDIR\Uninstall.exe$\" /S"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                   "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                   "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                   "Publisher" "Intel Corporation"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                     "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                     "NoRepair" 1

  ; Calculate and store install size
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole" \
                     "EstimatedSize" "$0"
SectionEnd

Section "Start Menu Shortcuts" SecStartMenu
  CreateDirectory "$SMPROGRAMS\Device Management Toolkit"
  CreateShortcut "$SMPROGRAMS\Device Management Toolkit\Console.lnk" "$INSTDIR\console.exe" "--tray"
  CreateShortcut "$SMPROGRAMS\Device Management Toolkit\Uninstall Console.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Desktop Shortcut" SecDesktop
  CreateShortcut "$DESKTOP\DMT Console.lnk" "$INSTDIR\console.exe" "--tray"
SectionEnd

Section /o "Add to PATH" SecPath
  ; Add to system PATH using registry
  ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"

  ; Check if already in PATH
  ${StrStr} $1 $0 "$INSTDIR"
  ${If} $1 == ""
    ; Not in PATH, add it
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$0;$INSTDIR"
    ; Record that we added to PATH
    WriteRegStr HKLM "Software\DeviceManagementToolkit\Console" "AddedToPath" "1"
    ; Broadcast environment change
    SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=5000
  ${EndIf}
SectionEnd

Section /o "Run at Startup (System Tray)" SecStartup
  ; Add to HKLM Run key so it launches with --tray on login
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "DMTConsole" '"$INSTDIR\console.exe" --tray'

  ; Record that we added startup entry
  WriteRegStr HKLM "Software\DeviceManagementToolkit\Console" "StartupInstalled" "1"
SectionEnd

;--------------------------------
; Write Config File Function

Function WriteConfigFile
  ; Determine TLS setting
  ${If} $TLSEnabled == ${BST_CHECKED}
    StrCpy $0 "true"
  ${Else}
    StrCpy $0 "false"
  ${EndIf}

  FileOpen $1 "$INSTDIR\config\config.yml" w

  FileWrite $1 "app:$\r$\n"
  FileWrite $1 "  name: console$\r$\n"
  FileWrite $1 "  repo: device-management-toolkit/console$\r$\n"
  FileWrite $1 "  version: ${VERSION}$\r$\n"
  FileWrite $1 "  encryption_key: $\"$\"$\r$\n"
  FileWrite $1 "  allow_insecure_ciphers: false$\r$\n"
  FileWrite $1 "http:$\r$\n"
  FileWrite $1 "  host: localhost$\r$\n"
  FileWrite $1 "  port: $\"$PortValue$\"$\r$\n"
  FileWrite $1 "  ws_compression: false$\r$\n"
  FileWrite $1 "  tls:$\r$\n"
  FileWrite $1 "    enabled: $0$\r$\n"
  FileWrite $1 "    certFile: $\"$\"$\r$\n"
  FileWrite $1 "    keyFile: $\"$\"$\r$\n"
  FileWrite $1 "  allowed_origins:$\r$\n"
  FileWrite $1 "    - $\"*$\"$\r$\n"
  FileWrite $1 "  allowed_headers:$\r$\n"
  FileWrite $1 "    - $\"*$\"$\r$\n"
  FileWrite $1 "logger:$\r$\n"
  FileWrite $1 "  log_level: info$\r$\n"
  FileWrite $1 "secrets:$\r$\n"
  FileWrite $1 "  address: http://localhost:8200$\r$\n"
  FileWrite $1 "  token: $\"$\"$\r$\n"
  FileWrite $1 "postgres:$\r$\n"
  FileWrite $1 "  pool_max: 2$\r$\n"
  FileWrite $1 "  url: $\"$\"$\r$\n"
  FileWrite $1 "ea:$\r$\n"
  FileWrite $1 "  url: http://localhost:8000$\r$\n"
  FileWrite $1 "  username: $\"$\"$\r$\n"
  FileWrite $1 "  password: $\"$\"$\r$\n"
  FileWrite $1 "auth:$\r$\n"
  FileWrite $1 "  disabled: false$\r$\n"
  FileWrite $1 "  adminUsername: $\"$UsernameValue$\"$\r$\n"
  FileWrite $1 "  adminPassword: $\"$PasswordValue$\"$\r$\n"
  FileWrite $1 "  jwtKey: your_secret_jwt_key$\r$\n"
  FileWrite $1 "  jwtExpiration: 24h0m0s$\r$\n"
  FileWrite $1 "  redirectionJWTExpiration: 5m0s$\r$\n"
  FileWrite $1 "  clientId: $\"$\"$\r$\n"
  FileWrite $1 "  issuer: $\"$\"$\r$\n"
  FileWrite $1 "  ui:$\r$\n"
  FileWrite $1 "    clientId: $\"$\"$\r$\n"
  FileWrite $1 "    issuer: $\"$\"$\r$\n"
  FileWrite $1 "    scope: $\"$\"$\r$\n"
  FileWrite $1 "    redirectUri: $\"$\"$\r$\n"
  FileWrite $1 "    responseType: $\"code$\"$\r$\n"
  FileWrite $1 "    requireHttps: false$\r$\n"
  FileWrite $1 "    strictDiscoveryDocumentValidation: true$\r$\n"
  FileWrite $1 "ui:$\r$\n"
  FileWrite $1 "  externalUrl: $\"$\"$\r$\n"

  FileClose $1
FunctionEnd

;--------------------------------
; Section Descriptions

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "Install the Device Management Toolkit Console application. (Required)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} "Create Start Menu shortcuts for easy access."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Create a Desktop shortcut."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPath} "Add the installation directory to the system PATH environment variable."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartup} "Run Console with system tray icon at Windows startup."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
; Uninstaller Section

Section "Uninstall"
  ; Remove startup entry if installed
  ReadRegStr $0 HKLM "Software\DeviceManagementToolkit\Console" "StartupInstalled"
  ${If} $0 == "1"
    DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "DMTConsole"
  ${EndIf}

  ; Remove from PATH if we added it
  ReadRegStr $0 HKLM "Software\DeviceManagementToolkit\Console" "AddedToPath"
  ${If} $0 == "1"
    ReadRegStr $1 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
    ; Remove our path (try both with and without trailing semicolon)
    ${UnStrRep} $2 $1 ";$INSTDIR" ""
    ${UnStrRep} $2 $2 "$INSTDIR;" ""
    ${UnStrRep} $2 $2 "$INSTDIR" ""
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$2"
    ; Broadcast environment change
    SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=5000
  ${EndIf}

  ; Remove files
  Delete "$INSTDIR\console.exe"
  Delete "$INSTDIR\config\config.yml"
  Delete "$INSTDIR\Uninstall.exe"

  ; Remove directories (only if empty)
  RMDir "$INSTDIR\config"
  RMDir "$INSTDIR\data"
  RMDir "$INSTDIR"
  RMDir "$PROGRAMFILES64\Device Management Toolkit"

  ; Remove shortcuts
  Delete "$SMPROGRAMS\Device Management Toolkit\Console.lnk"
  Delete "$SMPROGRAMS\Device Management Toolkit\Uninstall Console.lnk"
  RMDir "$SMPROGRAMS\Device Management Toolkit"
  Delete "$DESKTOP\DMT Console.lnk"

  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\DMTConsole"
  DeleteRegKey HKLM "Software\DeviceManagementToolkit\Console"
  DeleteRegKey /ifempty HKLM "Software\DeviceManagementToolkit"

  ; Offer to remove user data. The DB and encryption key are tied together —
  ; keeping one without the other is useless, so they're removed as a unit.
  ; Silent uninstalls preserve data by default.
  IfSilent skip_data_prompt
  MessageBox MB_YESNO|MB_ICONQUESTION "Remove user data (database, logs, and encryption key from Credential Manager)?$\r$\n$\r$\nChoose No to preserve your configuration for a future reinstall." /SD IDNO IDNO skip_data_prompt
    DetailPrint "Removing user data..."
    RMDir /r "$APPDATA\device-management-toolkit"
    RMDir /r "$LOCALAPPDATA\device-management-toolkit"
    nsExec::Exec 'cmdkey /delete:device-management-toolkit:default-security-key'
    Pop $0
  skip_data_prompt:
SectionEnd

;--------------------------------
; Functions

Function .onInit
  ; Set default values
  StrCpy $PortValue "8181"
  StrCpy $TLSEnabled ${BST_CHECKED}
  StrCpy $UsernameValue "standalone"
  StrCpy $PasswordValue "G@ppm0ym"

  ; Check for admin rights
  UserInfo::GetAccountType
  Pop $0
  ${If} $0 != "admin"
    MessageBox MB_ICONSTOP "Administrator rights required!"
    SetErrorLevel 740 ; ERROR_ELEVATION_REQUIRED
    Quit
  ${EndIf}

  ; Check for existing installation. Block downgrades; allow same-version
  ; reinstalls and upgrades but stop any running console.exe first so the
  ; new binary can replace it.
  ReadRegStr $0 HKLM "Software\DeviceManagementToolkit\Console" "Version"
  ${If} $0 != ""
    ${VersionCompare} "$0" "${VERSION}" $1
    ${If} $1 == "1"
      MessageBox MB_ICONSTOP "A newer version of Device Management Toolkit Console ($0) is already installed.$\r$\nPlease uninstall it before installing ${VERSION}."
      Abort
    ${EndIf}
    DetailPrint "Stopping running Console instance..."
    nsExec::Exec 'taskkill /F /IM console.exe'
    Pop $2
    Sleep 1500
  ${EndIf}
FunctionEnd

Function un.onInit
  ; Stop any running Console instance so files can be removed.
  nsExec::Exec 'taskkill /F /IM console.exe'
  Pop $0
  Sleep 1500
FunctionEnd
