extends Node
## Audit sahte HUD: MemorySeal prompt_seal_code yerine next_code dondurur.
var next_code: String = ""


func prompt_seal_code() -> String:
	await get_tree().process_frame
	return next_code
