::@echo off
set FAKE_RELEASE=1
set PERL5_LOCAL_LIB_HOME=%CD%\local
perl -I%PERL5_LOCAL_LIB_HOME%\lib\perl5 -Mlocal::lib=%PERL5_LOCAL_LIB_HOME% > perlenv.bat
call perlenv.bat & del perlenv.bat
set local\bin;%PATH%
echo -- env setting --
echo PERL5_LOCAL_LIB_HOME: %PERL5_LOCAL_LIB_HOME%
echo PERL5LIB:             %PERL5LIB%
echo PERL_LOCAL_LIB_ROOT:  %PERL_LOCAL_LIB_ROOT%
echo PERL_MB_OPT:          %PERL_MB_OPT%
echo PERL_MM_OPT:          %PERL_MM_OPT%
echo PATH:                
setlocal enabledelayedexpansion
set lf=^


echo %PATH:;=!LF!%
endlocal
echo -- env setting --
doskey run=perl^ -Ilib^ $*
doskey test=prove -Ilib^ -r^ t

