#NoEnv
SendMode Input
; Does not interact with client at all
; Reads color of pixels at top left of screen which ActionStar sets according to current mouselock state.
; Expects Windows 8.1 windowed or borderless-windowed

; Keys you want pressed
Left_Click = 1
Right_Click = -

state := 0

; Color reading timer
SetTimer, ActionStarPulse, 250
return

ActionStarPulse:
IfWinActive, WildStar
{
	WinGetPos, X, Y
	WinGet, style, Style
	if style = 0x15CF0000
		PixelGetColor, color, X+16, Y+40
	else
		PixelGetColor, color, X+2, Y+2

	
	if color = 0x00FF00
		state := 1
	else
		state := 0
	return
}


; Mouse remaps
#IfWinActive, WildStar

$LButton::
If (state == 1){
  Send, {%Left_Click% Down}
  KeyWait, LButton
  Send, {%Left_Click% Up}
  return
}
else
  Click Down
  KeyWait, LButton
  Click Up
Return

$RButton::
If (state == 1){
  Send, {%Right_Click% Down}
  KeyWait, RButton
  Send, {%Right_Click% Up}
  Return
}
else
  Click Down
  KeyWait, RButton
  Click Up
Return