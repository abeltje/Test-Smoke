@ECHO off
REM This is the traditional way for Win32 nmake/MSVCxx; 
REM Although at this moment tested with dmake/GCC
REM Revision: 1.08
IF /I "%1"=="/?" GOTO Usage
FOR %%a IN (h /h -h help /help -help) DO IF /I "%1"=="%%a" GOTO Usage

REM This could be run with AT like:
REM AT 22:25 /EVERY:M,T,W,Th,F,S,Su c:\path\to\smokew32.bat

REM Change your BuildDir(TS_DB), Config File(TS_CF)
REM and C-Compiler(CCTYPE) here:
set TS_BD=c:\usr\local\src\bleadperl\perl
set TS_CF=w32current.cfg
set CCTYPE=GCC

REM We now have 'synctree.pl', We'll set the default to 'rsync'
set TS_RP=ftp.linux.activestate.com::perl-current
REM Please see the documentation about 'snapshot' or 'copy'
set SYNCARGS=-t rsync -d "%TS_BD%" --source %TS_RP% -v

REM We now have 'mailrpt.pl', look at its documentation!
REM PLEASE set your SMTPserver and EMAILaddress
set SMTP=localhost
set EMAIL=smoker
set MAILARGS=-t Mail::Sendmail --mserver %SMTP% --from %EMAIL%

REM Set GCC_VERSION here if your shell can't deal with
REM with this stuff. Only applies for for GCC
set GCC_VERSION=

REM Set OS_VERSION
FOR /F "usebackq delims=" %%V IN (`perl -e"printf q{%s.%s %s},(Win32::GetOSVersion)[1,2,0]"`) DO set OS_VERSION=%%V
IF "%OS_VERSION%"=="" set OS_VERSION=5.0 Win2000Pro

REM I don't know how to detect these, so set them as appropriate
REM set BCC_VERSION=5.5
REM set CL_VERSION=60

REM If you don't want all this fancy checking
REM Just set MK to [dmake | nmake] here
set MK=

REM Is this hack for WD=`pwd`, CMD.EXE specific?
REM You could also uncomment the SET WD= line (must end with '\'!)
REM and comment this one out
FOR %%I IN ( %0 ) DO set WD=%%~dpI
REM set WD=c:\path\to\

REM ############### CHANGES FROM THIS POINT, ONLY IF YOU MUST ###############
REM The complete logfile
set TS_LF=%WD%mktest.log

REM My maker is set, get on with it
IF DEFINED MK GOTO NoSet

:_GCC
    IF NOT "%CCTYPE%"=="GCC" GOTO _BCC
    set MK=dmake
    IF NOT "%GCC_VERSION%"=="" GOTO Smoke
REM A Windows way to set GCC_VERSION
:GCC_V2_95
    gcc --version | find "2.95" > NUL: 2>&1
    IF ERRORLEVEL 1 GOTO GCC_V3
    FOR /F "usebackq" %%V IN (`gcc --version`) DO set GCC_VERSION=%%V
goto Smoke
:GCC_V3
    FOR /F "usebackq delims=" %%V IN (`gcc --version`) DO ((ECHO %%V | find "gcc">NUL: 2>&1) && (IF NOT ERRORLEVEL 1 set GCC_VERSION=%%V))

    IF "%GCC_VERSION%"=="" set GCC_VERSION=unknown
GOTO Smoke

:_BCC
    IF NOT "%CCTYPE%"=="BORLAND" GOTO _MSVC
    set MK=dmake
    IF NOT "%BCC_VERSION%"=="" set GCC_VERSION=%BCC_VERSION%
GOTO Smoke

:_MSVC
    REM Check if %CCTYPE% contains MSVC, FIND.EXE will exit(1) if not
    ECHO %CCTYPE% | find "MSVC" > NUL: 2>&1
    IF ERRORLEVEL 1 GOTO Error

    REM Use NMAKE.EXE as default maker for %CCTYPE%
    set MK=nmake
    IF NOT "%CL_VERSION%"=="" set GCC_VERSION=%CL_VERSION%
GOTO Smoke

:NoSet
    ECHO Skipping maker settings(%MK%/%CCTYPE%)...

:Smoke
    ECHO Smoke %TS_BD%
    REM Sanity Check ...
    IF NOT EXIST %TS_BD% (ECHO Can't find %TS_BD%) && GOTO Exit
    
    ECHO Smokelog: builddir is %TS_BD% > %TS_LF%
    PUSHD %TS_BD% > NUL: 2>&1
    IF ERRORLEVEL 1 GOTO Exit

    REM Prepare the source-tree
    (PUSHD win32) && (%MK% -i distclean >NUL: 2>&1) && (POPD)

    IF /I "%1"=="nofetch" (ECHO Skipped rsync) && shift && GOTO _MKTEST
    perl -e "sleep(rand(600))"
    REM We now use the synctree.pl script
    perl %WD%synctree.pl %SYNCARGS% >>%TS_LF%% 2>&1

:_MKTEST
    IF EXIST %WD%patchperl.bat CALL %WD%patchperl
    IF /I "%1"=="nosmoke" shift && GOTO _MKOVZ

    IF "%GCC_VERSION%"=="" goto _SET_OSVERSION
    IF "%CCTYPE%"=="GCC" (set GCC_VERSION=gccversion=%GCC_VERSION%) && goto _SET_OSVERSION
    set GCC_VERSION=ccversion=%GCC_VERSION%
:_SET_OSVERSION
    IF NOT "%OS_VERSION%"==""  set OS_VERSION=osvers=%OS_VERSION%

    REM Configure, build and test
    perl %WD%mktest.pl -m %MK% -c %CCTYPE% -v 1 %WD%%TS_CF% "%GCC_VERSION%" "%OS_VERSION%" >>%TS_LF% 2>&1
    IF ERRORLEVEL 1 ECHO mktest.pl exited with code %ERRORLEVEL%

:_MKOVZ
    IF /I "%1"=="noreport" shift && GOTO _MAILRPT
    REM Create the report and send to: <smokers-reports@perl.org>
    perl %WD%/mkovz.pl noemail %TS_DB%
    IF ERRORLEVEL 1 ECHO mkovz.pl  exited with code %ERRORLEVEL%

:_MAILRPT
    IF /I "%1"=="nomail" shift && GOTO Exit
    REM Send the report
    perl %WD%mailrpt.pl %MAILARGS% >>%TS_LF% 2>&1
GOTO Exit

:Usage
    ECHO Welcome to "perl core smoke suite"
    ECHO.
    ECHO Usage: %0 [nofetch[ nosmoke[ noreport]]] 
    ECHO.
    ECHO Arguments *must* be in the right order.
    ECHO Any argument can be ommitted.
    ECHO.
    ECHO Have fun!
GOTO Exit

:Error
    ECHO Unknown C Compiler (%CCTYPE%), use [BORLAND,GCC,MSVC,MSVC20,MSVC60]

:Exit
    set MK=
    set CCTYPE=
    set GCC_VERSION=
    set BCC_VERSION=
    set CL_VERSION=
    set OS_VERSION=
    set TS_BD=
    set TS_CF=
    set TS_LF=
    set WD=
    set SYNCARGS=
    set SMTP=
    set EMAIL=
    set MAILARGS=
    POPD
