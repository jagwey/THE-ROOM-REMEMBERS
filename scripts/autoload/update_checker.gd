extends Node
## Public release repo'sundan (jagwey/THE-ROOM-REMEMBERS-release) en son sürümü kontrol eder.
## Kaynak repo private; token KULLANILMAZ. Yeni sürüm varsa `update_available` yayınlanır,
## başlık ekranı "Güncelle" düğmesi gösterir ve APK indirme bağlantısını açar.

signal update_available(version: String, url: String)

const RELEASE_REPO := "jagwey/THE-ROOM-REMEMBERS-release"
const API_URL := "https://api.github.com/repos/" + RELEASE_REPO + "/releases/latest"
const RELEASES_PAGE := "https://github.com/" + RELEASE_REPO + "/releases/latest"

var latest_version: String = ""
var download_url: String = ""
var has_update: bool = false

var _http: HTTPRequest


func _ready() -> void:
	if OS.get_environment("TORIMON_TEST") == "1" or DisplayServer.get_name() == "headless":
		return
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: TheRoomRemembers-Game",
	])
	if _http.request(API_URL, headers) != OK:
		_http.queue_free()


func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func open_download() -> void:
	OS.shell_open(download_url if download_url != "" else RELEASES_PAGE)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var tag := str(data.get("tag_name", ""))
	if tag == "" or not is_newer(tag, current_version()):
		return
	latest_version = tag.trim_prefix("v")
	download_url = str(data.get("html_url", RELEASES_PAGE))
	for asset in data.get("assets", []):
		if typeof(asset) == TYPE_DICTIONARY and str(asset.get("name", "")).ends_with(".apk"):
			download_url = str(asset.get("browser_download_url", download_url))
			break
	has_update = true
	update_available.emit(latest_version, download_url)


## "v1.4.2" > "1.4.1" gibi sayısal karşılaştırma.
static func is_newer(remote: String, local: String) -> bool:
	var a := _parts(remote)
	var b := _parts(local)
	for i in range(max(a.size(), b.size())):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false


static func _parts(v: String) -> Array:
	var out: Array = []
	for p in v.strip_edges().trim_prefix("v").split("-")[0].split("."):
		out.append(int(p) if p.is_valid_int() else 0)
	return out
