# 00 — Baseline

Sürüm: **v1.12.2** · commit `84a2032` (main, `origin/main` ile eşit) · tarih: 2026-11-11
Motor: Godot 4.7.2 (GL Compatibility) · Paket: com.torimon.theroomremembers · Android arm64

## Kanıt sınıfları
KOD (statik okuma) · HEADLESS (Godot `--headless` betiği) · PENCERELİ · EMÜLATÖR · CİHAZ · İNSAN · RİSK (doğrulanmamış).
Bu belgedeki tüm "PASS" sonuçları yalnız **HEADLESS** sınıfındadır. Pencereli, emülatör, cihaz ve insan oyun testi bu oturumda **yapılmadı**.

## Sürüm bilgisi (export_presets.cfg / project.godot)
| Alan | Değer |
|---|---|
| version/code · version/name | 39 · 1.12.2 |
| export_format | 0 (APK, AAB değil) |
| Mimari | yalnız arm64-v8a |
| compileSdk / minSdk / targetSdk (gradle) | 36 / 24 / 36 |
| min_sdk / target_sdk (preset) | boş (şablon belirler) |
| İzinler | INTERNET, VIBRATE |
| Ekran | immersive_mode=true |

## Headless denetim sonuçları (izole kopya, `TORIMON_TEST=1`)
Komut: `docs/gelistirme/Run-Audit.ps1` — 28 kayıt (26 dev denetimi + e2e_runner + faz67_smoke), **0 başarısız**, çıkış kodu 0.

| Denetim | PASS | Denetim | PASS |
|---|---|---|---|
| lore_canon | 7 | room_header_fit | 41 |
| story_flags | 33 | room_identity | 21 |
| save_split | 32 | dialogue_data | 105 |
| memory_seal | 100 | room_graph | 57 |
| curse_reload | 92 | save_robust | 7 |
| final_sequence | 35 | resume_m3 | 4 |
| save_quit | 44 | update_check | 7 |
| start_flow | 46 | m1_stress | 64 |
| death_loop | 113 | e2e_runner | 53 |
| interact | 23 | faz67_smoke | çıkış 0 |
| ui_header_portrait | 47 | | |
| keeper_naming | 20 | | |
| release | 141 | | |
| controls | 32 | | |
| door | 31 | | |
| push | 17 | | |
| jump | 13 | | |
| eye_intro | 11 | | |

Ek: `scripts/dev/move_time_audit.gd` (v1.12.2 ile geldi, Run-Audit listesinde **yok**) ayrıca çalıştırıldı: **28 PASS / 0 FAIL, çıkış 0** (yürüme simetrisi, time_scale sıfırlama, lanet bitiminde hold tamamlanması).

Smoke günlüğü: `FAZ67_SMOKE ok curse_possession=true curse50=true world=true bad=true good=true rooms=true indicator=true`.

## Bu baseline'ın KANITLAMADIĞI şeyler
- Pencereli/gerçek giriş: dokunmatik joystick, çoklu dokunuş, gerçek kare hızı, ses.
- Gerçek cihaz/emülatör: açılış, uygulama arka plana alma/geri dönme, düşük bellek, 16 KB sayfa.
- İnsan oyun süresi ve anlaşılırlık. Ölçülen ana yol süresi 42,6 dk (yan odalarla 52,1 dk); PROGRESS.md/plan hedefi 165–195 dk. Fark ciddi (bkz. 08).
- Doğal rota ile final: fixture ile geçen final doğal rotayı kanıtlamaz (Run-Audit kendi çıktısı da bunu söyler).
- Derlenmiş paket: `targetSdkVersion`, 16 KB hizalama, imza.

## Çalışma ağacı
Takip edilmeyen: `android/build/src/debug/`, `qa/`, iki `.uid` dosyası (`playtime_measure.gd.uid`, `ordered_relic.gd.uid`). Bu oturum repoda kod değişikliği yapmadı; yalnız `qa/release-readiness/` altına rapor yazıldı.

## Not
`audit-run-1` (v1.12.1'e ait) bayat; kullanılmadı. Bu belgeye yalnız 1.12.2 koşusu (`audit-run-2`) girdi.
