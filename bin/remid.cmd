@ECHO OFF
cd %~dp0..
bundle exec ruby bin/remid %*
