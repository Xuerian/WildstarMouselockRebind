;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MouselockRebind
;
; Please change all options in MouselockRebind_Options.ini after script is run
;
; Interacts with Wildstar to the least degree possible.
; Reads color of pixels at top left of screen which the MouselockIndicatorPixel addon sets according to GameLib.IsMouseLockOn()

#NoEnv
SendMode Input
#InstallKeybdHook
#UseHook
#SingleInstance force

GroupAdd, wildstar, ahk_exe Wildstar.exe
GroupAdd, wildstar, ahk_exe Wildstar64.exe

; Read options
SetWorkingDir %A_ScriptDir% ; Some people's save files landed in odd places..
optfile := "MouselockRebind_Options.ini"
IniRead, Left_Click, %optfile%, MouseActions, Left_Click, -
IniRead, Right_Click, %optfile%, MouseActions, Right_Click, =
IniRead, Middle_Click, %optfile%, MouseActions, Middle_Click, %A_Space%
IniRead, UpdateInterval, %optfile%, Tweaks, UpdateInterval, 100
IniRead, AlternateDetectionMode, %optfile%, Tweaks, AlternateDetectionMode, false
IniRead, AlternateDetectionModeTolerance, %optfile%, Tweaks, AlternateDetectionModeTolerance, 4
IniRead, DEBUG, %optfile%, Tweaks, DEBUG, false

IniStrToBool( str ) {
  if (str == 1 or str == "true" or str == "yes")
    return true
  return false
}

; Correct option types
UpdateInterval := UpdateInterval + 0 ; Int
AlternateDetectionMode := IniStrToBool(AlternateDetectionMode) ; Bool
AlternateDetectionModeTolerance := AlternateDetectionModeTolerance + 0 ; Int
DEBUG := IniStrToBool(DEBUG) ; Bool

; Write out options to initialize any missing defaults
IniWrite, %Left_Click%, %optfile%, MouseActions, Left_Click
IniWrite, %Right_Click%, %optfile%, MouseActions, Right_Click
IniWrite, %Middle_Click%, %optfile%, MouseActions, Middle_Click
IniWrite, %UpdateInterval%, %optfile%, Tweaks, UpdateInterval
IniWrite, %AlternateDetectionMode%, %optfile%, Tweaks, AlternateDetectionMode
IniWrite, %AlternateDetectionModeTolerance%, %optfile%, Tweaks, AlternateDetectionModeTolerance
IniWrite, %DEBUG%, %optfile%, Tweaks, DEBUG

DebugPrint( params* ) {
  global DEBUG
  if (DEBUG) {
    if (params.MaxIndex() > 1) {
      str := ""
      for index,param in params
        str .= param . ", "
      str := SubStr(str, 1, -2)
    } else
      str := params[1]

    FileAppend, %A_Now%  %str%`n, %A_Desktop%\MouselockRebind_debug.txt
    if (ErrorLevel == 1)
      MsgBox Could not write to %A_Desktop%\MouselockRebind_debug.txt    
  }
}

HexStr( hex ) {
  SetFormat, IntegerFast, Hex
  str := hex . ""
  SetFormat, IntegerFast, D
  return hex . ""
}

; 0 = Invalid
; 1 = black (Inactive)
; 2 = green (Lock active)
GetPixelStatus( x, y ) {
  global DEBUG
  global AlternateDetectionMode
  global AlternateDetectionModeTolerance
  if (AlternateDetectionMode) {
    PixelSearch, , , x, y, x, y, 0x00FF00, %AlternateDetectionModeTolerance%, Fast
    if (ErrorLevel == 0)
      return 2
    PixelSearch, , , x, y, x, y, 0x000000, %AlternateDetectionModeTolerance%, Fast
    if (ErrorLevel == 0)
      return 1
  } else {
    PixelGetColor, color, x, y
    if (color == 0x00FF00) ; 0x003400
      return 2
    else if (color == 0x000000)
      return 1
  }
  if (DEBUG) {
    PixelGetColor, color, x, y
    DebugPrint("[ERROR] GetPixelStatus failed (x, y, color found, (green), (black))", x, y, HexStr(color), "0x00FF00", "0x000000")
  }
  return 0
}

if FileExist(A_ScriptDir . "\wildstar_icon.ico") {
  Menu, Tray, Icon, %A_ScriptDir%\wildstar_icon.ico
}

Menu, Tray, NoStandard
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, Settings, EditSettings
Menu, Tray, Add, Exit, ExitScript
Menu, Tray, Default, Settings

if (DEBUG)
  FileDelete, %A_Desktop%\MouselockRebind_debug.txt

DebugPrint("Starting up")

; State is the current reading of the in-game indicator pixel
state := false

borderless := true

; State update timer
SetTimer, UpdateState, %UpdateInterval%
SetTimer, UpdateState, Off

; Timer control and alt-tab locking/unlocking
Loop {
  WinWaitActive, ahk_group wildstar
  {
    ; Update window type
    WinGet, style, Style
    borderless := (NOT style & 0x800000)

    ; Activate color polling
    SetTimer, UpdateState, On
    
    ; Make sure we find the pixel
    if (borderless)
      pixel_status := GetPixelStatus(1, 1)
    else
      pixel_status := GetPixelStatus(8, 31)
    if (pixel_status == 0) {
      DebugPrint("[ERROR] Failed to find pixel on focus")
    }
    
    DebugPrint("[WINDOW] Active", borderless ? "Borderless" : "Normal window")
    
    ; Wait for unfocus
    WinWaitNotActive, ahk_group wildstar
    {
    }
  }
}

return

UpdateState:
  ; Release and disable if not focused
  if not WinActive("ahk_group wildstar") {
    DebugPrint("[WINDOW] Inactive")
    state := false
    SetTimer, UpdateState, Off
    return
  }
  
  ; Check pixel status
  if (borderless)
    pixel_status := GetPixelStatus(1, 1)
  else
    pixel_status := GetPixelStatus(8, 31)
  
  ; Act on status
  if (pixel_status == 2) { ; Green
    if (state == false) {
      DebugPrint("[STATE] Change: On")
    }
    state := true
  } else {
    if (state) {
      DebugPrint("[STATE] Change: Off")
    }
    state := false
  }
return

ReloadScript:
  Reload
return

EditSettings:
  MsgBox, , MouselockRebind Options, Make your changes then save when closing Notepad, 5
  RunWait, notepad %optfile%
  Reload
return

ExitScript:
  ExitApp
return

; Mouse remaps
#IfWinActive, ahk_group wildstar

*LButton::
  If (state and Left_Click != "") {
    Send, {blind}{%Left_Click% Down}
    KeyWait, LButton
    Send, {blind}{%Left_Click% Up}
  }
  else {
    Send, {blind}{LButton Down}
    KeyWait, LButton
    Send, {blind}{LButton Up}
  }
return

*RButton::
  If (state and Right_Click != "") {
    Send, {blind}{%Right_Click% Down}
    KeyWait, RButton
    Send, {blind}{%Right_Click% Up}
  }
  else {
    Send, {blind}{RButton Down}
    KeyWait, RButton
    Send, {blind}{RButton Up}
  }
return

*MButton::
  If (state and Middle_Click != "") {
    Send, {blind}{%Middle_Click% Down}
    KeyWait, MButton
    Send, {blind}{%Middle_Click% Up}
  }
  else {
    Send, {blind}{MButton Down}
    KeyWait, MButton
    Send, {blind}{MButton Up}
  }
return
