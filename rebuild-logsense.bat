@echo off
cd /d "%~dp0"

echo Rebuilding LogSense...

pushd D:\javaworkspace\logsense-ai-backend
docker build --no-cache -t logsense-ai-backend:1.0.0 --secret id=maven_settings,src=C:\Users\%USERNAME%\.m2\settings.xml .
if %errorlevel% neq 0 ( popd & echo [ERROR] Backend build failed. & pause & exit /b 1 )
popd

pushd D:\reactproject\logsense-ai-frontend
docker build --no-cache -t logsense-ai-frontend:1.0.0 .
if %errorlevel% neq 0 ( popd & echo [ERROR] Frontend build failed. & pause & exit /b 1 )
popd

echo Forcing pod restart...
kubectl patch deployment logsense-ai-backend  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"
kubectl patch deployment logsense-ai-frontend -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"

kubectl rollout status deployment/logsense-ai-backend  --timeout=120s
kubectl rollout status deployment/logsense-ai-frontend --timeout=120s

kubectl get pods -l app=logsense-ai-backend
kubectl get pods -l app=logsense-ai-frontend
pause