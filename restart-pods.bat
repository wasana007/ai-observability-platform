REM restart-pods.bat
@echo off
kubectl rollout restart deployment/logsense-ai-backend
kubectl rollout restart deployment/logsense-ai-frontend
kubectl rollout restart deployment/logsense-admin
kubectl rollout restart deployment/payroll-backend
kubectl rollout restart deployment/payroll-frontend
kubectl get pods
pause