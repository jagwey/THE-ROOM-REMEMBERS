# Oynanış Süresi İçeriği — Tasarım (2026-11-15)

Kaynak: `docs/gelistirme/oyun-elestiri-ve-oneriler-2026-11-15.md` §2. Kullanıcı onayı: "sırayla hepsini yap".
Hedef: ölçülen ~52 dk → 3–3,5 saat. Yürüme eklemek yasak; süre bulmaca ve hikâyeden gelir.

## 1. Derin bulmaca odaları (6 oda, her bölüme 1, ~10 dk)
Yan kapıdan (`scripts/main.gd` `SIDE_DOORS`) girilen, ana yol için **zorunlu olmayan** ama ödüllü odalar.
Her biri o bölüme kadar öğrenilmiş en az üç mekaniği birleştirir; ipucu odanın içindeki 2–3 kayıttan toplanır.

| Bölüm | Oda id | Başlık | Giriş | Mekanikler | Ödül |
|---|---|---|---|---|---|
| Uyanış | `awakening_bellroom` | Sessiz Çanlar | `awakening_vigil` | 3 basınç plakası aynı anda: ceset + yankı + Noroi; çan sırası kayıttan | kanıt kartı "İlk Nöbet" |
| Çürüme | `decay_rootworks` | Kök Damarları | `decay_garden` | vana/su seviyesi + sarmaşık + ağırlık taşı; su sarmaşığı merdivene çevirir | kanıt kartı "Bahçıvanın Defteri" |
| Kütüphane | `library_archive_vault` | Kayıt Mahzeni | `library_upper_stacks` | sıralı emanet + kadran + saat; üç dağınık kayıt tarih sırasını verir | Shilda'nın 1927 kaydı |
| Deney | `experiment_twin_lab` | İkiz Laboratuvarı | `experiment_circuit` | yankı ikizi + zamanlı devre + Ruh Kesimi | Denek 14 dosyası (ek sayfa) |
| Aynalar | `mirrors_inverse_hall` | Ters Salon | `mirrors_labyrinth` | ters kontrol + yol taklidi + kırmızı şerit + Gölge Atılması | yansıma kaydı |
| Çekirdek | `core_last_record` | Son Kayıt | `core_memory_vault` | hepsi: yankı, ceset, kesim, atılma, sıra | X'in son notu |

Kurallar: her odada `puzzle_manager.gd` goal/orientation/explicit ipucu, `campaign_objectives.gd` hedef satırı,
`room_manager.gd` `ROOM_ORDER`/`ROOM_TITLES_TR` (sona eklenir, mevcut numaralar kaymaz), `main.tscn` instance, defter haritası.
Softlock yok: ölüm, yeniden giriş, kayıt yükleme sonrası oda çözülebilir kalır. Çözülme bayrağı kalıcı.

## 2. Yankı Sınavı (6, her derin odada, ~3 dk)
Derin oda çözüldükten sonra odadaki sunak "Yankı Sınavı"nı açar: aynı odanın zamanlı (60–90 sn) varyantı.
Başarı: defter sayfası + kalıcı bayrak. Başarısızlık cezasız; yeniden denenir.

## 3. Geri dönüş köşeleri (8, ~3 dk)
Eski odalarda yeteneğe bağlı küçük alanlar; içlerinde Shilda'nın insan dönemine (1927 öncesi / Araştırma Yardımcısı S.) ait kayıtlar.
- Ruh Kesimi (`ability_soul_slash`) → çatlak duvar (`cracked_wall.gd`): `awakening_crypt`, `decay_catacombs`, `library_hall`, `experiment_cells`.
- Gölge Atılması → kırmızı perde / boşluk: `decay_cistern`, `experiment_observation`, `awakening_balcony`, `library_forbidden_wing`.
Her köşe: 1 kanıt kartı veya kayıt + 1 Shilda satırı. Toplam sayaç defterde görünür ("Kayıtlar 3/8").

## 4. Tahmini süre
Derin odalar +60, Sınavlar +18, Köşeler +24, hikâye doldurma +20, zayıf oda iyileştirmesi +10 → ~52 + 132 ≈ 3 saat.

## 5. Test
- Her yeni oda için `scripts/dev/deep_rooms_audit.gd`: oda yüklenir, kapı bağlı, ipucu var, çözüm yolu uygulanınca çözülür, ölüm/yeniden giriş sonrası çözülebilir.
- `backtrack_nooks_audit.gd`: yetenek yokken kapalı, varken açık, kayıt alınır, sayaç artar.
- Mevcut 11 denetim yeşil kalır; `playtime_measure.gd` yeni odaları sayar.
