@echo off
cd /d "%~dp0"

echo Rebuilding Payroll...

pushd D:\javaworkspace\payroll-backend
docker build --no-cache -t payroll-backend:1.0.0 --secret id=maven_settings,src=C:\Users\%USERNAME%\.m2\settings.xml .
if %errorlevel% neq 0 ( popd & echo [ERROR] Backend build failed. & pause & exit /b 1 )
popd

pushd D:\reactproject\payroll-frontend
docker build --no-cache -t payroll-frontend:1.0.0 .
if %errorlevel% neq 0 ( popd & echo [ERROR] Frontend build failed. & pause & exit /b 1 )
popd

echo Forcing pod restart...
kubectl patch deployment payroll-backend  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"
kubectl patch deployment payroll-frontend -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"

kubectl rollout status deployment/payroll-backend  --timeout=120s
kubectl rollout status deployment/payroll-frontend --timeout=120s

kubectl get pods -l app=payroll-backend
kubectl get pods -l app=payroll-frontend
pause