extends "res://scripts/world/code_seal_base.gd"
## Arşiv mührü — bahçe çiçeğinden hatırlanan kod (memory_codes["decay_archive"]).


func _init() -> void:
	code_key = "decay_archive"
	puzzle_id = &"decay_archive_key"
	story_code = "729"
	intro_line = "…Semboller var. Bir anahtar gibi."
	solved_line = "Arşiv kapısı… gevşedi."
	wrong_line = "…Yanlış. Mühür sert."
