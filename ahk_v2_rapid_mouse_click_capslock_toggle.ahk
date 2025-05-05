; taken from https://www.autohotkey.com/boards/viewtopic.php?style=1&f=95&t=115469
; Enables rapid mouse clicks (left mouse button) when CapsLock is toggled (one tap: script activated, second tap, script de-activated)
; Emits PC speaker-style audio beep when toggled
; Default delay between clicks is 375ms (line 17). Change this up or down if it overloads the CPU and/or software
; This only works in AutoHotKey v2.0
#Requires AutoHotkey v2.0
; Taken from 
auto := False

CapsLock:: {
 Global auto := !auto
 SoundBeep 1000 + 500 * auto
}

#HotIf auto
LButton:: {
 SetKeyDelay 375, 375
 While GetKeyState(ThisHotkey, "P")
  SendEvent '{' ThisHotkey '}'
}
#HotIf
F10::ExitApp
