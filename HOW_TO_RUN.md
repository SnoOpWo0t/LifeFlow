# How to Run LifeFlow Locally (Windows)

Since this project consists of two separate systems (the Laravel API Backend and the Flutter Frontend) and uses specific local installations for PHP and Flutter, the paths must be set correctly. 

## 🚀 The Easy Way (One-Click Start)
I have created a helper script for you. You don't have to open multiple terminals or remember paths manually anymore!

1. Open PowerShell in the root folder (`f:\LifeFlow`)
2. Run this single command:
   ```powershell
   .\start.ps1
   ```
This will automatically pop open two new terminal windows, set all the correct paths for you, and boot up both the Laravel server and the Flutter web app simultaneously!

---

## 🛠️ The Manual Way (Terminal 1 - Laravel)

Whenever you restart your computer or close your terminal, you need to tell PowerShell where PHP is installed before you can run `php artisan serve`.

1. Open a new PowerShell terminal.
2. Navigate to the API folder:
   ```powershell
   cd f:\LifeFlow\lifeflow-api
   ```
3. Add your local PHP installation to the Path:
   ```powershell
   $env:Path += ";C:\laragon\bin\php\php-8.3.30-Win32-vs16-x64"
   ```
4. Start the server:
   ```powershell
   php artisan serve
   ```
*Leave this terminal open. The API is now running on `http://127.0.0.1:8000`.*

---

## 📱 2. Start the Flutter Frontend (Terminal 2)

You have a local installation of Flutter that needs to be added to the path as well. Open a **second, brand new PowerShell terminal**.

1. Navigate to the Flutter app folder:
   ```powershell
   cd f:\LifeFlow\lifeflow_app
   ```
2. Add your local Flutter installation to the Path:
   ```powershell
   $env:Path += ";f:\LifeFlow\flutter\bin"
   ```

Now you have two choices for how to run the app:

### Option A: Development Mode (Hot Reload)
If you are writing code and want the browser to instantly update when you save a file, run this:
```powershell
flutter run -d chrome
```

### Option B: Production Build (Fastest Performance)
If you just want to view the app quickly (like a user would) using the Python server we set up previously:
```powershell
flutter build web
cd build\web
python -m http.server 8080
```
*You can then view the app by opening `http://localhost:8080` in your web browser.*

---

## 💡 Troubleshooting
* **"php is not recognized"** - This means you forgot to run Step 3 in Terminal 1.
* **"flutter is not recognized"** - This means you forgot to run Step 2 in Terminal 2.
* **"Failed to load resource: net::ERR_CONNECTION_REFUSED"** - Your Flutter app is running, but your Laravel API (Terminal 1) is closed or stopped.
