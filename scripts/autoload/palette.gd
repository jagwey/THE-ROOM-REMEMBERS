extends Node
## Moodboard paleti — void / stone / ivory / crimson.

const VOID := Color("#221B27")
const DEEP_STONE := Color("#322A39")
const STONE := Color("#493F51")
const PALE_LILAC := Color("#AB98A9")
const IVORY := Color("#E1D3D1")
const CRIMSON := Color("#7E2D3A")
const DARK_RED := Color("#521D29")

## Tekrarlanan altın / mavi / yeşil vurgular (eski dağınık literaller).
const GOLD := Color(1.0, 0.82, 0.5)
const GOLD_DIM := Color(0.78, 0.62, 0.3, 0.75)
const SHIELD_BLUE := Color(0.75, 0.85, 1.0, 0.65)
const SHIELD_BLUE_DOWN := Color(0.75, 0.85, 1.0, 0.12)
const SOLVED_GREEN := Color(0.6, 0.9, 0.7, 1.0)

## Sıra taşı ipuçları: renk körlüğü için hem ton hem parlaklık değişir.
const SEQUENCE_TINTS: Array[Color] = [
	Color(1.0, 0.82, 0.35),
	Color(0.3, 0.45, 1.0),
	Color(0.5, 1.0, 0.55),
	Color(0.7, 0.18, 0.25),
	Color(0.6, 1.0, 1.0),
	Color(0.5, 0.3, 0.75),
	Color(1.0, 0.5, 0.15),
	Color(0.95, 0.9, 1.0),
]
