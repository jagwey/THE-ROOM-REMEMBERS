extends Area2D
## Visible memory fracture. Warn, allow retreat, then deal one avoidable heart of damage.
## ring_radius > 0: dönen diken halkası. Hitbox çizilen halkayla aynıdır (delik ve boşluk güvenli).

@export var hazard_id: StringName = &"awakening_rift"
@export var arm_requires_mystery: bool = true
## Geçit tehlikeleri: tek temasta yalnızca bir kalp (ölüm döngüsü yok).
@export var passage_one_heart_cap: bool = false
## Tek temas öldürür. CorpseDrop varsa ceset oraya, sağlam zemine konur.
@export var lethal: bool = false
## Dış yarıçap (px). 0 ise eski dikdörtgen çarpışma.
@export var ring_radius: float = 0.0
## Delik yarıçapı. Bu mesafenin içi güvenli. 0 ise ring_radius'un yarısı.
@export var ring_hole: float = 0.0
## Dönüşte açık kalan sektör (derece). Yerden geçiş penceresi.
@export var ring_gap_deg: float = 140.0
## rad/s. Yavaş dönüş, boşluğun okunması için.
@export var ring_spin: float = 0.55
## Doğuş / yeniden doğuşta bu kadar saniye temas öldürmez.
@export var arm_grace: float = 0.0

var _armed: bool = false
var _warned: bool = false
var _warning_open: bool = false
var _grace: float = 0.0
var _hit_cooldown: float = 0.0
var _hits_this_life: int = 0
## Boşluğun baktığı açı. PI = sola (girişe) açık başlar.
var _spin: float = PI


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	visible = false
	var hid: String = String(hazard_id)
	if hid.begins_with("passage_"):
		passage_one_heart_cap = true
	if DeathManager.has_signal("rebirth_completed") and not DeathManager.rebirth_completed.is_connected(_on_rebirth_completed):
		DeathManager.rebirth_completed.connect(_on_rebirth_completed)
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		s.texture = load("res://assets/props/halo.png")
		s.modulate = Color(0.95, 0.28, 0.35, 0.8)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ring_radius > 0.0:
		if ring_hole <= 0.0:
			ring_hole = ring_radius * 0.5
		_grace = arm_grace
		_spin = PI
		z_index = 6
		var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs:
			cs.disabled = true
		var spr := get_node_or_null("Sprite2D") as CanvasItem
		if spr:
			spr.visible = false


func _process(delta: float) -> void:
	if not _armed:
		var pk: Dictionary = GameState.player_progress_knowledge
		var mystery_ok: bool = (
			bool(pk.get("awakening_mystery_seen", false))
			or bool(pk.get("pocket_watch_seen", false))
			or bool(GameState.get_world_flag(&"intro_completed", false))
			or bool(GameState.get_world_flag(&"pocket_watch_seen", false))
			or bool(GameState.get_world_flag(&"awakening_mystery_seen", false))
		)
		if not arm_requires_mystery or mystery_ok:
			_armed = true
			visible = true
			GameState.set_world_flag(&"hazard_rift_seen", true)
		return
	if UiGate.pauses_world_threats() or not is_visible_in_tree() or _warning_open:
		return
	if ring_radius > 0.0:
		_spin = wrapf(_spin + ring_spin * delta, -PI, PI)
		queue_redraw()
	_grace = maxf(0.0, _grace - delta)
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	var bodies: Array = get_overlapping_bodies() if ring_radius <= 0.0 else _ring_bodies()
	for body in bodies:
		if not body.is_in_group("player"):
			continue
		if lethal:
			if DeathManager.is_dying or _grace > 0.0:
				return
			var drop := get_node_or_null("CorpseDrop") as Node2D
			if drop != null and body.has_method("note_safe_floor"):
				body.note_safe_floor(drop.global_position)
			DeathManager.request_death(&"hazard")
			return
		if not _warned:
			_warn(body)
			return
		if _grace <= 0.0 and _hit_cooldown <= 0.0 and body.has_method("receive_hazard_hit"):
			if passage_one_heart_cap and _hits_this_life >= 1:
				continue
			if body.receive_hazard_hit(global_position.x):
				_hit_cooldown = 2.0
				_hits_this_life += 1
				GameState.set_world_flag(&"awakening_trap_sprung", true)


func _draw() -> void:
	if ring_radius <= 0.0 or ring_hole >= ring_radius:
		return
	var gap := deg_to_rad(clampf(ring_gap_deg, 0.0, 300.0))
	var start := _spin + gap * 0.5
	var sweep := TAU - gap
	var mid_r := (ring_radius + ring_hole) * 0.5
	var band := ring_radius - ring_hole
	var crimson := Color(0.86, 0.12, 0.18, 0.92)
	var hot := Color(1.0, 0.55, 0.48, 0.95)
	draw_arc(Vector2.ZERO, mid_r, start, start + sweep, 36, crimson, band, true)
	draw_arc(Vector2.ZERO, ring_radius - 1.5, start, start + sweep, 36, hot, 2.0, true)
	var spikes := 8
	for i in spikes:
		var a := start + sweep * (float(i) + 0.5) / float(spikes)
		var dir := Vector2.from_angle(a)
		draw_line(dir * ring_hole, dir * (ring_radius + 7.0), crimson, 3.0)
	## Boşluğun iki kenarı: geçiş penceresi.
	var edge_a := Vector2.from_angle(start)
	var edge_b := Vector2.from_angle(start + sweep)
	draw_line(edge_a * ring_hole, edge_a * ring_radius, hot, 2.0)
	draw_line(edge_b * ring_hole, edge_b * ring_radius, hot, 2.0)


## Test ve çarpışma: dünya noktası halka bandında ve boşluğun dışında mı.
func blocks_point(world: Vector2) -> bool:
	if ring_radius <= 0.0:
		return false
	var dvec := world - global_position
	var dist := dvec.length()
	if dist < ring_hole or dist > ring_radius:
		return false
	if ring_gap_deg <= 0.0:
		return true
	var delta := absf(wrapf(atan2(dvec.y, dvec.x) - _spin, -PI, PI))
	return delta > deg_to_rad(ring_gap_deg) * 0.5


func set_ring_phase(angle: float) -> void:
	_spin = wrapf(angle, -PI, PI)


## Ayak noktasına oturan oyuncu kapsülü (varsayılan 18×36) bu fazda güvende mi.
func feet_clear(feet: Vector2, body: Node2D = null) -> bool:
	var size := Vector2(18, 36)
	var origin := Vector2(0, -18)
	var src: Node = body if body != null else get_tree().get_first_node_in_group("player")
	if src:
		var cs := src.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			size = (cs.shape as RectangleShape2D).size
			origin = cs.position
	var center := feet + origin
	var half := size * 0.5
	for ix in 3:
		for iy in 3:
			var p := center + Vector2(lerpf(-half.x, half.x, float(ix) / 2.0), lerpf(-half.y, half.y, float(iy) / 2.0))
			if blocks_point(p):
				return false
	return true


func _ring_bodies() -> Array:
	var found: Array = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return found
	var feet := player.global_position
	if not feet_clear(feet, player):
		found.append(player)
	return found


func _warn(_body: Node) -> void:
	_warned = true
	_warning_open = true
	DialogueManager.say("Shilda", "Geri çekil. O yarık anını yer. Dar olanın üstünden atıl (%s)." % MobileInputManager.control_name(&"dash"))
	await DialogueManager.dialogue_finished
	# Time starts after the player can actually move, never during the warning dialogue.
	_grace = 4.0
	_warning_open = false


func _on_rebirth_completed() -> void:
	_hits_this_life = 0
	_grace = maxf(_grace, arm_grace)
