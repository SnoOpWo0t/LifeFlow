Write-Host "Starting LifeFlow Services..." -ForegroundColor Green

# Start Laravel API in a new window
Write-Host "Launching Laravel Backend (Port 8000)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd lifeflow-api; `$env:Path += ';C:\laragon\bin\php\php-8.3.30-Win32-vs16-x64'; php artisan serve"

# Start Flutter App in a new window
Write-Host "Launching Flutter Frontend (Port 8080)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd lifeflow_app; `$env:Path += ';f:\LifeFlow\flutter\bin'; flutter run -d web-server --web-port 8080"

Write-Host "Both servers are now starting in separate windows!" -ForegroundColor Green
Write-Host "You can view your app at: http://localhost:8080" -ForegroundColor Yellow
