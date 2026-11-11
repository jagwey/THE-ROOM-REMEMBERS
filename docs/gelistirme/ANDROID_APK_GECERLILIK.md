# Android APK geçerliliği (v1.11.0)

Godot 4.7.2'nin **gradle'sız** dışa aktarımı (`gradle_build/use_gradle_build=false`) hazır APK şablonunun ikili manifestini yamalar. `export_plugin.cpp` içindeki `_fix_manifest`, **her** `<provider android:authorities>` değerini `<paket>.fileprovider` yapar. Böylece `androidx.startup.InitializationProvider` ile `FileProvider` aynı yetkiyi paylaşır. Aynı dışa aktarım `res/mipmap-anydpi-v26/themed_icon.xml` dosyasını paketten çıkarır; manifest `@mipmap/themed_icon` istediği için telefon paketi geçersiz sayar («package appears to be invalid»).

## Bu depodaki düzeltme

Dışa aktarım Gradle ile yapılır. Şablon `android/build/` altındadır (Godot 4.7.2 `android_source.zip` ile aynı ağaç: `platform/android/java/app` + `gradlew`). Sürüm damgası `android/.build_version` = `4.7.2.stable`.

`android/build/src/main/AndroidManifest.xml` içinde InitializationProvider açıkça şöyle durur:

```xml
android:authorities="${applicationId}.androidx-startup"
tools:replace="android:authorities"
```

`FileProvider` kütüphane manifestinde `${applicationId}.fileprovider` olarak kalır; iki yetki çakışmaz.

`android/build/res/mipmap-anydpi-v26/themed_icon.xml` pakete girer. Manifest `@mipmap/themed_icon` istese de kaynak eksik kalmaz.

`export_presets.cfg`: `gradle_build/use_gradle_build=true`. Gradle'sız dışa aktarma bu hatayı geri getirir; onu kapatma.

Kök `.gitignore` yalnız depo kökündeki `/build/` çıktısını yok sayar. `android/build` şablonu repoda durur. Gradle'ın kendi ara klasörleri (`android/build/build`, `android/build/.gradle`) yine yok sayılır.

## Dışa aktarma

Godot 4.7.2 düzenleyicisinde Android SDK ve JDK yolları ayarlı olmalı (Editör Ayarları → Export → Android). İlk kez şablon istenirse Project menüsünden yeniden kurma gerekmez; `android/build` zaten duruyor. Çıktı: `build/android/TheRoomRemembers-1.11.0.apk` (versionCode 36).

İmza anahtarı ve şifresi bu depoya yazılmaz.
