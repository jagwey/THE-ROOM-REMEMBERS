extends Node2D
## Ruh Damarları Kanalı (experiment_core_conduit): üç damar sırayla kesilir (kalp, sol, uç).
## Son damar çözülünce `experiment_conduit` çözülür. Eski kayıt: kanal çözülmüşse damarlar açık sayılır.

const VEIN_IDS: Array[StringName] = [&"experiment_vein_1", &"experiment_vein_2", &"experiment_vein_3"]
const SOLVE_ID := &"experiment_conduit"


func _ready() -> void:
	PuzzleManager.puzzle_solved.connect(_on_solved)
	if PuzzleManager.is_solved(SOLVE_ID):
		for v in VEIN_IDS:
			if not PuzzleManager.is_solved(v):
				PuzzleManager.mark_solved(v)
	elif PuzzleManager.is_solved(VEIN_IDS[2]):
		PuzzleManager.mark_solved(SOLVE_ID)


func _on_solved(id: StringName) -> void:
	if id == VEIN_IDS[2] and not PuzzleManager.is_solved(SOLVE_ID):
		PuzzleManager.mark_solved(SOLVE_ID)
		DialogueManager.whisper("Noroi", "Enerji Çekirdek'e yönlendi, ışıklar yandı.")
		SaveManager.save_game()
