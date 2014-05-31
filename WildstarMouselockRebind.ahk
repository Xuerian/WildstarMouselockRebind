﻿#NoEnv
SendMode Input
#InstallKeybdHook
#UseHook 
; Does not interact with client at all, no hooks
; Reads color of pixels at top left of screen which the MouselockIndicatorPixel addon sets according to GameLib.IsMouseLockOn()
; Tested with Windows 8.1 windowed and borderless-windowed

; Desired mouse binds
Left_Click = 1
Right_Click = -

; Color reading timer
SetTimer, ActionStarPulse, 250
return

state := false
intent := false

ActionStarPulse:
IfWinActive, WildStar
{
	; Resume lock when refocused after automatically unlocking
	if (state == false && intent == true)
		ControlSend, , {F7}, WildStar
	
	; Read color
	WinGet, style, Style
	if (style & 0x800000)
		PixelGetColor, color, 9, 31
	else
		PixelGetColor, color, 3, 3
	
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
	ControlSend, , {F8}, WildStar
}


; Mouse remaps
#IfWinActive, WildStar

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