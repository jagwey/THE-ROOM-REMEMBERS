# Android APK geçerliliği (v1.11.0)

Godot 4.7.2'nin **gradle'sız** dışa aktarımı (`gradle_build/use_gradle_build=false`) hazır APK şablonunun ikili manifestini yamalar. `export_plugin.cpp` içindeki `_fix_manifest`, **her** `<provider android:authorities>` değerini `<paket>.fileprovider` yapar. Böylece `androidx.startup.InitializationProvider` ile `FileProvider` aynı yetkiyi paylaşır. Aynı dışa aktarım `res/mipmap-anydpi-v26/themed_icon.xml` dosyasını paketten çıkarır; kaynak tablosu `@mipmap/themed_icon` istediği için telefon paketi geçersiz sayar («package appears to be invalid»).

## Bu depodaki düzeltme

Dışa aktarım Gradle ile yapılır. Şablon `android/build/` altındadır (Godot 4.7.2 `android_source.zip` ile aynı ağaç: `platform/android/java/app` + `gradlew`). Sürüm damgası `android/.build_version` = `4.7.2.stable`.

`android/build/src/main/AndroidManifest.xml` içinde InitializationProvider açıkça şöyle durur:

```xml
android:authorities="${applicationId}.androidx-startup"
tools:replace="android:authorities"
```

`FileProvider` kütüphane manifestinde `${applicationId}.fileprovider` olarak kalır; iki yetki çakışmaz.

`android/build/res/mipmap-anydpi-v26/themed_icon.xml` `@mipmap/icon_monochrome` ister. Bu webp, export sırasında yalnız `launcher_icons/adaptive_monochrome_432x432` doluysa yazılır. Preset:

```
launcher_icons/adaptive_monochrome_432x432="res://assets/icon/icon_foreground.png"
```

`export_presets.cfg`: `gradle_build/use_gradle_build=true`. Gradle'sız dışa aktarma manifest hatasını geri getirir; onu kapatma.

Kök `.gitignore` depo kökündeki `/build/` çıktısını yok sayar. `android/build` şablonu repoda durur. Gradle ara klasörleri (`android/build/build`, `android/build/.gradle`), şablon AAR'ları (`android/build/libs/`) ve export'un yazdığı ikon/çizim/`src/release` çıktıları yok sayılır. `src/main/assets/.gitignore` oyun paketini yutar.

Editörden **Install Android Build Template** çalıştırma. Zip, özelleştirilmiş `AndroidManifest.xml` dahil `android/build` ağacının üstüne yazılır. Yalnız aşağıdaki iki AAR kopyalanır.

## Derleme hatası

Temiz klonda `android/build/libs/` boştur (AAR'lar ~100 MB, repoda yok). `themed_icon.xml` monokrom ikona işaret ettiği ve AAR da olmadığı için Gradle kaynak bağlaması düşer:

```
Execution failed for task ':processStandardReleaseResources'.
Android resource linking failed
ERROR: android/build/res/mipmap-anydpi-v26/themed_icon.xml:10: AAPT: error: resource mipmap/icon_monochrome (aka com.torimon.theroomremembers:mipmap/icon_monochrome) not found.
```

Monokrom preset satırı Godot'un `res/mipmap*/icon_monochrome.webp` dosyalarını yazmasını sağlar; bu AAPT hatası kapanır. AAR hâlâ yoksa bir sonraki adım Java derlemesidir (`:compileStandardReleaseJavaWithJavac`):

```
GodotApp.java:33: error: package org.godotengine.godot does not exist
```

İkisi birden durunca `assembleStandardRelease` biter. Headless Godot 4.7.2 + JDK 17 + SDK 36 + NDK 29.0.14206865 ile bu ağaçta denendi.

## Dışa aktarma

Araçlar, `android/build/config.gradle` ile aynı sürümler:

- Godot 4.7.2 ve export templates `4.7.2.stable`
- JDK 17 (`export/android/java_sdk_path`; alt sınır 17)
- Android SDK (`export/android/android_sdk_path`): `platforms;android-36`, `build-tools;36.1.0`, `ndk;29.0.14206865`, `platform-tools`

Şablon AAR'ları (bir kez). Linux:

```bash
T="$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip"
mkdir -p android/build/libs/debug android/build/libs/release
unzip -j -o "$T" libs/debug/godot-lib.template_debug.aar -d android/build/libs/debug
unzip -j -o "$T" libs/release/godot-lib.template_release.aar -d android/build/libs/release
```

Windows (PowerShell, şablon yolu `%APPDATA%\Godot\export_templates\4.7.2.stable\android_source.zip`):

```powershell
$T = "$env:APPDATA\Godot\export_templates\4.7.2.stable\android_source.zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($T)
function Copy-ZipEntry([string]$entryName, [string]$dest) {
    $e = $zip.GetEntry($entryName)
    if (-not $e) { throw "Zip icinde yok: $entryName" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
}
Copy-ZipEntry "libs/debug/godot-lib.template_debug.aar" (Join-Path (Get-Location) "android\build\libs\debug\godot-lib.template_debug.aar")
Copy-ZipEntry "libs/release/godot-lib.template_release.aar" (Join-Path (Get-Location) "android\build\libs\release\godot-lib.template_release.aar")
$zip.Dispose()
```

Yayın imzası sahibinin anahtarıdır (CN=Jagwey, O=Jagwey Games). Anahtar dosyası ve parola repoya yazılmaz. Headless release export ortam değişkenlerini okur:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

```bash
godot --headless --path . --export-release "Android" build/android/TheRoomRemembers-1.11.0.apk
```

Çıktı versionCode 36, paket `com.torimon.theroomremembers`, yalnız `arm64-v8a`.

## Doğrulama

`aapt2` build-tools 36.1.0 içindedir.

```bash
aapt2 dump xmltree --file AndroidManifest.xml build/android/TheRoomRemembers-1.11.0.apk
aapt2 dump resources build/android/TheRoomRemembers-1.11.0.apk
apksigner verify --verbose --print-certs build/android/TheRoomRemembers-1.11.0.apk
zipalign -c -p 4 build/android/TheRoomRemembers-1.11.0.apk
```

Beklenen:

- `androidx.startup.InitializationProvider` yetkisi `com.torimon.theroomremembers.androidx-startup`
- `androidx.core.content.FileProvider` yetkisi `com.torimon.theroomremembers.fileprovider`
- Aynı yetki iki kez geçmez
- `mipmap/themed_icon` `(anydpi-v26) (file) res/<ad>.xml` satırına iner; o dosya APK içindedir ve `@mipmap/icon_monochrome` mevcut bir `res/*.webp` dosyasına bağlanır
- `apksigner verify` v2 imzayı doğrular

Bu ortamda atılan deneme anahtarı (CN=Throwaway Verify) yalnız doğrulama içindir; yayın APK'sı onunla imzalanmaz.
