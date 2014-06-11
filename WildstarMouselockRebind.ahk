;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MouselockRebind
;
; Please change all options in MouselockRebind_Options.ini after script is run
;
; Interacts with Wildstar to the least degree possible.
; Reads color of pixels at top left of screen which the MouselockIndicatorPixel addon sets according to GameLib.IsMouseLockOn()
; Presses F7, F8, and F9 to toggle mouselock status in game
;
; Tested with Windows 8.1 windowed and borderless-windowed


; TODO: Provide for a custom lock location by defocusing wildstar, positioning the mouse, and locking it before returning focus

#NoEnv
SendMode Input
#InstallKeybdHook
#UseHook
#SingleInstance force

GroupAdd, wildstar, ahk_exe Wildstar.exe
GroupAdd, wildstar, ahk_exe Wildstar64.exe

; Read options
optfile := "MouselockRebind_Options.ini"
IniRead, Left_Click, %optfile%, MouseActions, Left_Click, 1
IniRead, Right_Click, %optfile%, MouseActions, Right_Click, -
IniRead, ReticleOffset_Y, %optfile%, ReticlePosition, ReticleOffset_Y, -100
IniRead, ReticleOffset_X, %optfile%, ReticlePosition, ReticleOffset_X, 0
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
ReticleOffset_Y := ReticleOffset_Y + 0 ; Int
ReticleOffset_X := ReticleOffset_X + 0 ; Int
UpdateInterval := UpdateInterval + 0 ; Int
AlternateDetectionMode := IniStrToBool(AlternateDetectionMode) ; Bool
AlternateDetectionModeTolerance := AlternateDetectionModeTolerance + 0 ; Int
DEBUG := IniStrToBool(DEBUG) ; Bool

; Write out options to initialize any missing defaults
IniWrite, %Left_Click%, %optfile%, MouseActions, Left_Click
IniWrite, %Right_Click%, %optfile%, MouseActions, Right_Click
IniWrite, %ReticleOffset_Y%, %optfile%, ReticlePosition, ReticleOffset_Y
IniWrite, %ReticleOffset_X%, %optfile%, ReticlePosition, ReticleOffset_X
IniWrite, %UpdateInterval%, %optfile%, Tweaks, UpdateInterval
IniWrite, %AlternateDetectionMode%, %optfile%, Tweaks, AlternateDetectionMode
IniWrite, %AlternateDetectionModeTolerance%, %optfile%, Tweaks, AlternateDetectionModeTolerance
IniWrite, %DEBUG%, %optfile%, Tweaks, DEBUG

DebugPrint( params* ) {
  global DEBUG
  if (DEBUG) {
    if (params.MaxIndex() > 1) {
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
; 2 = green (Lock active and clean)
; 3 = blue (Lock active, needs reposition)
GetPixelStatus( x, y ) {
  global DEBUG
  global AlternateDetectionMode
  global AlternateDetectionModeTolerance
  if (AlternateDetectionMode) {
    PixelSearch, , , x, y, x, y, 0x00FF00, %AlternateDetectionModeTolerance%, Fast
    if (ErrorLevel == 0)
      return 2
    PixelSearch, , , x, y, x, y, 0xFF0000, %AlternateDetectionModeTolerance%, Fast
    if (ErrorLevel == 0)
      return 3
    PixelSearch, , , x, y, x, y, 0x000000, %AlternateDetectionModeTolerance%, Fast
    if (ErrorLevel == 0)
      return 1
  } else {
    PixelGetColor, color, x, y
    if (color == 0x00FF00) ; 0x003400
      return 2
    if (color == 0xFF0000)
      return 3
    else if (color == 0x000000)
      return 1
  }
  if (DEBUG) {
    PixelGetColor, color, x, y
    DebugPrint("[ERROR] GetPixelStatus failed (x, y, color found, (green), (black))", x, y, HexStr(color), "0x00FF00", "0x000000")
  }
  return 0
}


LockCursor( Activate=false, Offset=5 ) {
  global ReticleOffset_Y
  global ReticleOffset_X
  if Activate {
    WinGetPos, x, y, w, h, ahk_group wildstar
    x1 := x + round(w/2 + ReticleOffset_X)
    y1 := y + round(h/2 + ReticleOffset_Y)
    VarSetCapacity(R,16,0),  NumPut(x1-Offset,&R+0),NumPut(y1-Offset,&R+4),NumPut(x1+Offset,&R+8),NumPut(y1+Offset,&R+12)
    DllCall( "ClipCursor", UInt, &R )
  } else
    DllCall( "ClipCursor", UInt, 0 )
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
; Intent is the assumed state the game is in while tabbed out (To get around mouselock location bugs)
intent := false

borderless := true

; State update timer
SetTimer, UpdateState, %UpdateInterval%
SetTimer, UpdateState, Off

; Timer control and alt-tab locking/unlocking
Loop {
  WinWaitActive, ahk_group wildstar
  {
    ; Resume lock when refocused after automatically unlocking
    if (state == false && intent == true) {
      ControlSend, , {F7}, ahk_group wildstar
      DebugPrint("[ALT-TAB] Relocking")
    }
    
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
      ; SetTimer, UpdateState, Off
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
    if (state) {
      ControlSend, , {F8}, ahk_group wildstar
      DebugPrint("[ALT-TAB] Unlocking")
    }
    DebugPrint("[WINDOW] Inactive")
    state := false
    SetTimer, UpdateState, Off
    LockCursor()
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
      ; Lock loosely to prevent it leaving the screen
      ; but allowing it to feel responsive while unlocking
      LockCursor(true, 300)
    }
    state := true
    intent := true
  } else if (pixel_status == 3) { ; Blue, recenter cursor
    DebugPrint("[FIX] Recentering cursor")
    state := false
    ; Lock cursor so movement doesn't disrupt it
    LockCursor(true)
    ; Forcefully recenter cursor, possibly redundant
    WinGetPos, x, y, w, h
    DllCall("SetCursorPos", int, w/2 + 10 + ReticleOffset_X, int, h/2 + ReticleOffset_Y)
    ; Send release signal
    ControlSend, , {F8}, ahk_group wildstar
    ; Wait for wildstar to detect and release mouselock
    Sleep, 20
    ; Re-lock mouse (Confirming clean)
    ControlSend, , {F9}
  } else { ; Black, release cursor
    if (state) {
      DebugPrint("[STATE] Change: Off")
    }
    LockCursor()
    state := false
    intent := false
  }
return

ReloadScript:
  Reload
return

EditSettings:
  Run, notepad %optfile%
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
