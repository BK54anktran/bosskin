@echo off
rem Reset dev database: stop backend, wipe schema, re-run migrations, bootstrap sysadmin from backend\.env
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop.ps1" backend
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" backend -ResetDb
