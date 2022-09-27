successMessage(0, "compilation successful")
SoundPlay, %A_WinDir%\Media\Windows Print Complete.wav, Wait
Gosub, ClearMessageTimer
ExitApp



successMessage(delay, title, message = "", width=250, color = "47a447") {
  Gui, SplashMessage:New, +AlwaysOnTop +ToolWindow +LastFound +E0x20, %title%
  Gui, Color, 000011
  Gui, Font, W700 S12 c%color%
  Gui, Add, Text, center w%width%, %title%
  if(message != "") {
    Gui, Font, W700 S10 c%color%
    Gui, Add, Text, center w%width%, %message%
  }
  WinSet, Transparent, 175
  ;WinSet, TransColor, 000011 200
  Gui, SplashMessage: -Caption
  Gui, Show, NoActivate y100
  ;SetTimer, ClearMessageTimer, %delay%
}

failureMessage(delay, title, message = "", width=250) {
  successMessage(delay, title, message, width, "d9534f")
}

ClearMessageTimer:
  SetTimer, ClearMessageTimer, Off
  Gui, SplashMessage:Destroy
  return
