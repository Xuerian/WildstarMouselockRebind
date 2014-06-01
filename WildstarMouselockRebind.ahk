; TODO: WinWait instead of polling
; TODO: Scan for pixel initially and provide suitable feedback if not found
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

; Desired mouse binds
Left_Click = 1
Right_Click = -

;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DEBUG
; Change this to DEBUG = true if helping to fix issues.
DEBUG = true

DebugPrint( out ) {
	if (DEBUG == true)
		return
	FileAppend, %out%`n, %A_Desktop%\MouselockRebind_debug.txt
	if (ErrorLevel == 1)
		MsgBox Could not write to %A_Desktop%\MouselockRebind_debug.txt
}

DebugPrint("Starting up")

; Color reading timer
SetTimer, ActionStarPulse, 250
return

; State is the current reading of the in-game indicator pixel
state := false
; Intent is the assumed state the game is in while tabbed out (To get around mouselock location bugs)
intent := false

ActionStarPulse:
IfWinActive, ahk_group wildstar
{
	; Resume lock when refocused after automatically unlocking
	if (state == false && intent == true)
		ControlSend, , {F7}, ahk_group wildstar
	
	; Read color
	WinGet, style, Style
	if (style & 0x800000) ; Windowed mode
		PixelGetColor, color, 9, 31
	else ; Borderless windowed
		PixelGetColor, color, 2, 2
		
	; Update intent and state
	if (color == 0x00FF00) {
		state := true
		intent := true
	}
	else {
		state := false
		intent := false
	}
	return
}
; Release lock when focus lost
else if (state == true) {
	state := false
	ControlSend, , {F8}, ahk_group wildstar
}


; Mouse remaps
; Include all modifier states, it would be nice if this looked less redundant
#IfWinActive, ahk_group wildstar

$LButton::
^$LButton::
!$LBUTTON::
+$LBUTTON::
!^$LBUTTON::
If (state == true) {
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
!^$RBUTTON::
If (state == true) {
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