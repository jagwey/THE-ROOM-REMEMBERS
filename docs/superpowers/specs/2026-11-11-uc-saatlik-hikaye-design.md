# Üç Saatlik Hikâye — Tasarım (2026-11-11)

Durum: tasarım onaylandı, yazılı spec kullanıcı incelemesinde. Kod değişikliği yok.
Kanon kaynağı: `docs/superpowers/specs/torimon-v3-spec.md` (bu belge onu genişletir; çeliştiği iki yer §3'te açıkça yazılıdır).

## 1. Amaç ve başarı ölçütü

Bugün ilk oynanış tahminen 75–110 dakika (30 oda, kabaca 340 satır diyalog). Hedef: ilk oynanışta **yaklaşık 3 saat** süren, her odası bir şey anlatan tek parça bir hikâye.

Başarı ölçütleri:
- İlk oynanış 165–195 dk (her parçadan sonra ölçülür; tahmin değil ölçüm).
- 40 oda; her odada en az 1 hikâye vuruşu ve 1 bulmaca. Saf geçiş odası yok.
- Kanon olayları, karakterler ve tek final (BÖLÜM I SONU / END OF PART I) değişmez.
- Hiçbir yeni bulmaca softlock üretmez; eski kayıtlar açılır.

## 2. Kullanıcı kararları

| Konu | Karar |
|---|---|
| Süre nereden gelecek | Hem mevcut odaları derinleştir hem yeni oda ekle |
| Kanon | Sabit; içi doldurulur |
| Ağırlık | Hikâye + bulmaca dengeli; dövüş seyrek, boss yok |
| Yaklaşım | **B — "Oda hatırlar"**: ~10 yeni oda, yetenek kapılı geri dönüş turları, her bölgede perde sonu doruğu |
| 1927 sahneleri | Oynanmaz; yankı olarak izlenir |
| Shilda ile tanışma | Perde 1 sonunda (ilk odalarda değil) |
| Shilda'nın adı | Perde 2 sonunda, bahçede öğrenilir |

## 3. v3 kanonuna göre bilinçli değişiklikler

1. **§20 (Uyanış):** v3 "Shilda burada doğrudan görünmemelidir" der. Yeni kural: ilk iki odada yalnız izleri vardır; perde sonunda (`awakening_vigil`) ilk kez yüz yüze görülür, konuşmacı adı "???".
2. **§17 (adın öğrenilmesi):** Ad kapısı Perde 2 sonuna, `decay_garden` çiçek sahnesine taşınır.

Başka kanon değişikliği yoktur. §19'daki beş diyalog evresi, §31 final bölümü ve §32 tek son aynen korunur.

## 4. Perdeler ve süre

| Perde | Bölge | Süre | Oda (eski→yeni) | Oyuncunun sorusu | Ara doruk |
|---|---|---|---|---|---|
| 1 | Uyanış | 0–25 dk | 5→6 | Ben kimim, burası neresi? | İlk ölüm; perde sonunda Shilda ile ilk yüz yüze karşılaşma |
| 2 | Çürüme | 25–55 | 5→7 | Ona güvenebilir miyim? | Duvar kovalamacası, ardından bahçede çiçek sahnesi ve **ad** |
| 3 | Kütüphane | 55–90 | 5→7 | Burada ne oldu? | Ruh Kesimi; Shilda'nın insan geçmişi |
| 4 | Deney | 90–125 | 5→7 | Ben neden buradayım? | Denek 14 Noroi'dir; X'in imzası |
| 5 | Aynalar | 125–155 | 5→7 | Kaç kez öldüm, kime güvenebilirim? | 1927 gecesi yankı olarak izlenir; Shilda ile yüzleşme |
| 6 | Çekirdek | 155–185 | 5→6 | Çıkabilir miyiz? | Mühür kırılır, X döner, BÖLÜM I SONU |

Toplam 30→40 oda.

### Perde 1 akışı (Shilda'nın girişi)
- `awakening`, `awakening_passage`: yalnız izler — duran saat, taze kırmızı çiçek, uzak fısıltı.
- `awakening_seal`: ilk ölüm; yeniden doğuşta bir siluet parlaması.
- `awakening_balcony` (yan): siluet uzaktan, sessizce izler.
- `awakening_vigil` (yeni): ilk yüz yüze karşılaşma. Mesafeli; uyarır, saldırmaz. Kısa bir yol gösterir ve gider.

### Geri dönüş turları
- **Tur 1 — Ruh Kesimi sonrası (Perde 3 sonu):** balkondaki mor mühür, `awakening_crypt`, mahzenden `decay_shilda_wall`'a arka kapı, `decay_catacombs` iç mührü. Dönülen eski odalar değişmiştir: yeni kayıtlar, Shilda'nın bıraktığı çiçekler.
- **Tur 2 — Gölge Atılması sonrası (Perde 5):** Çürüme ve Deney'de kırmızı perdeli odalar (`decay_cistern`, `experiment_observation`); Shilda'nın 68 yıllık günlüğünün parçaları.

Turlar isteğe bağlıdır ama ödüllüdür (kanıt kartı, mühür parçası bağlamı). Ana yol turlar yapılmadan da bitirilebilir.

### Tempo kuralları
- Her odada ≥1 hikâye vuruşu ve 1 bulmaca.
- Lanet baskısı Perde 4'ten itibaren anlatının parçası olur (Noroi'nin satırlarına yansır).
- Doruklar bulmaca ya da kaçıştır; boss değildir.

## 5. Oda haritası (40 oda)

Kalın = yeni oda.

| Perde | Ana yol | Yan odalar |
|---|---|---|
| 1 | `awakening` → `awakening_passage` → `awakening_seal` → **`awakening_vigil`** | `awakening_balcony`, `awakening_crypt` (Tur 1'de açılır) |
| 2 | `decay_vines` → `decay_weight` → **`decay_greenhouse`** → `decay_shilda_wall` → `decay_garden` | `decay_catacombs`, **`decay_cistern`** (Tur 2) |
| 3 | `library_hall` → `library_witness` → **`library_clockroom`** → `library_page` | `library_upper_stacks` → `library_forbidden_wing`, **`library_reading_cell`** |
| 4 | `experiment_cells` → **`experiment_intake`** → `experiment_circuit` → `experiment_authority` | `experiment_quarantine`, `experiment_core_conduit`, **`experiment_observation`** (Tur 2) |
| 5 | `mirrors_reverse` → `mirrors_dual` → **`mirrors_gallery`** → `mirrors_unbroken` | `mirrors_labyrinth`, `mirrors_shrine`, **`mirrors_1927`** |
| 6 | `core_threshold` → **`core_ascent`** → `core_seal_chamber` → `core` | `core_memory_vault`, `core_bloom_garden` |

### Yeni odalar

| # | id | Türkçe ad | Yol | İçerik |
|---|---|---|---|---|
| 1 | `awakening_vigil` | Nöbet Odası | ana | Shilda ile ilk karşılaşma |
| 2 | `decay_greenhouse` | Sera | ana | İlk ortak bulmaca: Shilda uzaktan bir mührü tutar |
| 3 | `decay_cistern` | Sarnıç | yan, Tur 2 | Kırmızı perde; ilk günlük parçaları |
| 4 | `library_clockroom` | Saatler Odası | ana | 1927 ve 1995'te durmuş saatler; cep saatine bağlanır |
| 5 | `library_reading_cell` | Okuma Hücresi | yan | Gün çentikleri; Shilda'nın insan döneminin izleri |
| 6 | `experiment_intake` | Kabul Odası | ana | 1995 kabul kayıtları, Noroi'nin eşyaları |
| 7 | `experiment_observation` | Gözlem Camı | yan, Tur 2 | X'in Noroi'nin ölümlerini sayan notları |
| 8 | `mirrors_gallery` | Bedenler Galerisi | ana | Her ölüm bir yansıma; duvarda gerçek ceset sayısı |
| 9 | `mirrors_1927` | Kırık Gece | yan | 1927 gecesi, izlenen yankı |
| 10 | `core_ascent` | Son Merdiven | ana | Ruh Kesimi + Gölge Atılması + yankı + Shilda'nın mührü birleşik bulmaca |

### Yeni yan kapılar
Kaynak oda ve koşul kesindir; kapının oda içindeki x konumu ilgili parçanın planında belirlenir.

| Kaynak | Hedef | Koşul |
|---|---|---|
| `decay_weight` | `decay_cistern` | Gölge Atılması |
| `library_witness` | `library_reading_cell` | yok |
| `experiment_circuit` | `experiment_observation` | Gölge Atılması |
| `mirrors_dual` | `mirrors_1927` | `mirrors_gallery` bulmacası çözülmüş |

### Mevcut odalardaki değişiklikler
- **`decay_shilda_wall` ana yola girer** (bahçeden önce). En büyük yapısal değişiklik: bugün `SIDE_DOORS`'ta `decay_garden` → `decay_shilda_wall` yan kapısıdır; bu kayıt kalkar, oda `decay_greenhouse` ile `decay_garden` arasına bağlanır. Mahzenden gelen arka kapı (Tur 1) kalır.
- `awakening_passage`: yarık yankısı, Noroi'nin önceki bir ölümünden kendi sesi olur.
- `awakening_seal`: ilk ölüm + siluet.
- `decay_vines`: kesilmiş sarmaşıklar ve çiçek izi (biri önden geçmiş).
- `decay_weight`: taşın üstünde çentikler.
- `experiment_core_conduit`: üç kanal üç ses kaydı oynatır.

### Koddan doğrulanan mevcut durum (2026-11-11)
- `scripts/main.gd` `SIDE_DOORS`: 10 kayıt (awakening→balcony, decay_vines→catacombs, decay_garden→shilda_wall, library_hall→upper_stacks, experiment_cells→quarantine, experiment_authority→core_conduit, mirrors_reverse→labyrinth, mirrors_unbroken→shrine, core_threshold→memory_vault, core_seal_chamber→bloom_garden). Kayıtlar `req` ve `msg` alanlarını destekler.
- `awakening_crypt`, `library_forbidden_wing` ve mahzen→duvar kapıları `SIDE_DOORS`'ta değildir; oda sahnelerinde tanımlıdır. Parça 1'de envanteri çıkarılacak.
- `scripts/autoload/room_manager.gd` `ROOM_ORDER`: 30 kayıt, bölge bölge, yan odalar araya karışık. **HUD'daki "ODA NN" numarası bu sıradan gelir**; yeni odalar eklenince numaralar kayar. `ROOM_TITLES_TR` ve `EXTRA_ROOM_SCENE_PATHS` de güncellenir.

## 6. Diyalog planı

### Shilda'nın beş evresi (v3 §19)

| Evre | Ne zaman | Taşıyıcı sahneler |
|---|---|---|
| Mesafeli | Perde 1 sonu – Perde 2 | Nöbet Odası karşılaşması, duvar kovalamacası |
| Merak | Perde 2 sonu – Perde 3 | Bahçe çiçeği + ad |
| Güven | Perde 3–4 | Okuma Hücresi, Kabul Odası |
| Acı | Perde 4 sonu – Perde 5 | Denek 14, Kırık Gece, yüzleşme |
| Ortak amaç | Perde 6 | Son Merdiven, "Gidelim." |

### Hafıza kuralı
- Noroi her ölümde unutur; Shilda unutmaz.
- Bazı Shilda satırları ölüm sayısına göre değişir. Tekrarlanan soruyu fark eder ama açıklamaz.
- Oyuncu bunun anlamını `mirrors_gallery`'de kavrar.
- Mühür noktasında kaydedilen bilgi (ad dahil) kalıcıdır. Mevcut üç katmanlı hafıza sistemi korunur.

### Diğer sesler
- **X:** finalden önce hiç görünmez. Her perdede tek iz: kayıt, imza ya da gözlem notu.
- **Arşivci:** Perde 3'ün rehberi; Tur 1'de yeniden konuşur.
- **Yansıma:** Perde 5'te Noroi'nin önceki bedenlerinin sesleri.
- **Ses (kasa):** Perde 6'da son kayıt.

### Hacim
- Hedef: ~950 satır / ~6.000 kelime (30–35 dk okuma). Bugün ~340 satır.
- Ana yol odası 15–25 satır; yan oda 8–12.
- Kanıt kartı 15 → ~28; her yeni odada en az 1 kart.

### Yazım kuralları
- Kısa satır; kutu başına en çok iki cümle.
- Açıklama diyaloğu yok: bilgi kayıt, kart ve çevreden gelir; karakterler duyguyu konuşur.
- Mevcut satırların çoğu kalır. Yeri değişen sahneler yeniden yazılır: ad sahnesi ve Kütüphane'deki "???" kullanımı.
- Oyun metni Türkçe, UTF-8; ana karakterin adı her yerde Noroi.

## 7. Teknik kapsam

### Diyalog verisi: oda başına bir dosya
Bugün diyalog GDScript çağrılarına (`story_beat.gd`, `keeper_controller.gd`, `final_sequence.gd` vb.) ve sahne `lines`/`dialogue_sets` alanlarına dağınık. 600 yeni satır bu şekilde yazılırsa yönetilemez.

- Yeni satırlar `data/dialogue/<room_id>.json` dosyalarında tutulur (oda başına bir dosya).
- Biçim:
  ```json
  {
    "room": "awakening_vigil",
    "sets": {
      "first_meeting": [
        {"variants": [
          {"when": {"min_deaths": 3}, "s": "@shilda", "t": "..."},
          {"s": "@shilda", "t": "..."}
        ]},
        {"s": "Noroi", "t": "..."}
      ]
    }
  }
  ```
  - `s`: konuşmacı. `@shilda` belirteci `GameState.keeper_speaker_name()` ile çözülür ("???" / "Gölge" / "Shilda").
  - `variants`: yukarıdan aşağı ilk eşleşen `when` seçilir; `when` yoksa varsayılandır.
  - `when` anahtarları: `min_deaths`, `flag`, `not_flag`, `named`, `solved`. Başka anahtar yok.
- Tek okuma noktası: `DialogueData.get_set(room_id, set_id)` → `[speaker, text]` dizisi; `DialogueManager` bunu mevcut `say` yoluyla oynatır. Tüketiciler dosya biçimini bilmez.
- Eksik dosya ya da set hata günlüğüne yazılır ve boş dizi döner; oyun çökmez.
- **Eski satırlar toplu taşınmaz.** Yalnız dokunulan sahne taşınır (ad sahnesi, Kütüphane "???" satırları, değişen oda vuruşları).
- Headless denetim: her JSON ayrıştırılır, bilinmeyen `when` anahtarı ve boş `t` hata sayılır, toplam satır/kelime raporlanır (hacim hedefini ölçer).

### Diğer kod alanları
- `scenes/rooms/`: 10 yeni sahne.
- `room_manager.gd`: `ROOM_ORDER`, `ROOM_TITLES_TR`, `EXTRA_ROOM_SCENE_PATHS`.
- `main.gd`: `SIDE_DOORS` (shilda_wall kaydı kalkar, dört yeni yan kapı eklenir).
- `campaign_objectives.gd`: `_BY_ROOM`'a 10 kayıt; tur odaları için mevcut `awakening_balcony` örneğindeki gibi koşullu metin.
- `story_beat.gd`: Uyanış ve Çürüme için vuruşlar (bugün yalnız Kütüphane'den itibaren var).
- `keeper_controller.gd`: karşılaşma sahnesi, ölüm sayısına duyarlı satırlar, ad kapısının bahçeye taşınması.
- ~13 yeni kanıt kartı; yeni ana yol bulmacalarına üç kademeli ipucu.

### Varlıklar
- Yeni odalar kendi bölgesinin arka plan ve tileset'ini kullanır.
- Yeni prop'lar: saatler, sera camı, sarnıç suyu, gözlem camı, galeri yansımaları, 1927 siluetleri.
- Shilda karşılaşması mevcut animasyonlarla yapılır.
- Ücretli üretim gerekiyorsa önce kullanıcı onayı alınır.

## 8. Parçalara ayırma

Tek planla yapılamayacak kadar büyük. Her parçanın kendi planı, testi ve sürümü olur.

| # | Parça | İçerik |
|---|---|---|
| 1 | Temel | Diyalog veri dosyası yapısı + denetim, 40 odalık grafik (boş iskelet odalar), kapı envanteri, kayıt uyumluluğu |
| 2 | Perde 1 | Uyanış derinleştirme, `awakening_vigil`, karşılaşma |
| 3 | Perde 2 | `decay_greenhouse`, shilda_wall ana yolda, ad sahnesi bahçede |
| 4 | Perde 3 + Tur 1 | `library_clockroom`, `library_reading_cell`, geri dönüş değişiklikleri |
| 5 | Perde 4 | `experiment_intake`, kanal kayıtları |
| 6 | Perde 5 + Tur 2 | `mirrors_gallery`, `mirrors_1927`, `decay_cistern`, `experiment_observation` |
| 7 | Perde 6 + ölçüm | `core_ascent`, tam oynanış süresi ölçümü, tempo ayarı |

Parça 1 bittiğinde oyun baştan sona oynanabilir kalmalıdır: iskelet odalar tek kapılı geçilir, "bitmemiş" içerik oyuncuya sürüm olarak gitmez (Parça 1 yayınlanmaz; Parça 2 ile birlikte çıkar).

## 9. Riskler

| Risk | Önlem |
|---|---|
| Eski kayıtlar oda sırası değişince bozulur | Kayıtlar oda kimliğiyle tutulur; Parça 1'de kural: kayıttaki odadan önce gelen yeni ana yol odalarının kapıları açık sayılır, içerikleri ziyaret edilebilir kalır. Ad zaten öğrenilmişse öğrenilmiş kalır. v1.9.0 kaydıyla yükleme testi şart |
| "ODA NN" numaraları kayar | Kabul edilir; numara yalnız HUD etiketidir. Kayıt ya da mantık numaraya bağlıysa Parça 1'de bulunup kimliğe çevrilir |
| Oyuncu turlarda kaybolur | Koşullu hedef metni + her tur için Shilda'dan tek yönlendirme satırı |
| 3 saat hedefi tutmaz | Her parçadan sonra süre ölçülür; Parça 7'de tempo ayarı |
| Diyalog hacmi tempoyu boğar | Kutu başına iki cümle kuralı; denetim satır/kelime sayısını raporlar |
| shilda_wall ana yola girince kovalamaca zorunlu olur, takılan oyuncu ilerleyemez | Üç kademeli ipucu + üç ölümden sonra kolaylaştırma |

## 10. Test

- Headless denetimler 40 odayı, her odanın en az bir giriş ve çıkışını, tüm hedef metinlerini doğrular.
- Her yeni bulmaca için softlock testi (ölüm, yeniden doğuş, odadan çıkıp girme).
- Diyalog verisi denetimi (§7).
- Her parçadan sonra `TORIMON_TEST=1` testleri ve 1920x1080 render kontrolü.
- Eski kayıt yükleme testi (Parça 1 ve shilda_wall değişikliğinin olduğu Parça 3).

## 11. Kapsam dışı

- Yeni son, yeni karakter, boss dövüşü.
- Oynanabilir 1927 bölümü.
- Eski diyalogların toplu veri dosyasına taşınması.
- Seslendirme, çeviri, yeni müzik.
- Bölüm II içeriği.
