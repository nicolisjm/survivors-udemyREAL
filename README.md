# survivors-udemy

## Android APK Export

### Prerequisites

1. **OpenJDK 17** - [Download from Adoptium](https://adoptium.net/temurin/releases/?variant=openjdk17&version=17)
2. **Android SDK** - Install via [Android Studio](https://developer.android.com/studio/) or sdkmanager. Required packages:
   - platform-tools (35.0.0+)
   - build-tools (35.0.1)
   - platforms;android-35
   - NDK r28b
   - CMake 3.10.2.4988404
3. **Godot Editor Settings** - Set paths under Editor > Editor Settings > Export > Android:
   - **Java SDK Path** - OpenJDK 17 install location
   - **Android SDK Path** - e.g. `%LOCALAPPDATA%\Android\Sdk` on Windows

### Export Steps

1. Open the project in Godot
2. Go to **Project > Export**
3. Select the **Android** preset
4. Set **Export Path** (e.g. `build/SurvivorsUdemy.apk`)
5. Click **Export Project** and choose the output location

### Command-line Export

```bash
godot --headless --export-release "Android" "build/SurvivorsUdemy.apk"
```

Create the `build` folder first if it does not exist.

