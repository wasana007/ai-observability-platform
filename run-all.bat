@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo =========================================
echo   AI OBSERVABILITY PLATFORM STARTER
echo =========================================

REM -----------------------------
REM CONFIGURATION
REM -----------------------------
set LOGSENSE_BACKEND_DIR=D:\javaworkspace\logsense-ai-backend
set LOGSENSE_FRONTEND_DIR=D:\reactproject\logsense-ai-frontend
set LOGSENSE_ADMIN_DIR=D:\reactproject\logsense-admin
set PAYROLL_BACKEND_DIR=D:\javaworkspace\payroll-backend
set PAYROLL_FRONTEND_DIR=D:\reactproject\payroll-frontend

set K8S_DIR=D:\ai-observability-platform\k8s

set LOGSENSE_BACKEND_IMAGE=logsense-ai-backend:1.0.0
set LOGSENSE_FRONTEND_IMAGE=logsense-ai-frontend:1.0.0
set LOGSENSE_ADMIN_IMAGE=logsense-admin:1.0.0
set PAYROLL_BACKEND_IMAGE=payroll-backend:1.0.0
set PAYROLL_FRONTEND_IMAGE=payroll-frontend:1.0.0

REM -----------------------------
REM VALIDATE
REM -----------------------------
echo Validating...
if not exist "%LOGSENSE_BACKEND_DIR%" ( echo [ERROR] %LOGSENSE_BACKEND_DIR% not found & goto error )
if not exist "%LOGSENSE_FRONTEND_DIR%" ( echo [ERROR] %LOGSENSE_FRONTEND_DIR% not found & goto error )
if not exist "%LOGSENSE_ADMIN_DIR%" ( echo [ERROR] %LOGSENSE_ADMIN_DIR% not found & goto error )
if not exist "%PAYROLL_BACKEND_DIR%" ( echo [ERROR] %PAYROLL_BACKEND_DIR% not found & goto error )
if not exist "%PAYROLL_FRONTEND_DIR%" ( echo [ERROR] %PAYROLL_FRONTEND_DIR% not found & goto error )
if not exist "%K8S_DIR%" ( echo [ERROR] %K8S_DIR% not found & goto error )
echo OK.

REM -----------------------------
REM INFRA
REM -----------------------------
echo.
echo Starting docker-compose...
docker-compose up -d
if errorlevel 1 goto error
timeout /t 10 >nul

REM -----------------------------
REM PULL ELASTIC IMAGES
REM -----------------------------
echo.
echo Checking Elasticsearch image...
docker image inspect docker.elastic.co/elasticsearch/elasticsearch:8.12.0 >nul 2>&1
if errorlevel 1 (
    echo Pulling Elasticsearch image - this may take a while...
    docker pull docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    echo [OK] Elasticsearch image ready.
) else (
    echo [OK] Elasticsearch image already exists, skipping pull.
)

echo Checking Kibana image...
docker image inspect docker.elastic.co/kibana/kibana:8.12.0 >nul 2>&1
if errorlevel 1 (
    echo Pulling Kibana image - this may take a while...
    docker pull docker.elastic.co/kibana/kibana:8.12.0
    echo [OK] Kibana image ready.
) else (
    echo [OK] Kibana image already exists, skipping pull.
)

REM -----------------------------
REM BUILD IMAGES
REM -----------------------------
echo.
echo =========================================
echo  BUILDING DOCKER IMAGES
echo =========================================

echo Building logsense-ai-backend...
pushd "%LOGSENSE_BACKEND_DIR%"
docker build --no-cache -t %LOGSENSE_BACKEND_IMAGE% --secret id=maven_settings,src=C:\Users\%USERNAME%\.m2\settings.xml .
if !errorlevel! neq 0 ( popd & echo [ERROR] logsense-ai-backend failed. & goto error )
popd
echo [OK] logsense-ai-backend done.

echo Building logsense-ai-frontend...
pushd "%LOGSENSE_FRONTEND_DIR%"
docker build --no-cache -t %LOGSENSE_FRONTEND_IMAGE% .
if !errorlevel! neq 0 ( popd & echo [ERROR] logsense-ai-frontend failed. & goto error )
popd
echo [OK] logsense-ai-frontend done.

echo Building logsense-admin...
pushd "%LOGSENSE_ADMIN_DIR%"
docker build --no-cache -t %LOGSENSE_ADMIN_IMAGE% .
if !errorlevel! neq 0 ( popd & echo [ERROR] logsense-admin failed. & goto error )
popd
echo [OK] logsense-admin done.

echo Building payroll-backend...
pushd "%PAYROLL_BACKEND_DIR%"
docker build --no-cache -t %PAYROLL_BACKEND_IMAGE% --secret id=maven_settings,src=C:\Users\%USERNAME%\.m2\settings.xml .
if !errorlevel! neq 0 ( popd & echo [ERROR] payroll-backend failed. & goto error )
popd
echo [OK] payroll-backend done.

echo Building payroll-frontend...
pushd "%PAYROLL_FRONTEND_DIR%"
docker build --no-cache -t %PAYROLL_FRONTEND_IMAGE% .
if !errorlevel! neq 0 ( popd & echo [ERROR] payroll-frontend failed. & goto error )
popd
echo [OK] payroll-frontend done.

REM -----------------------------
REM CREATE SECRETS
REM -----------------------------
echo.
echo Creating Kubernetes secrets...
kubectl create secret generic app-secrets ^
  --from-env-file=%LOGSENSE_BACKEND_DIR%\.env ^
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic payroll-secrets ^
  --from-env-file=%PAYROLL_BACKEND_DIR%\.env ^
  --dry-run=client -o yaml | kubectl apply -f -

REM -----------------------------
REM DEPLOY K8S
REM -----------------------------
echo.
echo Deploying Kubernetes apps...
kubectl apply -f "%K8S_DIR%"
if errorlevel 1 goto error

REM -----------------------------
REM FORCE POD RESTART
REM -----------------------------
echo.
echo Forcing pod restart with new images...
kubectl patch deployment logsense-ai-backend  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"
kubectl patch deployment logsense-ai-frontend -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"
kubectl patch deployment logsense-admin       -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"
kubectl patch deployment payroll-backend       -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"
kubectl patch deployment payroll-frontend      -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollme\":\"%TIME%\"}}}}}"

REM -----------------------------
REM WAIT PODS
REM -----------------------------
echo.
echo Waiting pods...
kubectl wait --for=condition=Ready pod -l app=logsense-ai-backend  --timeout=180s
kubectl wait --for=condition=Ready pod -l app=logsense-ai-frontend --timeout=180s
kubectl wait --for=condition=Ready pod -l app=logsense-admin       --timeout=180s
kubectl wait --for=condition=Ready pod -l app=payroll-backend      --timeout=180s
kubectl wait --for=condition=Ready pod -l app=payroll-frontend     --timeout=180s

REM -----------------------------
REM OLLAMA MODEL
REM -----------------------------
echo.
echo Checking Ollama model...
kubectl wait --for=condition=Ready pod -l app=ollama --timeout=120s

kubectl exec deployment/ollama -- ollama list | findstr "llama3.2" > nul
if errorlevel 1 (
    echo Pulling llama3.2 - this may take a while...
    kubectl exec deployment/ollama -- ollama pull llama3.2
    echo [OK] llama3.2 ready.
) else (
    echo [OK] llama3.2 already exists, skipping pull.
)

REM -----------------------------
REM STATUS
REM -----------------------------
echo.
echo =========================================
echo  POD STATUS
echo =========================================
kubectl get pods -o wide

echo.
echo =========================================
echo  SERVICE STATUS
echo =========================================
kubectl get svc

REM -----------------------------
REM PORT FORWARD
REM -----------------------------
echo.
echo Starting port-forward...
call :free_port 3000
call :free_port 5173
call :free_port 8080
call :free_port 3001
call :free_port 8282
call :free_port 9200
call :free_port 5601

start "LogSense UI"         cmd /k kubectl port-forward service/logsense-ai-frontend-service  3000:80
start "LogSense Admin UI"   cmd /k kubectl port-forward service/logsense-admin-service        5173:80
start "LogSense API"        cmd /k kubectl port-forward service/logsense-ai-backend-service   8080:8080
start "Payroll UI"          cmd /k kubectl port-forward service/payroll-frontend-service      3001:80
start "Payroll API"         cmd /k kubectl port-forward service/payroll-backend-service       8282:8282
start "Elasticsearch"       cmd /k kubectl port-forward service/elasticsearch-service         9200:9200
start "Kibana"              cmd /k kubectl port-forward service/kibana-service                5601:5601

timeout /t 3 /nobreak >nul

echo.
echo =========================================
echo  SYSTEM READY
echo =========================================
echo  LogSense UI         ^>^>  http://localhost:3000
echo  LogSense Admin UI   ^>^>  http://localhost:5173
echo  LogSense API        ^>^>  http://localhost:8080
echo  Payroll UI          ^>^>  http://localhost:3001
echo  Payroll API         ^>^>  http://localhost:8282
echo  Elasticsearch       ^>^>  http://localhost:9200
echo  Kibana              ^>^>  http://localhost:5601
echo =========================================
pause
exit /b 0

REM =====================================================
REM FUNCTIONS
REM =====================================================
:free_port
set PORT=%1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%PORT% ^| findstr LISTENING') do (
    echo Killing PID %%a on port %PORT%
    taskkill /F /PID %%a >nul 2>&1
)
exit /b

:error
echo.
echo [ERROR] Something failed.
pause
exit /b 1