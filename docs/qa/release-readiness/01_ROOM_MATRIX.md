# 01 — Oda Matrisi (40 oda)

Sürüm: v1.12.2 · 2026-11-11 · Kanıt sınıfı: **KOD (statik okuma)**. Hiçbir oda oynanarak gezilmedi. Oda grafiği tutarlılığı ayrıca `room_graph_audit` (HEADLESS, 57 PASS) ile doğrulandı; bu tablo o denetimin yerine geçmez.

Kaynak: `scripts/autoload/room_manager.gd`, `scripts/main.gd` (ROOM_DEFS, SIDE_DOORS), `scenes/rooms/*.tscn`, `scripts/dev/room_graph_audit.gd`. Perde = ROOM_ORDER bölge öneki (awakening=1 … core=6). "Kanıt" = `.tscn` içindeki `evidence_title`/`evidence_id` sayısı (0 = o dosyada yok). "?" = taramada belirlenemedi; tahmin edilmedi.

| oda id | perde | çıkışlar | gereken yetenek | bulmaca / mekanik | kanıt | düşman |
|---|---|---|---|---|---|---|
| awakening | 1 | →awakening_passage; yan→awakening_balcony | - | awakening_weight; rebirth_bed | 1 | yok |
| awakening_balcony | 1 | →awakening; →awakening_crypt (req soul_seal_balcony) | ability_soul_slash (mor mühür) | soul_seal_balcony | 2 | yok |
| awakening_crypt | 1 | →awakening_balcony; →decay_shilda_wall (req decay_shilda_wall_broken) | - | taş yığını kapısı (dış taraftan kırılır) | 2 | yok |
| awakening_passage | 1 | →awakening; →awakening_seal | - | - | 1 | yok |
| awakening_seal | 1 | →awakening_passage; →awakening_vigil (req awakening_memory_code) | - | awakening_seal_weight; awakening_memory_code | 0 | yok |
| awakening_vigil | 1 | →awakening_seal; →decay_vines (req awakening_vigil) | - | nöbet kapısı | 1 | yok |
| decay_vines | 2 | →awakening_vigil; →decay_weight; yan→decay_catacombs | - | - | 0 | yok |
| decay_weight | 2 | →decay_vines; →decay_greenhouse; yan→decay_cistern | ability_shadow_dash | decay_weight_latch | 0 | yok |
| decay_greenhouse | 2 | →decay_weight; →decay_shilda_wall (req decay_greenhouse) | - | basınç plakası | 1 | yok |
| decay_shilda_wall | 2 | →decay_greenhouse; →decay_garden; →awakening_crypt (ikisi req decay_shilda_wall_broken) | - | kırılabilir duvar, Keeper kovalaması (iki çarpma) | 1 | Keeper (kovalama) |
| decay_garden | 2 | →decay_shilda_wall; →library_hall | - | decay_flower_evidence | ? | walking shade ×1 |
| decay_catacombs | 2 | yan→decay_vines | - | decay_catacomb_seal | 1 | walking shade ×2 |
| decay_cistern | 2 | →decay_weight | ability_shadow_dash (giriş) | - | 1 | yok |
| library_hall | 3 | →decay_garden; →library_witness (req library_catalog); yan→library_upper_stacks | - | library_catalog | 2 | yok |
| library_witness | 3 | →library_hall; →library_clockroom (req library_witnesses); yan→library_reading_cell | - | library_witnesses | 0 | yok |
| library_clockroom | 3 | →library_witness; →library_page (req library_clockroom) | - | iki saat (1927/1995) kapısı | 2 | yok |
| library_page | 3 | →library_clockroom; →experiment_cells (req library_page_order) | - | library_page_order | 0 | yok |
| library_upper_stacks | 3 | →library_hall; →library_forbidden_wing (req library_page_order) | - | library_shelf_order | 1 | yok |
| library_forbidden_wing | 3 | →library_upper_stacks | verir: ability_soul_slash | soul_seal_forbidden | 1 | yok |
| library_reading_cell | 3 | yan→library_witness | - | - | 1 | yok |
| experiment_cells | 4 | →library_page; →experiment_intake (req experiment_cells_seen); yan→experiment_quarantine | - | experiment_cells_seen | 0 | walking ×1; shielded ×1 |
| experiment_intake | 4 | →experiment_cells; →experiment_circuit (req experiment_intake) | - | kabul kaydı okuma kapısı | 2 | yok |
| experiment_circuit | 4 | →experiment_intake; →experiment_authority (req experiment_circuit); yan→experiment_observation | ability_shadow_dash (yan kapı) | experiment_circuit | 0 | shielded ×1 |
| experiment_authority | 4 | →experiment_circuit; →mirrors_reverse (req experiment_authority); yan→experiment_core_conduit | - | experiment_authority | 0 | yok |
| experiment_quarantine | 4 | yan→experiment_cells | - | - | 1 | yok |
| experiment_core_conduit | 4 | yan→experiment_authority | - | experiment_conduit | 1 | yok |
| experiment_observation | 4 | yan→experiment_circuit | ability_shadow_dash (giriş) | - | 1 | yok |
| mirrors_reverse | 5 | →experiment_authority; →mirrors_dual (req mirrors_reverse); yan→mirrors_labyrinth | - | mirrors_reverse | 0 | shielded ×1 |
| mirrors_dual | 5 | →mirrors_reverse; →mirrors_gallery (req mirrors_dual); yan→mirrors_1927 (req mirrors_gallery) | - | mirrors_dual | 0 | yok |
| mirrors_gallery | 5 | →mirrors_dual; →mirrors_unbroken (req mirrors_gallery) | - | beden sayımı kapısı | 1 | yok |
| mirrors_unbroken | 5 | →mirrors_gallery; →core_threshold (req mirrors_unbroken); yan→mirrors_shrine | - | mirrors_unbroken | 0 | yok |
| mirrors_labyrinth | 5 | yan→mirrors_reverse | - | mirrors_labyrinth_crossed | 1 | shielded ×1 |
| mirrors_shrine | 5 | yan→mirrors_unbroken | verir: ability_shadow_dash | - | 0 | yok |
| mirrors_1927 | 5 | yan→mirrors_dual | - | - | 1 | yok |
| core_threshold | 6 | →mirrors_unbroken; →core_ascent (req core_threshold); yan→core_memory_vault | - | core_threshold | 0 | yok |
| core_ascent | 6 | →core_threshold; →core_seal_chamber (req core_ascent) | mesaj: soul_slash + shadow_dash + yankı (`required_ability` alanı yok) | core_ascent kapısı | 2 | yok |
| core_seal_chamber | 6 | →core_ascent; →core (req core_seal); yan→core_bloom_garden | - | core_seal | 0 | yok |
| core | 6 | →core_seal_chamber | - | ? | 0 | ? |
| core_memory_vault | 6 | yan→core_threshold | - | core_vault_order | 1 | yok |
| core_bloom_garden | 6 | yan→core_seal_chamber | - | core_bloom_order | 2 | yok |

## Notlar ve sınırlar
- Düşman sütunu yalnızca `room_manager` shade yerleşimine ve audit'teki Keeper kovalamasına dayanır. "yok" kesin değil, "taramada bulunmadı" demektir.
- `decay_garden` kanıt sayısı ve `core` bulmaca/düşman alanları belirlenemedi (`?`). Bunlar için oda dosyasının elle okunması gerekir.
- Yetenek-sırası kontrolü (KOD): `ability_shadow_dash` yalnız **yan kapılarda** isteniyor (`main.gd:58` decay_weight→decay_cistern, `main.gd:62` experiment_circuit→experiment_observation); ana yol kapıları bu yeteneği istemiyor. Yetenek `mirrors_shrine.tscn:34` içinde veriliyor (Perde 5 yan odası). Sonuç: Perde 2/4 yan odaları geri dönüşle erişilen isteğe bağlı içerik; ana yolda kilit çıkmıyor. İlk taramadaki "çelişki" şüphesi (BUG-053) bu okumayla **düşürüldü**. Yan odaların oyuncuya "sonra dön" ipucunu verip vermediği TEST EDİLMEDİ.
- Oda başına bulmaca çözülebilirliği, ceset/echo etkileşimi, kaydet-çık-devam: **TEST EDİLMEDİ** (bkz. 03_GAMEPLAY_PUZZLES).

## Açık soru
- Perde 2'de (`decay_weight`) yan odaya geri dönüş ipucu, oyuncunun yeteneği Perde 5'te alıp dönmesini gerektiriyor; geri dönüş maliyeti (uzun yol) ve ipucu netliği insan testinde sorulmalı (05_PLAYTEST_PROTOCOL).
