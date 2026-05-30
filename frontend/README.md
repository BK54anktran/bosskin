# Bosskin — Frontend

Ứng dụng quản lý nhân sự xây dựng bằng Flutter, kết nối backend Spring Boot.

---

## Yêu cầu

| Tool | Phiên bản |
|---|---|
| Flutter | ≥ 3.22 |
| Dart | ≥ 3.4 |
| Android SDK | API 34+ (để build Android) |
| Xcode | ≥ 15 (để build iOS/macOS) |
| Android NDK | 27.0.12077973 |

---

## Cấu hình server

Địa chỉ server được lưu trong `SharedPreferences` — **không cần hardcode**.

**Lần đầu / đổi server:** mở app → màn hình Login → nhấn icon ⚙ góc trên phải → nhập địa chỉ `http://<IP>:8080` → Lưu.

Hoặc sửa giá trị mặc định tại:
```
lib/core/config/server_config.dart  →  static const _defaultHost = 'http://<IP>:8080';
```

---

## Cài dependencies

```bash
flutter pub get
```

---

## Chạy development

```bash
# Web
flutter run -d chrome

# Windows desktop
flutter run -d windows

# Android (kết nối thiết bị / mở emulator trước)
flutter run -d android

# iOS (macOS + Xcode)
flutter run -d ios
```

---

## Build release

### Android (APK)

```bash
# Cài Android SDK nếu chưa có (Linux/WSL)
mkdir -p ~/Android/Sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdtools.zip
unzip /tmp/cmdtools.zip -d /tmp/ct && mv /tmp/ct/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
export ANDROID_HOME=~/Android/Sdk
yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Build APK
export ANDROID_HOME=~/Android/Sdk
flutter build apk --release

# Output
build/app/outputs/flutter-apk/app-release.apk
```

> **WSL:** backend chạy trong WSL cần forward port ra Windows:
> ```powershell
> # Chạy PowerShell với quyền Administrator
> netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8080 connectaddress=<WSL_IP> connectport=8080
> netsh advfirewall firewall add rule name="Spring Boot 8080" dir=in action=allow protocol=TCP localport=8080
> ```
> WSL IP lấy bằng: `hostname -I` trong WSL terminal.

---

### Android (AAB — Google Play)

```bash
flutter build appbundle --release

# Output
build/app/outputs/bundle/release/app-release.aab
```

---

### iOS (macOS + Xcode bắt buộc)

```bash
flutter build ios --release --no-codesign

# Để upload TestFlight/App Store cần signing certificate:
flutter build ipa --release
```

---

### Web

```bash
flutter build web --release

# Output: build/web/
# Deploy bằng bất kỳ web server (nginx, Firebase Hosting, v.v.)

# Preview nhanh
cd build/web && python3 -m http.server 8000
```

> **CORS:** khi chạy web, backend Spring Boot cần cho phép origin của web app.

---

### Windows Desktop

```bash
flutter build windows --release

# Output
build/windows/x64/runner/Release/bosskin.exe
```

> Yêu cầu: Visual Studio 2022 với workload **Desktop development with C++**.

---

### macOS Desktop (macOS bắt buộc)

```bash
flutter build macos --release

# Output
build/macos/Build/Products/Release/bosskin.app
```

---

### Linux Desktop

```bash
# Cài dependencies
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev

flutter build linux --release

# Output
build/linux/x64/release/bundle/bosskin
```

---

## Lưu ý chung

- Sau khi đổi địa chỉ server mặc định trong `server_config.dart`, cần build lại app.
- Android APK dùng HTTP (không HTTPS) — đã bật `android:usesCleartextTraffic="true"` trong `AndroidManifest.xml`.
- Mỗi lần khởi động lại máy tính khi dùng WSL2, IP WSL có thể thay đổi → cần chạy lại lệnh port forwarding hoặc dùng nút ⚙ trong app để cập nhật IP mới.
