extends SceneTree
## UpdateChecker.is_newer sürüm karşılaştırma testi (ağ yok).
const UC := preload("res://scripts/autoload/update_checker.gd")

func _init() -> void:
	var f := 0
	var cases := [["v1.4.2","1.4.1",true],["v1.4.1","1.4.1",false],["v1.4.0","1.4.1",false],["v1.10.0","1.9.9",true],["v2.0","1.99.99",true],["1.4.1","v1.4.1",false],["",  "1.4.1",false]]
	for c in cases:
		var got: bool = UC.is_newer(c[0], c[1])
		if got != c[2]:
			f += 1
			print("UPDATE FAIL %s vs %s -> %s" % [c[0], c[1], got])
		else:
			print("UPDATE PASS %s vs %s" % [c[0], c[1]])
	print("UPDATE_AUDIT failures=%d" % f)
	quit(f)
