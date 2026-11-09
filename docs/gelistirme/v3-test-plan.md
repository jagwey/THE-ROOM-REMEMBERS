# v3 Test Plani (spec §36 haritasi)

Calistirma: `docs/gelistirme/Run-Audit.ps1 -ProjectPath <repo> -GodotPath <godot-console.exe>` (izole kopya, `TORIMON_TEST=1`).
Elle tek audit: `TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/<ad>_audit.gd` (start_flow icin ek `TORIMON_FORCE_TITLE=1`).
Smoke: `TORIMON_SMOKE=1 godot --headless --path .` (faz67, cikis kodu 0 beklenir). Son sonuclar: `.superpowers/sdd/v3-story-overhaul/task-11b-report.md`.

Run-Audit kapsami: lore_canon, story_flags, save_split, memory_seal, curse_reload, final_sequence, save_quit, start_flow, death_loop, interact, ui_header_portrait, keeper_naming, release, controls, door, push, jump, eye_intro, room_header_fit, save_robust, resume_m3, update_check, m1_stress, e2e_runner, faz67 smoke.
`-IncludeLegacy` eski `audit.gd` (v0.10.1) senaryolarini da calistirir; bu senaryolar v3 oncesidir ve `seal` senaryosu AUDIT_TIMEOUT verir (bkz. "Bilinen bosluklar").

## §36 maddeleri -> kapsam

### Hareket
| Madde | Kapsam |
|---|---|
| Oyun baslayinca kendiliginden kosmama | start_flow ("player not blocked after the opening", baslik kapaninca UiGate NONE); pencereli tur (opening) ekran goruntusu. Dogrudan "hareket vektoru sifir" assert'i yok. |
| Joystick birakilinca durma | m1_stress ("respawn_at() resets state to idle"), death_loop (ölüm sonrasi girdi temizligi), MobileInputManager.clear_held_inputs final/ölüm yollarinda kullanilir. Gercek joystick: kapsam disi. |
| Ziplama tutarli | jump_audit (13 assert: tam/kisa ziplama, coyote, buffer, cift ziplama yok, inis sesi bir kez) |
| Dash duvara sokmama | controls_audit (dash cooldown, curse barrier normal dash'i durdurur), door_audit (z/collision), push_audit; duvara dash icin ozel assert yok. |

### Diyalog
| Madde | Kapsam |
|---|---|
| Konusmada kontrol durur | controls_audit ("story freezes both horizontal and vertical physics", "pauses threats") |
| Bitince kontrol geri | eye_intro_audit ("gate released after intro"), final_sequence_audit ("input released after final"), start_flow, interact_audit (debounce sonrasi etkilesim) |
| Gorunmez panel kalmamasi | start_flow (UiGate NONE 10 sn sonra, Menu dugmesi merkezi kapatmaz), ui_header_portrait (journal diger katmanlarda bloklu), room_header_fit |

### Kayit
| Madde | Kapsam |
|---|---|
| Her Hafiza Muhru | memory_seal_audit (100 assert: her muhur tehlike/dusman uzakligi, kesif, seyahat, uyku noktalari) |
| Yanlis odada dogmama | save_split_audit (committed vs resume, bozuk dosya yedegi, eksik yasam -> varsayilan checkpoint), save_quit_audit, resume_m3_audit, save_robust_audit, curse_reload (guvenli konum) |
| Bulmaca/kapi kalicigi | save_split / save_robust (puzzle + dunya durumu roundtrip), e2e_runner (Tier 3 kayit kombinasyonlari), story_flags_audit (v5/v6 gocu, bayrak roundtrip) |

### Normal olum
| Madde | Kapsam |
|---|---|
| Eski beden olusur | death_loop_audit ("corpse node exists in far room", dongu basina ceset sayisi), controls_audit |
| Ruh ayrilma animasyonu | death_loop ("phases DYING>SOUL_RELEASE>SOUL_TRANSITION>RESPAWNING>ALIVE"); pencereli ekran goruntusu |
| Dogru konumda yeniden dogus | death_loop ("far death respawns in awakening", "awakening seal near bed", "rebirth completes without input"); yatak ekran goruntusu |
| Dunya kalici degisiklikleri | death_loop / m1_stress (kirik duvar yeniden giriste kirik kalir), e2e_runner |

### Lanet
| Madde | Kapsam |
|---|---|
| %100 ele gecirilme bir kez | curse_reload_audit ("first possession ~4.5s", possession_count 1/2/3, olum sayisi degismez) |
| Ekran kararmasi | curse_reload (possession tamamlanir, kontrol geri); pencereli lanet ekran goruntuleri (possession_mid / possession) |
| Son kayit yuklenir | curse_reload ("spawn at committed safe position"), save_split |
| Lanet guvenli seviyede baslar | curse_reload (band 0/1/2/3 esikleri, meter 50'den gorunur), save_split (yeni oyun) |
| Ekstra ceset olusmaz | curse_reload ("corpse count unchanged", "no death/soul/bed phases") |

### Shilda
| Madde | Kapsam |
|---|---|
| Cok erken gorunmez | keeper_naming_audit ("awakening before first death: keeper hidden"), interact_audit |
| Ad dogru asamada | keeper_naming_audit (isim sahnesi 12 satir sirayla, sonra "named"), interact_audit (adsiz "???" etiketi), ui_header_portrait (konusmaci sozlesmesi, ad zorlanmaz), story_flags |
| Animasyonlar durumlara bagli | controls_audit (combat gir/cik), ui_header_portrait (portre eslesmesi); animasyon gecis kalitesi elle |
| Saldirilar haksiz kilitlemez | controls_audit ("first contact is survivable", "one contact costs only one heart", "repeat contact cooldown"), m1_stress, death_loop (combat abort) |

### Final
| Madde | Kapsam |
|---|---|
| Ana muhur yalniz dogru kosulda | controls_audit ("final locked without both shards", "final open with both shards + soul slash"), final_sequence_audit ("final locked without Soul Slash") |
| Shilda insan formu | final_sequence_audit ("Shilda human form shown"); pencereli final ekran goruntusu (YER TUTUCU gorsel) |
| X sahnesi dogru sirada | final_sequence_audit (bayrak sirasi final_seal_broken -> x_revealed -> game_completed, 18 satir sirasi) |
| Jenerik tek finalden sonra | final_sequence_audit (enum yalniz NONE/PART_ONE, END OF PART I etiketi, kredi, baslik donusu, final_seen), start_flow (Jenerik sayfasi), e2e_runner |

## Lore ve metin
lore_canon_audit (yasak desen yok, 1927/1995 kanonu, satir uzunlugu <=120 hata / >90 uyari), ui_header_portrait (konusmaci sozlesmesi), release_audit (111 kontrol: surum, paket, yeni oyun).

## Ekran goruntusu turu (pencereli 1920x1080, elle incelendi)
title, opening, seal, curse (band >=70 + possession), olum yeniden dogus (yatak), isim sahnesi, final (X belirisi, DOMAIN paneli, END OF PART I). Dosyalar ve gozlemler raporda.

## Otomatik KAPSANMAYAN
- Hissiyat/zamanlama: ziplama/dash hissi, diyalog tempo, final akis suresi, ele gecirilme ve yeniden dogus gecis ritmi, ses karisimi.
- Yer tutucu gorseller: Shilda insan formu (soluk ton + hale), X (FinalXActor siluet), DOMAIN 01-04 panelleri, portal. Nihai sanat yok; yalniz "gorunur ve okunur" diye ekran goruntusunden kontrol edildi.
- Android cihazda titresim/haptics, gercek dokunmatik joystick, ekran kenari "geri" jesti, POCO X6 Pro cihaz testi. Yalniz masaustu girdi ve headless simule edilir.
- Joystick birakma ve "oyun baslayinca kendiliginden kosma" icin ozel hareket-vektoru assert'i yok (dolayli).
- Dash'in duvara girmemesi icin ozel assert yok (dolayli: controls/door/push).
- Esc ile final sirasinda duraklatma menusu: kod analizi (SkipListener olayi tuketir; `open_menu` cutscene/STORY katmaninda reddeder), otomatik assert yok.
- Dogal oyun rotasi: audit'ler fixture ile bayrak kurar; bastan sona insan oynayisi yapilmadi.
- Bilinen bosluklar: eski `audit.gd` senaryolari (`-IncludeLegacy`) v3 oncesi; `seal` senaryosu zaman asimina ugrar ve `ending_touch` silinen endinglere dayanir. Bunlar v3 kapsami disi, varsayilan kosuda yok. story_flags_audit'te onceden var olan "current_scene is null" kosul notu (11a).
