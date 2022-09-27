@ECHO OFF
if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit )
..\bin\remid.cmd %~dp0 %*^
 -c C:\Users\chaos\Desktop\Games\MultiMC\instances\1.19.2\.minecraft\saves\copyNpaste\datapacks\^
 -s 'start "" %~dp0\success.ahk'^
 -f 'start "" %~dp0\failure.ahk'

rem to make sure to retain empty line above or batch might do weird things
