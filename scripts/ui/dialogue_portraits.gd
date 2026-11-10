extends RefCounted
## Diyalog portre eşlemesi (konuşmacı -> illüstrasyon). class_name yok: preload ile kullanılır.

const PATHS := {
	&"noroi": "res://assets/portraits/portrait_noroi.png",
	&"noroi_sad": "res://assets/portraits/portrait_noroi_sad.png",
	&"shilda": "res://assets/portraits/portrait_shilda.png",
	## Adı bilinmeyen Shilda ("???"): ayrı siluet asset.
	&"shilda_unknown": "res://assets/portraits/portrait_unknown.png",
	## Kurucu X / X? — soğuk siluet.
	&"x_unknown": "res://assets/portraits/portrait_x.png",
}
## Portre kutusu görünürken metin sütunundan düşülen genişlik (px).
const TEXT_INSET := 78.0

static var _cache: Dictionary = {}


## Konuşmacı -> portre anahtarı; portresiz konuşmacı için &"".
## "" / "Sistem" / "Kayıt" portresiz. "Shilda" portrait_shilda, "???" karartılmış siluet (shilda_unknown). Noroi: fısıltı veya yas bağlamında "sad".
static func key_for(speaker: String, sad: bool = false) -> StringName:
	match speaker.strip_edges():
		"Noroi":
			return &"noroi_sad" if sad else &"noroi"
		"???":
			return &"shilda_unknown"
		"Shilda":
			return &"shilda"
		"X?", "X":
			return &"x_unknown"
	return &""


static func has_portrait(speaker: String) -> bool:
	return key_for(speaker) != &""


## Küçültmede yumuşak görünsün diye mipmap üretilmiş doku (kaynak 256x256).
static func texture_for(key: StringName) -> Texture2D:
	if not PATHS.has(key):
		return null
	if _cache.has(key):
		return _cache[key]
	var base := load(PATHS[key]) as Texture2D
	var out: Texture2D = base
	if base:
		var img := base.get_image()
		if img != null and not img.is_empty() and not img.is_compressed():
			img.generate_mipmaps()
			out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out
