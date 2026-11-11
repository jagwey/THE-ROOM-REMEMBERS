# 02 — Hikâye ve Diyalog Denetimi

Sürüm: v1.12.2 · 2026-11-11 · Kanıt: **KOD/VERİ okuma** + HEADLESS (`lore_canon` 7, `dialogue_data` 105, `story_flags` 33 PASS). Hiçbir bulgu oyun içinde oynanarak doğrulanmadı.

## Kapsam
10 diyalog JSON'u (`data/dialogue/`, 162 satır); sahne/betiklerdeki söylem ve kanıt metinleri dahil toplam ~405 satır. 24 bulgu: P1 3, P2 10, P3 11 (kimlikleri 06_BUG_REGISTER'da BUG-003…005, 013…023, 037…042).

## Kanon kuralları ve durum
| Kural | Durum | Kanıt |
|---|---|---|
| Tek final (BÖLÜM I SONU) | Uyumlu | `ending_manager.gd`, `final_sequence` HEADLESS 35 PASS |
| Oyun verisinde "Shiren" yok (eski ad, artık Noroi) | Uyumlu | KOD taraması |
| Shilda adı Perde 2 sonu bahçede açılır; öncesinde konuşmacı "???" | **Kısmen ihlal**: Perde 1 kriptte Denek 14 + Shilda rolü sızıyor (BUG-003); balkonda Shilda konuşuyor (BUG-013) | KOD |
| X finale kadar görünmez, perde başına tek iz | **İhlal**: `story_beat.gd:211` X? sesi (BUG-005) | KOD |
| Noroi ölünce unutur, Shilda hatırlar | Uyumlu görünüyor; ölüm sayacı sabit "41" yazılan yerler var (BUG-015) | KOD |
| 1927 X boyutu kurdu, hikâye 1995 | **Çelişki**: "Kazı", kapı yılı, tally 1927 vs "68 yıl" (BUG-004, 019–021) | KOD |

## P1 ayrıntı
1. **Crypt sızıntısı** (`awakening_crypt.tscn:44-46`): oyuncu Perde 1'de Shilda'nın kim olduğunu ve Denek 14'ü öğreniyor. Kullanıcı kararı: Shilda ilk bölümde tanıtılır ama ilk odalarda değil, ad Perde 2 sonu bahçede.
2. **1995 / "kabul yılım"**: Noroi öncesinden biliyor (`story_beat.gd:113,139`, `library_clockroom.json`), sonra experiment_cells'te aynı bilgi "haber" olarak sunuluyor (`story_beat.gd:169-171`; `library_clockroom.tscn:42`).
3. **X? sesi** final öncesi konuşuyor.

## Önerilen minimal metin düzeltmeleri (uygulanmadı)
- Crypt: satırları maskele ("???", "Denek …"), Shilda adı/rolü çıkar.
- 1995: tek yönlü bilgi akışı seç (öğrenme sırası: haber → hatıra); önceden bilen satırları kaldır.
- X?: ses yerine iz (ses efekti/sembol).
- Sabit 41 → `death_count` değişkeni.
- Gölge/Güvenlik görevlisi/Araştırma Yardımcısı S. etiketleri tek adlandırmaya.
Bunlar kanon kararıdır; kullanıcı onayı olmadan uygulanmaz. Uygulandıktan sonra `lore_canon`, `dialogue_data`, `story_flags` yeniden çalıştırılmalı.

## Okunmayan alanlar
`scripts/ui/*` metinleri, çoğu `scripts/world/*.gd` söylem metni, `puzzle_manager` ipuçları, `final_sequence.gd` gövdesi, README/docs. Bu alanlar için kanon uyumu **bilinmiyor**.

## İnsan testi gerektirenler
Anlaşılırlık, ton, tempo, çeviri akıcılığı, "hatırlamıyorum/hatırlıyor" ayrımının oyuncuya ulaşıp ulaşmadığı. Protokol: `05_PLAYTEST_PROTOCOL.md`.
