@echo off
REM Security Rules Testing Script for Windows
REM This script helps test Firestore and Realtime Database security rules

echo ==========================================
echo Firebase Security Rules Testing
echo ==========================================
echo.

REM Check if Firebase CLI is installed
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X Firebase CLI is not installed.
    echo Please install it with: npm install -g firebase-tools
    exit /b 1
)

echo √ Firebase CLI is installed
echo.

REM Check if user is logged in
firebase projects:list >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X Not logged in to Firebase.
    echo Please login with: firebase login
    exit /b 1
)

echo √ Logged in to Firebase
echo.

REM Display menu
echo Select an option:
echo 1. Start Firebase Emulators
echo 2. Start Emulators with fresh data
echo 3. Deploy security rules to Firebase
echo 4. Run unit tests
echo 5. Exit
echo.
set /p choice="Enter your choice (1-5): "

if "%choice%"=="1" goto start_emulators
if "%choice%"=="2" goto start_emulators_fresh
if "%choice%"=="3" goto deploy_rules
if "%choice%"=="4" goto run_tests
if "%choice%"=="5" goto exit_script
goto invalid_choice

:start_emulators
echo.
echo Starting Firebase Emulators...
echo Firestore: http://localhost:8080
echo Realtime Database: http://localhost:9000
echo Emulator UI: http://localhost:4000
echo.
firebase emulators:start
goto end

:start_emulators_fresh
echo.
echo Starting Firebase Emulators with fresh data...
firebase emulators:start --clear-data
goto end

:deploy_rules
echo.
set /p confirm="Are you sure you want to deploy to production? (yes/no): "
if /i "%confirm%"=="yes" (
    echo Deploying security rules to Firebase...
    firebase deploy --only firestore:rules,database
    echo √ Security rules deployed successfully
) else (
    echo Deployment cancelled
)
goto end

:run_tests
echo.
echo Running unit tests...
flutter test test/firestore_security_rules_test.dart
goto end

:exit_script
echo Exiting...
exit /b 0

:invalid_choice
echo Invalid choice. Please run the script again.
exit /b 1

:end
echo.
pause
