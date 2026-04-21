@echo off
REM Run every spec\*_spec.lua under luajit.exe.
setlocal enabledelayedexpansion
set "LUAJIT=luajit"
where luajit >nul 2>&1 || set "LUAJIT=%LOCALAPPDATA%\Programs\LuaJIT\bin\luajit.exe"
if not exist "%LUAJIT%" (
  echo [test.bat] luajit.exe not found. Run: winget install DEVCOM.LuaJIT
  exit /b 2
)

pushd "%~dp0.."
set FAIL=0
set RAN=0
for %%f in (spec\*_spec.lua) do (
  echo === %%f ===
  "%LUAJIT%" "%%f"
  if !errorlevel! neq 0 set FAIL=1
  set /a RAN+=1
)
popd

if %RAN% equ 0 (
  echo [test.bat] no spec files matched.
  exit /b 3
)
if %FAIL% neq 0 (
  echo.
  echo [test.bat] FAILED
  exit /b 1
)
echo.
echo [test.bat] all specs passed.
