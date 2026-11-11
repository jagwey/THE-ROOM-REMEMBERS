# 03 — Oynanış, Bulmaca, Ölüm/Lanet/Kayıt

Sürüm: v1.12.2 · 2026-11-11. Kanıt sınıfları ayrı tutuldu. "Geçti" yalnız HEADLESS satırları içindir; oyuncu deneyimi hakkında karar vermez.

## Headless ile doğrulananlar
| Alan | Betik | Sonuç |
|---|---|---|
| Hareket/zıplama/itme/kapı/kontrol | controls 32, jump 13, push 17, door 31 | PASS |
| Yürüme simetrisi, time_scale (1.12.2) | move_time_audit 28 | PASS |
| Ölüm döngüsü | death_loop 113 | PASS |
| Ceset/lanet/yeniden yükleme | curse_reload 92, m1_stress 64 | PASS |
| Kayıt ayrımı, sağlamlık, çıkış, devam | save_split 32, save_robust 7, save_quit 44, resume_m3 4 | PASS |
| Mühür/hafıza | memory_seal 100 | PASS |
| Etkileşim envanteri | interact 23 | PASS |
| Oda grafiği/kimlik/başlık | room_graph 57, room_identity 21, room_header_fit 41 | PASS |
| Final dizisi | final_sequence 35 | PASS |
| Uçtan uca | e2e_runner 53, faz67_smoke | PASS |

## Statik inceleme (STATİK, yeniden üretilmedi)
- **Kilitlenme riski** BUG-001 (ölüm tween'i), BUG-002 (possession overlay). İkisi de sahne yeniden yüklenmesi gibi dar tetiklerde; kanıtlanmadı.
- **İlerleme engeli:** geri dönüşsüz `required_ability` kilitlenmesi bulunmadı (bulgu yokluğu, kanıt değil).
- **Save:** BUG-011/012/030/031/032 (tür koruması, atomik yazma, resume/commit ayrımı).
- **time_scale:** birden fazla güvenlik ağı var; v1.12.2 simetri düzeltmesi tutarlı.

## Bulmaca/softlock matrisi
Bulmaca bazlı oynanabilirlik doğrulaması bu oturumda **yapılmadı**: `puzzle_manager.gd` okunmadı ve çözüm yolları oynanarak denenmedi. Sonuç: **TEST EDİLMEDİ**. Gerekli: her bulmaca için (a) giriş durumu, (b) çözüm, (c) yanlış çözüm/ölüm sonrası sıfırlanma, (d) ceset/echo etkileşimi, (e) kaydet-çık-devam. Bu kontrol 01_ROOM_MATRIX'in "bulmaca" sütunu doldurulduktan sonra oda başına yapılmalı.

## Ölüm/lanet/ceset/echo stres durumu
HEADLESS dayanıklılık betikleri (death_loop, curse_reload, m1_stress) geçti. Pencereli çoklu ölüm, uzun oturum, bellek büyümesi ve gerçek cihazda arka plana alma **TEST EDİLMEDİ**.

## Tempo
Ölçülen ana yol 42,6 dk, yan odalarla 52,1 dk (`playtime_measure`, HEADLESS ölçüm, ideal rota varsayımlı). İlk oynayan oyuncu süresi bundan uzun olacaktır ama hedef 165–195 dk ile aralarında büyük fark var (BUG-024). Karar ürün sahibinde: içerik uzatma mı, hedef/mağaza vaadini düşürme mi.

## Yapılacaklar
1. BUG-001/002 için yeniden üretim testi.
2. Bulmaca bazlı oynanabilirlik denetimi (scout ile liste, sonra insan/pencereli).
3. Pencereli oturum: çoklu dokunuş + joystick.
