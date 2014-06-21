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


DEBUG := false ;;;; Change this false to true if told.


LockdownConfigFile := A_AppData . "\NCSoft\WildStar\AddonSaveData\Lockdown_0_Gen.xml"

; Configuration defaults (Used if Lockdown isn't in play)
free_with_shift := false
free_with_alt := false
free_with_ctrl := false
reticle_offset_x := 0
reticle_offset_y := 0
ahk_lmb := "-"
ahk_rmb := "="
ahk_mmb := ""
ahk_cursor_center := true
ahk_update_interval := 100

if (DEBUG)
  FileDelete, %A_Desktop%\MouselockRebind_debug.txt

print( str, tag="", prefix="" )
{
  global DEBUG
  if (DEBUG) {
    if (prefix)
      str := prefix . ": " . str
    if (tag)
      str := "[" . tag . "] " . str
    FileAppend, %A_Now%  %str%`n, %A_Desktop%\MouselockRebind_debug.txt
    if (ErrorLevel == 1)
      MsgBox Could not write to %A_Desktop%\MouselockRebind_debug.txt    
  }
}

XMLDoc := ComObjCreate("MSXML2.DOMDocument.6.0")
XMLDoc.async := false

ReadConfig()
{
  global
  ; Read file
  local Contents
  FileRead, Contents, %LockdownConfigFile%
  if (Contents == 0)
    return

  ; Load document
  XMLDoc.loadXML(Contents)

  ; Read options
  local node
  for node in XMLDoc.selectSingleNode("/Document").childNodes
  {
    local key := node.GetAttribute("K")
    ; Ugh.
    if ( key == "free_with_shift"
      or key == "free_with_alt"
      or key == "free_with_ctrl"
      or key == "reticle_offset_x"
      or key == "reticle_offset_y"
      or key == "ahk_lmb"
      or key == "ahk_rmb"
      or key == "ahk_mmb"
      or key == "ahk_cursor_center"
      or key == "ahk_update_interval" ) {

      local vtype := node.GetAttribute("T")
      local value := node.GetAttribute("V")

      if (vtype == "n")
        %key% := value + 0
      else if (vtype == "b")
        %key% := (value == "+")
      else
        %key% := value
    }
  }

  if (DEBUG) {
    print(free_with_shift, "OPTION", "free_with_shift")
    print(free_with_ctrl, "OPTION", "free_with_ctrl")
    print(free_with_alt, "OPTION", "free_with_alt")
    print(reticle_offset_x, "OPTION", "reticle_offset_x")
    print(reticle_offset_y, "OPTION", "reticle_offset_y")
    print(ahk_lmb, "OPTION", "ahk_lmb")
    print(ahk_rmb, "OPTION", "ahk_rmb")
    print(ahk_mmb, "OPTION", "ahk_mmb")
    print(ahk_cursor_center, "OPTION", "ahk_cursor_center")
    print(ahk_update_interval, "OPTION", "ahk_update_interval")
  }
}

IsCursorVisible()
{
  NumPut(VarSetCapacity(CurrentCursorStruct, A_PtrSize + 16), CurrentCursorStruct, "uInt")
  DllCall("GetCursorInfo", "ptr", &CurrentCursorStruct)
  if (NumGet(CurrentCursorStruct, 8) <> 0)
    return true
  return false
}

LockCursor( activate=false, offset=5 )
{
  global reticle_offset_y
  global reticle_offset_x
  if (activate) {
    WinGetPos, x, y, w, h, ahk_group wildstar
    x1 := x + round(w/2 + reticle_offset_x)
    y1 := y + round(h/2 + reticle_offset_y)
    VarSetCapacity(R,16,0),  NumPut(x1-offset,&R+0),NumPut(y1-offset,&R+4),NumPut(x1+offset,&R+8),NumPut(y1+offset,&R+12)
    DllCall( "ClipCursor", UInt, &R )
  } else
    DllCall( "ClipCursor", UInt, 0 )
}

if FileExist(A_ScriptDir . "\wildstar_icon.ico") {
  Menu, Tray, Icon, %A_ScriptDir%\wildstar_icon.ico
}

Menu, Tray, NoStandard
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, Edit Script, EditScript
Menu, Tray, Add, Exit, ExitScript
Menu, Tray, Default, Reload

print("Starting up", "LOG")

ReadConfig()

; State is the current reading of the in-game indicator pixel
state := false
; Intent is the assumed state the game is in while tabbed out
intent := false

; State update timer
SetTimer, UpdateState, %ahk_update_interval%
SetTimer, UpdateState, Off

; Config refresh timer
SetTimer, GetConfig, 30000
SetTimer, GetConfig, Off

; Timer control and alt-tab locking/unlocking
Loop {
  WinWaitActive, ahk_group wildstar
  {
    ; Resume lock when refocused after automatically unlocking
    if (state == false && intent == true) {
      ControlSend, , {F7}, ahk_group wildstar
      print("Relocking", "ALT-TAB")
    }
    
    ; Activate polling
    SetTimer, UpdateState, On
    SetTimer, GetConfig, On

    ; Reload settings
    ReadConfig()

    print("Active", "WINDOW")
    
    ; Wait for unfocus
    WinWaitNotActive, ahk_group wildstar
    {
      SetTimer, GetConfig, Off
    }
  }
}

return

;;;;;;;;;;;;;;;;
; Labels

GetConfig:
  ReadConfig()
return

; Cursor state polling
UpdateState:
  ; Release and disable if not focused
  if not WinActive("ahk_group wildstar") {
    if (state) {
      ControlSend, , {F8}, ahk_group wildstar
      print("Unlocking", "ALT-TAB")
    }
    print("Inactive", "WINDOW")
    state := false
    SetTimer, UpdateState, Off
    LockCursor()
    return
  }
  
  if (IsCursorVisible()) {
    if (state)
      print("Change: Off", "WINDOW")
    LockCursor()
    state := false
    intent := false

  } else {
    if (state == false and not GetKeyState("LButton") and not GetKeyState("RButton")) {
      print("Change: On", "STATE")
      ; Send release signal
      ControlSend, , {F8}, ahk_group wildstar
      Sleep, 10
      ; Forcefully recenter cursor, possibly redundant
      WinGetPos, x, y, w, h
      DllCall("SetCursorPos", int, w/2 + 5 + reticle_offset_x, int, h/2 + reticle_offset_y)
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

EditScript:
  RunWait, notepad %A_ScriptFullPath%
  Reload
return

ExitScript:
  ExitApp
return

; Mouse remaps
#IfWinActive, ahk_group wildstar

*LButton::
  If (state and ahk_lmb != "") {
    Send, {blind}{%ahk_lmb% Down}
    KeyWait, LButton
    Send, {blind}{%ahk_lmb% Up}
  }
  else {
    Send, {blind}{LButton Down}
    KeyWait, LButton
    Send, {blind}{LButton Up}
  }
return

*RButton::
  If (state and ahk_rmb != "") {
    Send, {blind}{%ahk_rmb% Down}
    KeyWait, RButton
    Send, {blind}{%ahk_rmb% Up}
  }
  else {
    Send, {blind}{RButton Down}
    KeyWait, RButton
    Send, {blind}{RButton Up}
  }
return

*MButton::
  If (state and ahk_mmb != "") {
    Send, {blind}{%ahk_mmb% Down}
    KeyWait, MButton
    Send, {blind}{%ahk_mmb% Up}
  }
  else {
    Send, {blind}{MButton Down}
    KeyWait, MButton
    Send, {blind}{MButton Up}
  }
return
