;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; MOUSE BINDINGS
;;;; Change to whatever you want.
;;;; Or just rebind these keys in game (easier)
Left_Click = 1
Right_Click = -

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; DEBUG
;;;; Change this to DEBUG := true if helping to fix issues.
DEBUG := false

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;; Don't change anything below this line





; TODO: Provide for a custom lock location by defocusing wildstar, positioning the mouse, and locking it before returning focus

#NoEnv
SendMode Input
#InstallKeybdHook
#UseHook

; Does not interact with client at all, no hooks
; Reads color of pixels at top left of screen which the MouselockIndicatorPixel addon sets according to GameLib.IsMouseLockOn()
; Tested with Windows 8.1 windowed and borderless-windowed
GroupAdd, wildstar, ahk_exe Wildstar.exe
GroupAdd, wildstar, ahk_exe Wildstar64.exe


DebugPrint( params* ) {
	if (not DEBUG)
		return
		
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

HexStr( hex ) {
	SetFormat, IntegerFast, Hex
	str := hex . ""
	SetFormat, IntegerFast, D
	return hex . ""
}

; 0 = Invalid
; 1 = black
; 2 = green
GetPixelStatus( x, y ) {
	PixelGetColor, color, x, y
	if (color == 0x00FF00)
		return 2
	else if (color == 0x000000)
		return 1
	;else if (color == 0x0D1315) ; Options screen
	;	return 3
	if (DEBUG)
		DebugPrint("[ERROR] GetPixelStatus failed (x, y, color found, (green), (black))", x, y, HexStr(color), "0x00FF00", "0x000000")
	return 0
}

if FileExist(A_ScriptDir . "\wildstar_icon.ico") {
	Menu, Tray, Icon, %A_ScriptDir%\wildstar_icon.ico
}

if (DEBUG)
	FileDelete, %A_Desktop%\MouselockRebind_debug.txt
DebugPrint("Starting up")

; State is the current reading of the in-game indicator pixel
state := false
; Intent is the assumed state the game is in while tabbed out (To get around mouselock location bugs)
intent := false

borderless := true

; State update timer
SetTimer, UpdateState, 250
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
			SetTimer, UpdateState, Off
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
	if not WinActive("ahk_group wildstar") {
		if (state) {
			ControlSend, , {F8}, ahk_group wildstar
			DebugPrint("[ALT-TAB] Unlocking")
		}
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
		if (state == false)
			DebugPrint("[STATE] Change: On")
		state := true
		intent := true
	} else {
		if (state)
			DebugPrint("[STATE] Change: Off")
		state := false
		intent := false
	}
return

; Mouse remaps
; Include all modifier states, it would be nice if this looked less redundant
#IfWinActive, ahk_group wildstar

$LButton::
^$LButton::
!$LBUTTON::
+$LBUTTON::
+!$LBUTTON::
+^$LBUTTON::
!^$LBUTTON::
If (state) {
  Send, {%Left_Click% Down}
  KeyWait, LButton
  Send, {%Left_Click% Up}
  return
}
else {
  Click Down
  KeyWait, LButton
  Click Up
  return
}

$RButton::
^$RButton::
!$RBUTTON::
+$RBUTTON::
+!$RBUTTON::
+^$RBUTTON::
!^$RBUTTON::
If (state) {
  Send, {%Right_Click% Down}
  KeyWait, RButton
  Send, {%Right_Click% Up}
  Return
}
else {
  Click right Down
  KeyWait, RButton
  Click right Up
  return
}