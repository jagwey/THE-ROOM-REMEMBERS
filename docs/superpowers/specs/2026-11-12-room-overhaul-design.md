# Oda Revizyonu + Diyalog Yeniden Yazımı — Tasarım (Spec)

- Tarih: 2026-11-12
- Taban sürüm: v1.13.0 (`main` 710fd85)
- Durum: kullanıcı onayı bekliyor (spec incelemesi)

## 1. Amaç

Kullanıcı isteği: her odayı tek tek en iyi hale getirmek, sadece yürünen / gereksiz yerleri kaldırmak, oyunu
**3–3,5 saat** yapmak ve diyalogları düzgün, doğal Türkçeye çevirmek.

Başarı ölçütleri:

1. 40 odanın hiçbiri "sadece yürüme" değil: her odada en az bir karar / bulmaca / beceri anı var.
2. İlk oynanış süresi (ortalama oyuncu, ölümler dahil) 180–240 dk. Şu an ~95 dk. Bölüm 4 tablosu üst sınırdır (toplam 255 dk).
3. Diyalog satırlarının tamamı Bölüm 6'daki üslup kurallarına uyar; anlamsız / çeviri kokan satır kalmaz.
4. Bilinen softlock / bozuk oda sıfır (Yükseliş, Sarnıç, Katakomb, Tapınak).
5. `scripts/dev/e2e_runner.gd` ana yolu baştan sona headless bitirir; `docs/gelistirme/Run-Audit.ps1` temiz.

Kapsam dışı: yeni yetenek, yeni karakter, yeni sanat seti, Play Store işleri, çok dilli destek.

## 2. Global kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Oda sayısı / ID | **40 oda korunur, hiçbir oda silinmez, ID değişmez.** "Birleştir" önerileri iptal; zayıf oda kendi mekaniğini alır. | `ROOM_ORDER`, save dosyaları ve `SIDE_DOORS` bozulmaz. |
| Labirent | `mirrors_labyrinth` yan odadan ana yola alınır (kapı bağlantısı değişir, ID aynı). | Ödülsüz yan oda israf. |
| Plaka davranışı | Kapı, koşul **canlı** sağlandıkça açık; `PuzzleManager.mark_solved` yalnız oyuncu o kapıdan **geçtiğinde** çağrılır. | Taşı/cesedi çekip kapıyı açık bırakma hilesi kalkar; geri dönüşte softlock olmaz. |
| `accept_player` | Bulmaca plakalarında varsayılan `false`. Oyuncu-kabul eden plaka yalnız "3 tanık" gibi bilinçli tasarımda. | Uyanış'ta plaka üstüne yürüyünce çözülüyor. |
| İtilebilir taş | Her `weight_stone` için `max_x` çıkış kapısının ≥ 48 px gerisinde. | Ağırlık / Uyanış'ta taş çıkışı tıkıyor. |
| Ceset sınırı | `MAX_CORPSES = 3` aynı kalır. Bulmacalar en fazla 3 ceset ister; metinler buna göre yazılır. | Galeri metni ile çelişki. |
| Eski save | Önceden çözülmüş bulmaca çözülmüş sayılır. Yeni bulmacalar **yeni** puzzle ID alır (`<oda>_<ad>`); eski save'de geçilmiş odaya dönülürse yeni bulmaca ister ama ana yol kapısı zaten açık kalır. | Güncelleme sonrası oyuncu kilitlenmez. |
| İpucu felsefesi | Her kod / sıra oyunda **önceden görülebilir** bir kaynaktan gelir; NPC cevabı söylemez. | Kasa ve Çiçeklenme sorunları. |
| Yetenek sırası | Ruh Kesimi: `library_forbidden_wing`. Gölge Atılması + seal_shard_2: `mirrors_shrine`. Bu yeteneklerden **önceki** odalar onları istemez. | Sarnıç Atılma istiyor ama yetenek Bölüm 5'te. |

## 3. Yapı taşları (mevcut, yeniden kullanılır)

`pressure_plate`, `weight_stone`, `ordered_relic`, `sequence_shrine`, `echo_altar` (kayıt süresi tek sabit),
`curse_cloud`, `soul_seal`, `curse_barrier`, `invisible_platforms`, `memory_shade`, `cracked_mirror` (şu an kullanılmıyor → Kırılmayan Ayna'da devreye girer),
`built_room.gd` iskeleti, `CorpseManager.set_corpse_anchored`.

Yeni küçük bileşenler (gerekirse, her biri tek dosya):

- `code_seal.gd` — N haneli sembol/rakam girişi, yanlışta ceza (lanet +1 veya kısa sersemleme). Mühür / Tanık / Yetki / Kasa kullanır. Mevcut kod mühürü varsa genişletilir, yenisi yazılmaz.
- `dial_puzzle.gd` — döndürülebilir kadran (Saatler Odası).
- `dialogue_choice` — DialogueManager'a 2–3 seçenekli cevap desteği (Nöbet Odası). Varsa genişletilir.
- `control_invert` bayrağı — oyuncu girişinde yatay eksen ters (Ayna Geçidi), oda çıkışında sıfırlanır.

Ölü kod: `mirror_relay.gd` ve `core_portal.gd` kullanılmıyorsa silinir.

## 4. Oda oda tasarım

Süre = hedef ilk oynanış dakikası. "Kaynak" = kodun / sıranın oyunda nereden öğrenildiği.

### Bölüm I — Uyanış (hedef ~40 dk)

| # | Oda | Hedef mekanik | Süre |
|---|---|---|---|
| 01 | `awakening` | 2 plaka: biri taş, biri **yalnız ceset** kabul eder (ilk ölüm dersi). Duvardaki saat yönü ipucu. Taş `max_x` < 892. | 6 |
| 02 | `awakening_balcony` | Teleskop = yankı kaydı (geçmişteki Noroi'nin yolunu gösterir). Boşluk: cesedi kenara bırakıp üstünden atla. `keeper_observe` (x700) ile boşluk çakışması giderilir. Çıkmaz değil: ödül = Geçit için halka sırası ipucunun ilk hanesi. | 6 |
| 03 | `awakening_crypt` | Defter sayfaları: 3 sayfayı tarih sırasına diz (`ordered_relic`). Yatağa ceset plakası. MemorySeal etkileşimi gerçekten bir anı sahnesi açar. | 7 |
| 04 | `awakening_passage` | Halka sırası 3-1-4 (Kaynak: Balkon + Mahzen). Ceset basamağı. Oda 1920 → 1500 px. OwnVoice etkileşimi yankıyla birleşir. | 7 |
| 05 | `awakening_seal` | Kod mühürü + ikinci ceset şartı; yanlış kod cezalı. | 7 |
| 06 | `awakening_vigil` | Gölge ile 3 soruluk konuşma (`dialogue_choice`); cevaplar `keeper_trust` değiştirir. VigilTrace gölgeleri: 3 `memory_shade` izlenir, biri sahte. | 7 |

### Bölüm II — Çürüme (hedef ~46 dk)

| # | Oda | Hedef mekanik | Süre |
|---|---|---|---|
| 07 | `decay_vines` | Çiçekli ceset sarmaşığı yakar (`has_flower`). Kırık cam = ölümcül zemin. Kol ikiye bölünür (iki taraf). | 7 |
| 08 | `decay_weight` | 2 plaka: taş + ceset, canlı koşul (latch yok). Taş `max_x` çıkıştan ≥ 48 px geride. | 6 |
| 09 | `decay_greenhouse` | Ceset = Shilda'nın eli: ceset doğru saksıya bırakılınca yol açılır. `memory_shade` yürüyüşü (gölgeyi takip et). | 7 |
| 10 | `decay_shilda_wall` | Cesetler engel (lanet bulutunu keser); çiçekler yankı tetikler. İki kapı arası ≥ 280 px. | 7 |
| 11 | `decay_garden` | Çiçek sıralama 7-2-9 (Kaynak: Sera duvar yazısı). Desen yalnız ceset ışığında görünür. | 6 |
| 12 | `decay_catacombs` | Çiçek kaynağı odada net (görünür çiçek + işaret). Semboller odaya yayılır. Ceset köprüsü. Çiçek yoksa alternatif kaynak → softlock yok. | 7 |
| 13 | `decay_cistern` | **Atılma şartı kalkar.** Su seviyesi bulmacası: 3 vana + ceset ağırlığı ile su düşür / yükselt; 3 kayıp sayfa toplanır (lore). | 6 |

### Bölüm III — Kütüphane (hedef ~40 dk)

| # | Oda | Hedef mekanik | Süre |
|---|---|---|---|
| 14 | `library_hall` | Arşiv zincirinin başı: 3 kitap rafı sırası (Kaynak: oda girişindeki kayıt). Tanık odasının kodunun ilk hanesi burada. | 5 |
| 15 | `library_witness` | 3 plaka: ceset, yankı, oyuncu (3 tanık). Hepsi aynı anda → 251 `code_seal` açılır (Kaynak: 3 tanığın sözleri). Shilda gerçekten odada, tek replik. **Portre kesilmesi düzeltilir.** | 7 |
| 16 | `library_clockroom` | `dial_puzzle`: 3 saati Tanık'tan öğrenilen saate getir. | 6 |
| 17 | `library_page` | Mevcut mekanik kalır; ipucu sırası kartlarla eşlenir; kamera pulse doğru odayı hedefler. | 5 |
| 18 | `library_upper_stacks` | Mevcut (sağlam), yalnız diyalog. | 5 |
| 19 | `library_forbidden_wing` | Ruh Kesimi alınır (mevcut). Alındıktan sonra kısa öğretici: 2 `soul_seal`. | 6 |
| 20 | `library_reading_cell` | Ruh Kesimi ile açılan kilitli okuma kabini; kitap okuma = yankı. Shilda'nın insanlığını ele veren satırlar kaldırılır (Bölüm 7). | 6 |

### Bölüm IV — Deney (hedef ~38 dk)

| # | Oda | Hedef mekanik | Süre |
|---|---|---|---|
| 21 | `experiment_cells` | Ceset ağırlığı: 3 hücre kapısı, 2 ceset; hangisinin açık kalacağına karar ver. X'in adı burada geçmez. Shilda'nın "sağdaki devre" satırı düzeltilir. | 6 |
| 22 | `experiment_intake` | Kabul masası: ceset + taş ile terazi dengesi. Çiçeğin kime ait olduğu netleşir (Bölüm 7). | 5 |
| 23 | `experiment_circuit` | Mevcut; zamanlayıcı **tek değer: 8 sn** (kod + metin). `ForwardCircuit` kapı adı düzeltilir. | 5 |
| 24 | `experiment_authority` | 4-1-8 `code_seal` (Kaynak: Hücreler + Kabul kayıtları). | 5 |
| 25 | `experiment_quarantine` | Ana yolda zorunlu. Lanet bulutu + ceset kalkanı. | 6 |
| 26 | `experiment_core_conduit` | Ana yolda zorunlu. Ruh Kesimi ile damar mühürlerini sırayla kes. | 6 |
| 27 | `experiment_observation` | Ana yolda zorunlu. Camın arkasında yankı kaydı izlenir → **Shilda'nın insan olduğu burada açılır.** | 5 |

### Bölüm V — Aynalar (hedef ~46 dk)

| # | Oda | Hedef mekanik | Süre |
|---|---|---|---|
| 28 | `mirrors_reverse` | `control_invert`: yatay kontroller ters, zemin yansımalı; 50/50 menü kalkar. | 6 |
| 29 | `mirrors_dual` | Mevcut 2 katmana 3.: plaka + iki kol; ayna yankı (kayıt ters oynar). | 7 |
| 30 | `mirrors_gallery` | Bedenler galerisi: 3 ceset plakası; metin "üç beden" der. | 6 |
| 31 | `mirrors_unbroken` | `cracked_mirror` yüzleşme: yansımanın yolunu yankıyla taklit et. Güvene göre 2 varyant replik. Tapınak kapısı (x784) görünür işaretli. | 7 |
| 32 | `mirrors_labyrinth` | Ana yola alınır. Ceset köprüsü; ödül = 1927 tarih tuğlasının yeri. | 7 |
| 33 | `mirrors_shrine` | Gölge Atılması alınır, sonra test: 3 `curse_barrier` + 1 boşluk. Önceki odada Shilda: "Tapınağa uğra." | 7 |
| 34 | `mirrors_1927` | Sessiz sekans (yazı yok, yalnız yankı). Sonunda tarih tuğlası → Kasa girdisi. Başlık "1927 Gecesi". **X'in adı Bölüm V sonunda burada açılır.** | 6 |

### Bölüm VI — Çekirdek (hedef ~45 dk)

| # | Oda | Hedef mekanik | Süre |
|---|---|---|---|
| 35 | `core_threshold` | `curse_cloud` testi: cesetleri kalkan yaparak geç. | 6 |
| 36 | `core_ascent` | **Yeniden yapılır.** Gerçek merdiven: Ruh Kesimi (mühür), Atılma (boşluk), yankı (plaka) — üç test. Yetenek eksikse ret repliği hangi odada alınacağını söyler. | 9 |
| 37 | `core_seal_chamber` | 3 bağı Ruh Kesimi ile kes. `trusted_keeper` burada **set edilmez**. | 6 |
| 38 | `core_memory_vault` | Kod = önceki odalardan toplanan ipuçları (1927 tuğlası dahil). NPC ve fail_line cevabı söylemez. Ödül anlamlı (son anı sahnesi). | 7 |
| 39 | `core_bloom_garden` | Çiçek sayısı = ölüm sayısı mantığı + ceset ağırlığı; ipucu 4-1-2 ile tutarlı. `trusted_keeper` yalnız burada set edilir. | 7 |
| 40 | `core` | 3 dalga kristal savunması. Final `trusted_keeper` + `truth_seen` bayraklarına göre 2 varyant (tek bölüm sonu korunur: "BÖLÜM I SONU"). | 10 |

Toplam üst sınır: I 40 + II 46 + III 40 + IV 38 + V 46 + VI 45 = **255 dk**. Gerçek hedef 180–240 dk (hızlı oyuncu tabloyu tutturmaz).

## 5. Kritik hatalar (Faz 0)

1. **Portre kesilmesi** (ODA 15 ekranı). Aday nedenler, sırayla incelenecek:
   `keeper_controller.gd:101` `sprite.offset=Vector2(0,-51)` + `keeper_observe` y288 / zemin 280;
   `portrait_medallion.gd` `STRETCH_KEEP_ASPECT_COVERED` (`portrait_shilda.png` 384×384), `dialogue_portraits.gd` `TEXT_INSET=78`;
   `hud_controller.gd:288-309` SafeArea. Düzeltme 640×360 ve 1280×720 + telefon oranında (20:9) doğrulanır.
2. `core_ascent` platformsuz → Bölüm 4'teki tasarım.
3. `mirrors_shrine` gizli → kapı işareti + Shilda yönlendirmesi.
4. `core_bloom_garden` "çoktan aza" ipucu ↔ 4-1-2 çelişkisi.
5. Plaka latch + `accept_player` (Bölüm 2 kararı) tüm odalarda.
6. `decay_catacombs` çiçek kaynağı.
7. `decay_cistern` Atılma şartı.
8. `experiment_circuit` 6/8 sn, `ForwardCircuit` kapı adı, `library_page` ipucu sırası + kamera.
9. `puzzle_manager.gd:103` "kalıcı olarak kilitle" metni / davranışı yeni plaka kuralına uyar.

## 6. Diyalog üslup kuralları

Kaynak: `data/dialogue/*.json`, `DialogueData`, oda scriptlerindeki gömülü metinler, HUD ipuçları.

1. **Noroi**: kısa, içe dönük; en fazla 1 cümle.
2. **Shilda**: 2–8 kelime, "sen" der.
3. **Gölge/Keeper**: adı öğrenilene kadar `GameState.keeper_speaker_name()` ("???" / "Gölge"); sabit "Shilda" yazılmaz.
4. **X**: "siz" der; Noroi X'e "sen" der.
5. Satır ≤ 90 karakter; HUD ipucu ≤ 70. Uzunlar bölünür.
6. Sade Türkçe; çeviri kalıbı yok ("…yapmak durumundasın", "bu bir … olarak" vb.).
7. Somut imge: soyut felsefe yerine nesne/ses/koku.
8. Üç nokta yalnız "…" karakteri.
9. Terimler: **Ruh Kesimi**, **Gölge Atılması**, **Çekirdek**, **Denek 14**, kurum = "deney".
   "hafıza" = sistem/kurum; "anı" = kişisel. "hatıra" ve "bellek" kullanılmaz.
10. İpucu satırı fiille biter ("…taşı plakaya it.").

İngilizce kalıntılar Türkçeleşir: `DOMAIN %02d` → "BÖLGE %02d", `END OF PART I` → "BÖLÜM I SONU" (tek dil), `İz: kind` → iz türünün Türkçe adı.
Oda başlıkları: `experiment_quarantine` → "Karantina Mahzeni", `mirrors_1927` → "1927 Gecesi".

## 7. Hikâye (canon) kararları

| Konu | Karar |
|---|---|
| X'in adı | `mirrors_1927` (oda 34) sonunda açılır. Öncesinde hiçbir satırda geçmez (Hücreler sızıntısı silinir). |
| Shilda'nın insan oluşu | `experiment_observation` (oda 27) yankısında açılır. Sarnıç ve Okuma Hücresi'ndeki erken ipuçları imaya indirgenir. |
| Tesisi içeriden kilitleyen | X, kendi seçimiyle. Unutmayı yasaklayan kişinin kendini hafızaya kilitlemesi ironisi Kasa'da söylenir. |
| Çiçeğin sahibi (Kabul) | Shilda. |
| "Yüzlerce" ölüm | Sabit sayı yerine `{deaths}` kullanılır. |
| 68 yıl / 1927 | Referans noktası 1927 gecesi; "1927 yazı" ifadesi "1927 gecesi" olur. |
| Tanık sırası | Hall kaydındaki sıra = Tanık plakalarının sırası. |

## 8. Fazlar ve teslim

Her faz ayrı branch + ayrı sürüm adayı; yayın yalnız kullanıcı isteyince.

| Faz | İçerik | Sürüm önerisi |
|---|---|---|
| 0 | Bölüm 5 kritik hatalar + Bölüm 2 global plaka/taş kuralları | v1.14.0 |
| 1 | Diyalog yeniden yazımı (Bölüm 6–7), oda başlıkları | v1.15.0 |
| 2 | Bölüm I–II odaları (01–13) | v1.16.0 |
| 3 | Bölüm III–IV odaları (14–27) | v1.17.0 |
| 4 | Bölüm V–VI odaları (28–40), final varyantları, ölü kod temizliği | v1.18.0 |

Her fazın sonunda README.md + PROGRESS.md güncellenir (proje kuralı).

## 9. Test ve doğrulama

- **Headless e2e**: `scripts/dev/e2e_runner.gd` her yeni bulmaca için çözüm adımı alır; ana yol 01→40 bitmeli.
  Komut: `TORIMON_TEST=1` ile Godot console (`Godot_v4.7.2-stable_win64_console.exe --headless`).
- **Audit**: `docs/gelistirme/Run-Audit.ps1` — kırık kapı hedefi, ulaşılamayan spawn, `max_x` > kapı-48 taş, `accept_player=true` bulmaca plakası için kontrol eklenir.
- **Diyalog lint** (yeni, `scripts/dev/`): satır uzunluğu, "..." (3 nokta), yasak kelimeler (hatıra, bellek), sabit "Shilda" (keeper bağlamında), İngilizce kalıntı.
- **Softlock senaryoları**: 3 ceset dolu + hepsi anchored; plakadan taş/ceset geri çekilip odaya geri dönüş; eski v1.13 save ile açılış.
- **Görsel**: portre 640×360, 1280×720, 20:9 telefon; Android cihazda bir tur (kullanıcı).

## 10. Riskler

- Süre tahmini kaba; Faz 2 sonunda kullanıcı oynayıp ölçer, hedef sapma > %20 ise Faz 3–4 bulmaca sayısı ayarlanır.
- `main.tscn` + `built_room.gd` odaları farklı kurulmuş; her oda kendi sahnesinde düzenlenir, ortak bileşen kopyalanmaz.
- Eski save uyumu: yeni puzzle ID'leri ve kapı akışı Faz 0'da save testine alınır.
