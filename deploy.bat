@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo   QLVA - Dong bo va Deploy len Firebase Hosting
echo ============================================
echo.
echo   1. Chi deploy TEST      (qlahs-test.web.app)
echo   2. Chi deploy PRODUCTION (qlahsp2.web.app - DU LIEU THAT)
echo   3. Deploy CA HAI (test truoc, production sau)
echo   0. Huy
echo.
set /p chon="Chon (1/2/3/0): "

if "%chon%"=="1" goto test
if "%chon%"=="2" goto prod
if "%chon%"=="3" goto both
goto end

:test
echo.
echo Dang dong bo qlva-dev.html va deploy len TEST...
if not exist public-test mkdir public-test
copy /Y qlva-dev.html public-test\index.html >nul
call firebase deploy --only hosting:test --project test
goto end

:prod
echo.
echo CANH BAO: Ban sap deploy len PRODUCTION - du lieu that, moi nguoi dang dung.
set /p xn="Go YES roi Enter de xac nhan: "
if not "%xn%"=="YES" (
  echo Da huy, khong deploy gi ca.
  goto end
)
echo Dang dong bo qlva.html va deploy len PRODUCTION...
if not exist public-prod mkdir public-prod
copy /Y qlva.html public-prod\index.html >nul
call firebase deploy --only hosting:prod --project prod
goto end

:both
echo.
echo Dang dong bo qlva-dev.html va deploy len TEST...
if not exist public-test mkdir public-test
copy /Y qlva-dev.html public-test\index.html >nul
call firebase deploy --only hosting:test --project test
echo.
echo CANH BAO: Chuan bi deploy len PRODUCTION - du lieu that, moi nguoi dang dung.
set /p xn="Go YES roi Enter de xac nhan: "
if not "%xn%"=="YES" (
  echo Da huy deploy PRODUCTION. TEST da deploy xong o tren.
  goto end
)
echo Dang dong bo qlva.html va deploy len PRODUCTION...
if not exist public-prod mkdir public-prod
copy /Y qlva.html public-prod\index.html >nul
call firebase deploy --only hosting:prod --project prod
goto end

:end
echo.
pause
