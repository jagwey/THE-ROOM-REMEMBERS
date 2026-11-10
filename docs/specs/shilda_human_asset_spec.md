# SHILDA HUMAN FORM — Art & Technical Asset Specification
**Document ID**: `docs/specs/shilda_human_asset_spec.md`  
**Character**: Shilda (Human Form / Araştırma Yardımcısı S.)  
**Engine & Target**: Godot 4.7.2 (GL Compatibility, 640x360 Base Viewport)  
**Milestone**: Milestone 2, Feature 13  
**Status**: APPROVED SPECIFICATION  

---

## 1. Narrative & Visual Concept

### 1.1 Lore Background
In 1927, Shilda served as Founder X's primary research assistant ("Araştırma Yardımcısı S.") in the original dimension facility. Following the 1927 cataclysmic resonance disaster, Shilda was bound to the Memory Core as its supernatural Guardian (Bekçi). For 68 years (1927–1995), she existed in an elongated, 1.6x supernatural form adorned with ceremonial robes, a floating golden-crimson halo, and red spider lily motifs.

In the canonical ending of Part I, Noroi shatters the Core Seal using the Soul Slash. The metaphysical tether snaps:
1. The floating halo ornament shatters into dispersing light motes.
2. Her elongated body (104px height) compresses down to standard mortal human height (48px height, matching Noroi's 1.0x human scale).
3. Her grand ceremonial robes dissolve into a modest 1927 assistant's dark research tunic with an ivory collar.
4. She looks at her own hands in awe: *"Ellerim... Sanırım... sonunda bitti."*

---

## 2. Canvas, Dimensions & Bounding Hierarchy

| Parameter | Specification | Technical Rationale |
| :--- | :--- | :--- |
| **Frame Canvas Size** | **64 × 64 pixels** | Matches pixel grid standard; power-of-two texture alignment. |
| **Visible Body Bounding Box** | **32 × 48 pixels** (W × H) | 1.0x scale relative to Noroi (Noroi is ~30×46 px). Replaces the 1.6x 104×128 Guardian frame. |
| **Foot Baseline Anchor** | **y = 54 px** (from top of 64×64 frame) | Foot contact sits at +10px below origin `(0, 0)` so `offset = Vector2(0, -22)` aligns with floor. |
| **Collision Shape (Physics)** | `RectangleShape2D(16, 44)` | Position `Vector2(0, -22)`. Standard side-scroller humanoid collision. |
| **Hurtbox / Interact Reach** | `Area2D` with `RectangleShape2D(28, 48)` | Position `Vector2(0, -24)`, collision layer 8 (interactable). |
| **Texture Filtering** | `CanvasItem.TEXTURE_FILTER_NEAREST` | Crisp gothic pixel art, zero blur on mobile scaling. |

---

## 3. Official Color Palette

Strict adherence to the 6-ramp gothic palette ensuring immediate contrast against dark backgrounds and seamless alignment with Noroi's visual language:

```
[Hair & Highlights]
#FFFFFF - Pure Glint (specular tip of hair)
#E8E4EC - Silver White (primary hair fill)
#C5BED0 - Dusky Silver (hair midtone & shadow)
#8E869B - Shadow Slate (deep hair separation)

[Skin & Flesh]
#F4EBE6 - Alabaster Porcelain (human highlight, warm mortal skin)
#DFCDC5 - Soft Blush (skin midtone)
#B89E94 - Mortal Ochre (skin shadow & facial contours)
#7A6258 - Deep Ochre (eyelids, nostril, neck crevice)

[Eyes]
#5B6676 - Human Slate Blue (iris highlight, clear human eyes)
#3A414D - Deep Slate (pupil & iris border, no supernatural glow)
#1A1D24 - Obsidian Black (eyelashes & brow)

[1927 Research Assistant Tunic]
#EDE8DD - Aged Ivory (collar, cuff trims)
#C7C1B4 - Tarnished Ivory (collar shadow)
#4E495D - Faded Wool Slate (coat highlights)
#35323F - Dark Charcoal Tunic (coat primary fabric)
#222028 - Abyss Charcoal (deep coat folds & trousers)
#15141A - Boot Leather & Shadow

[Accents & Memory]
#8B2533 - Faded Crimson Ribbon (memory of the spider lily, worn at collar)
#56151E - Crimson Shadow
#9E8858 - Tarnished Brass (assistant's pocket watch chain / pen clip)
```

---

## 4. Animation Specifications (5 Required Cycles)

### 4.1 Animation 1: `idle` (Human Breathing)
- **Framerate**: 6 FPS (166 ms per frame)
- **Loop**: `true`
- **Frame Count**: 6 frames
- **Motion Breakdown**:
  - Frame 0–1: Rest posture. Arms resting naturally at sides, shoulders dropped, hair resting.
  - Frame 2–3: Chest expands upward by 1px, chin lifts slightly (0.5px), hair shifts downward.
  - Frame 4–5: Exhalation, shoulders settle down to baseline.
- **Key Invariant**: Feet remain strictly locked on baseline y=54 (0px drift). Zero floating/levitation.

### 4.2 Animation 2: `walk` (Mortal Stride)
- **Framerate**: 8 FPS (125 ms per frame)
- **Loop**: `true`
- **Frame Count**: 8 frames
- **Motion Breakdown**:
  - Frame 0: Left foot forward plant, torso lowers 1px.
  - Frame 1: Left leg passing, torso rises to apex.
  - Frame 2: Right leg thrust, left heel leaves ground.
  - Frame 3: Right leg passing through center.
  - Frame 4: Right foot forward plant, torso lowers 1px.
  - Frame 5: Right leg passing, torso rises to apex.
  - Frame 6: Left leg thrust, right heel leaves ground.
  - Frame 7: Left leg passing through center.
- **Key Invariant**: Normal human stride with ground friction; no ethereal gliding or robe trail. Stride covers ~95 px/sec.

### 4.3 Animation 3: `transform` (Mortal Transfiguration)
- **Framerate**: 8 FPS (125 ms per frame)
- **Loop**: `false` (One-shot)
- **Frame Count**: 10 frames
- **Motion Breakdown**:
  - Frame 0–1: Halo behind head flickers and splits into crystalline fragments.
  - Frame 2–3: Pure white flash envelops body; Guardian silhouette contracts rapidly from 104px down to 48px.
  - Frame 4–5: Light dissipates; assistant tunic emerges with fabric settling.
  - Frame 6–7: Shilda stumbles slightly forward on mortal legs, catching herself.
  - Frame 8–9: She raises both hands in front of her chest, fingers trembling, turning palms upward in disbelief (*"Ellerim..."*).

### 4.4 Animation 4: `mourn` / `kneel` (Cradling Noroi)
- **Framerate**: 6 FPS (166 ms per frame)
- **Loop**: `true` (Holds on loop after landing)
- **Frame Count**: 6 frames
- **Motion Breakdown**:
  - Frame 0–1: Drops to one knee beside Noroi's collapsed body.
  - Frame 2–3: Reaches out right hand, resting palm gently on Noroi's shoulder.
  - Frame 4–5: Leans in close, head bowed, shoulders trembling slightly as she speaks (*"Noroi... beni duyuyor musun?"*).

### 4.5 Animation 5: `look_back` (Interrupted Hope)
- **Framerate**: 6 FPS (166 ms per frame)
- **Loop**: `false` (One-shot, holds final frame)
- **Frame Count**: 6 frames
- **Motion Breakdown**:
  - Frame 0: Walking stance toward exit door.
  - Frame 1: Sharp freeze upon hearing X's hidden voice (*"Demek sonunda başardınız."*).
  - Frame 2–3: Head and shoulders pivot slowly clockwise (180° turn toward camera/darkness).
  - Frame 4–5: Full body turns around; right foot steps back defensively in shock as Founder X materializes.

---

## 5. Dialogue Portraits (3 Expressions)

Portraits are formatted at **384 × 384 pixels** master resolution (matching `addons/trr_shilda_white/portraits/` standard), rendered with NEAREST filtering and mipmaps for HUD display inside `DialoguePortraits`:

### 5.1 Portrait 1: `shilda_human_neutral`
- **File**: `res://assets/portraits/shilda_human_neutral.png`
- **Expression**: Gentle human relief, soft eyes, faint melancholic smile.
- **Features**: Hair neatly parted without ornament; collar of 1927 tunic visible; warm mortal skin tones; NO halo behind head.
- **Context**: Used during lines: *"Ellerim..."*, *"Sanırım... sonunda bitti."*, *"Gidelim."*

### 5.2 Portrait 2: `shilda_human_sorrow`
- **File**: `res://assets/portraits/shilda_human_sorrow.png`
- **Expression**: Shock, heartbreak, trembling lips, wide pupils reflecting tragedy.
- **Features**: Slight shadow under eyes, stray hair strand across forehead, hand clutching chest collar.
- **Context**: Used during lines: *"Kurucu...?"*, *"Bunca insan..."*, *"O patlama... Bir kaza değil miydi?"*, *"Noroi!"*, *"Ona ne yaptınız?"*

### 5.3 Portrait 3: `shilda_human_resolute`
- **File**: `res://assets/portraits/shilda_human_resolute.png`
- **Expression**: Fierce, protective determination facing X, furrowed brow, jaw set firm.
- **Features**: Focused forward gaze directly challenging the Founder despite having lost her supernatural powers.
- **Context**: Used during lines: *"Bizi neden kurtarmadınız?"*, *"Noroi... beni duyuyor musun?"*

---

## 6. Engine Integration Architecture

### 6.1 `SpriteFrames` Resource (`res://assets/characters/shilda_human.tres`)
```gdscript
[gd_resource type="SpriteFrames" format=3]

[ext_resource type="Texture2D" path="res://assets/characters/shilda_human_sheet.png" id="1"]

# SubResource AtlasTexture definitions for 64x64 regions
# Grid: 8 columns x 5 rows (512 x 320 px master spritesheet)
# Row 0 (0-5):   idle (6 frames)
# Row 1 (0-7):   walk (8 frames)
# Row 2 (0-9):   transform (10 frames)
# Row 3 (0-5):   mourn (6 frames)
# Row 4 (0-5):   look_back (6 frames)
```

### 6.2 Switching SpriteFrames in `final_sequence.gd`
```gdscript
func _shilda_human() -> void:
    _stage(&"shilda_human")
    if _keeper == null:
        last_run["human"] = true
        return
    var spr := _keeper.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
    var human_frames := load("res://assets/characters/shilda_human.tres") as SpriteFrames
    
    # 1. Play transformation sequence with glow aura
    var glow := _make_glow(Color(1.0, 0.95, 0.85, 1.0), 54.0)
    _scene.add_child(glow)
    glow.global_position = _keeper.global_position + Vector2(0, -34)
    glow.z_index = 7
    
    if human_frames != null and spr != null:
        spr.sprite_frames = human_frames
        spr.play("transform")
        await spr.animation_finished
        spr.play("idle")
    else:
        # Fallback tint tween if sprite sheet pending art delivery
        var t := _keeper.create_tween().set_parallel(true)
        t.tween_property(_keeper, "modulate", Color(1.35, 1.3, 1.25, 1.0), 1.4)
        if spr != null:
            t.tween_property(spr, "scale", spr.scale * 0.94, 1.4)
        await _wait(1.4)
        
    last_run["human"] = true
```

### 6.3 DialoguePortraits Registration in `dialogue_portraits.gd`
```gdscript
const PATHS := {
    &"noroi": "res://assets/portraits/portrait_noroi.png",
    &"noroi_sad": "res://assets/portraits/portrait_noroi_sad.png",
    &"shilda": "res://assets/portraits/portrait_shilda.png",
    &"shilda_unknown": "res://assets/portraits/portrait_shilda.png",
    &"shilda_human_neutral": "res://assets/portraits/shilda_human_neutral.png",
    &"shilda_human_sorrow": "res://assets/portraits/shilda_human_sorrow.png",
    &"shilda_human_resolute": "res://assets/portraits/shilda_human_resolute.png",
}
```
