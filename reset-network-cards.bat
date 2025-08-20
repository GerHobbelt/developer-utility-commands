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

) else (

echo "**********************************************************"
echo "ERROR: you must run this batch file as    Administrator  !"
echo "**********************************************************"

)

pause


