# 04 — Android ve Performans

Sürüm: v1.12.2 · 2026-11-11. **Hiçbir performans ölçümü yapılmadı** (cihaz/emülatör yok). Aşağıdakiler yapılandırma okumasıdır (KOD), ölçüm değil.

## Yapılandırma (KOD)
| Başlık | Değer | Yorum |
|---|---|---|
| Renderer | GL Compatibility | Düşük/orta cihazlarda uyumlu seçim |
| Mimari | yalnız arm64-v8a | 32-bit cihaz kapsam dışı |
| Gradle build | açık; `compress_native_libraries=false` | 16 KB için olumlu, doğrulanmadı |
| SDK | compile 36 / min 24 / target 36 | Play hedef API şartı karşılıyor görünüyor |
| Ekran | immersive_mode=true | Çentik/kesim davranışı test edilmedi |
| İzinler | INTERNET, VIBRATE | INTERNET yalnız güncelleme denetimi |
| Biçim | APK (`export_format=0`) | Play için AAB gerekir |

## Statik performans notları
- P4: `player_controller` ve `room_transition` kare başı grup sorguları yapıyor (BUG-050).
- P4: her ölümde yeni Shader oluşturuluyor (BUG-051).
- `update_checker` ana iş parçacığını bloklamıyor (async, 8 sn).

## Ölçülmemiş
| Metrik | Durum |
|---|---|
| FPS / kare süresi (düşük, orta, üst cihaz) | TEST EDİLMEDİ |
| Bellek, tepe RAM, bellek sızıntısı (uzun oturum) | TEST EDİLMEDİ |
| Açılış süresi | TEST EDİLMEDİ |
| Pil/ısınma | TEST EDİLMEDİ |
| APK/AAB boyutu | Derlenmiş çıktı bu oturumda yok |
| 16 KB sayfa hizalama (`zipalign -c -P 16`) | TEST EDİLMEDİ |
| Manifest `targetSdkVersion` | TEST EDİLMEDİ |
| Arka plan/ön plan, çağrı kesintisi, döndürme | TEST EDİLMEDİ |
| Çoklu dokunuş + joystick | TEST EDİLMEDİ |
| Düşük bellekte kayıt bütünlüğü (BUG-030/033) | TEST EDİLMEDİ |

## Önerilen doğrulama (sıralı)
1. `export_format=1` ile AAB; APK'yı da derle.
2. `aapt2 dump badging` → `targetSdkVersion=36`; `zipalign -c -P 16 -v 4`.
3. Emülatör (API 36, 16 KB image) açılış + temel tur; ardından gerçek cihaz.
4. 30 dk kesintisiz oynama: `dumpsys gfxinfo`, `dumpsys meminfo`, `adb logcat -b crash`.
5. Sonuçları bu dosyaya, cihaz modeli/Android sürümüyle yaz.
