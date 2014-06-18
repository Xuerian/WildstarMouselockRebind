;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MouselockRebind
;
; Please change all options in MouselockRebind_Options.ini after script is run
;
; Checks visibility of mouse cursor to determine lock status
; Provides cursor re-centering and locking of cursor to screen, otherwise it would be much simpler.

#NoEnv
SendMode Input
#InstallKeybdHook
#UseHook
#SingleInstance force

GroupAdd, wildstar, ahk_exe Wildstar.exe
GroupAdd, wildstar, ahk_exe Wildstar64.exe

AppDataWS := A_AppData . "\NCSoft\WildStar\"

; Read options
optfile := AppDataWS . "AddonSaveData\MouselockRebind_Options.ini"
IniRead, Left_Click, %optfile%, MouseActions, Left_Click, -
IniRead, Right_Click, %optfile%, MouseActions, Right_Click, =
IniRead, Middle_Click, %optfile%, MouseActions, Middle_Click, %A_Space%
IniRead, OptReticleOffset_Y, %optfile%, ReticlePosition, ReticleOffset_Y, -100
IniRead, OptReticleOffset_X, %optfile%, ReticlePosition, ReticleOffset_X, 0
IniRead, OptRecenterCursor, %optfile%, Tweaks, RecenterCursor, true
IniRead, OptUpdateInterval, %optfile%, Tweaks, UpdateInterval, 100
IniRead, DEBUG, %optfile%, Tweaks, DEBUG, false

IniStrToBool( str ) {
  if (str == 1 or str == "true" or str == "yes")
    return true
  return false
}

; Correct option types
OptReticleOffset_Y := OptReticleOffset_Y + 0 ; Int
OptReticleOffset_X := OptReticleOffset_X + 0 ; Int
OptRecenterCursor := IniStrToBool(OptRecenterCursor) ; Bool
OptUpdateInterval := OptUpdateInterval + 0 ; Int
DEBUG := IniStrToBool(DEBUG) ; Bool

; Write out options to initialize any missing defaults
IniWrite, %Left_Click%, %optfile%, MouseActions, Left_Click
IniWrite, %Right_Click%, %optfile%, MouseActions, Right_Click
IniWrite, %Middle_Click%, %optfile%, MouseActions, Middle_Click
IniWrite, %OptReticleOffset_Y%, %optfile%, ReticlePosition, ReticleOffset_Y
IniWrite, %OptReticleOffset_X%, %optfile%, ReticlePosition, ReticleOffset_X
IniWrite, %OptRecenterCursor%, %optfile%, Tweaks, RecenterCursor
IniWrite, %OptUpdateInterval%, %optfile%, Tweaks, UpdateInterval
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

IsCursorVisible() {
  NumPut(VarSetCapacity(CurrentCursorStruct, A_PtrSize + 16), CurrentCursorStruct, "uInt")
  DllCall("GetCursorInfo", "ptr", &CurrentCursorStruct)
  if (NumGet(CurrentCursorStruct, 8) <> 0)
    return true
  return false
}

LockCursor( Activate=false, Offset=5 ) {
  global OptReticleOffset_Y
  global OptReticleOffset_X
  if Activate {
    WinGetPos, x, y, w, h, ahk_group wildstar
    x1 := x + round(w/2 + OptReticleOffset_X)
    y1 := y + round(h/2 + OptReticleOffset_Y)
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
; Intent is the assumed state the game is in while tabbed out
intent := false

; State update timer
SetTimer, UpdateState, %OptUpdateInterval%
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
    
    ; Activate polling
    SetTimer, UpdateState, On

    DebugPrint("[WINDOW] Active")
    
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
  
  if (IsCursorVisible()) {
    if (state)
      DebugPrint("[STATE] Change: Off")
    LockCursor()
    state := false
    intent := false

  } else {
    if (state == false and not GetKeyState("LButton") and not GetKeyState("RButton")) {
      DebugPrint("[STATE] Change: On")
      ; Send release signal
      ControlSend, , {F8}, ahk_group wildstar
      Sleep, 10
      ; Forcefully recenter cursor, possibly redundant
      WinGetPos, x, y, w, h
      DllCall("SetCursorPos", int, w/2 + 5 + OptReticleOffset_X, int, h/2 + OptReticleOffset_Y)
      ; Wait for wildstar to detect and release mouselock
      Sleep, 20
      ; Re-lock mouse
      ControlSend, , {F7}, ahk_group wildstar
      ; Lock loosely to prevent it leaving the screen
      ; but allowing it to feel responsive while unlocking
      LockCursor(true, 300)
    }
    state := true
    intent := true
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
