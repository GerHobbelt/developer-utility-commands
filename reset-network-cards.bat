@echo off
rem
rem
rem

net session >nul 2>nul
if %ErrorLevel% == 0 (

echo "Resetting network cards in Administrator mode"

@echo on

netsh winsock reset

netsh int ip reset

netsh int ip delete destinationcache

ipconfig /release

ipconfig /renew

ipconfig /flushdns

ipconfig /registerdns





netsh winsock reset

netsh int ip reset

ipconfig /release

ipconfig /renew

ipconfig /flushdns

ipconfig /registerdns

@echo off

echo "**********************************************************"
echo "WARNING: when using NordVPN, be sure to run the NordVPN diagnostics tool and click the [Reset Network] button there!"
echo "**********************************************************"

if exist "C:\\Program Files\\NordVPN\\Diagnostics\\NordSecurity.NordVpn.DiagnosticsTool.Application.exe" (
	"C:\\Program Files\\NordVPN\\Diagnostics\\NordSecurity.NordVpn.DiagnosticsTool.Application.exe"
)

) else (

@echo off

echo ************************************************************
echo WARNING: you must run this batch file as    Administrator  !
echo ************************************************************

echo.
echo BATCH FILE TO RUN:
echo.
echo %0 | sed -E -e 's/Z:/    I:\\\\Z/' -e 's/"//g'
echo.

rem
rem This does not work on Windows 10:
rem
rem     runas /noprofile /user:%COMPUTERNAME%\administrator cmd /D /C %0
rem

)

pause


