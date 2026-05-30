extends Node

var current_song_data: Dictionary = {}
var current_chart_path: String = "" # 記錄最終選擇的具體難度譜面路徑

var note_speed_mult: float = 1.0  # 下落速度倍率 (預設 1.0x)
var device_offset: float = 0.0    # 裝置聲音延遲校準 (單位：秒)
var bg_brightness: float = 0.4    # 背景暗化亮度 (0.0 全黑 ~ 1.0 原圖)
var effect_height_ratio = 1.0 
var song_list: Array = [
	{
		"id": "base_song_01", # 確保有給一個唯一的 ID 用來存分數
		"title": "Tablear",
		"artist": "kuro",
		"charter": "flanxhv",
		# ★ 關鍵：這裡的路徑全部指向 res:// 
		"folder_path": "res://built_in_songs/base_tablear/",
		"audio_path": "res://built_in_songs/base_tablear/music.mp3", # 或 .mp3
		"preview_path": "res://built_in_songs/base_tablear/preview.mp3",
		"cover_path": "res://built_in_songs/base_tablear/cover.jpg",
		"difficulty": ["GIGA 15"], # 填入這首歌有的難度
		"ranked": false,
		"loved": false
	}
]
var auto_play: bool = false
var mirror_mode: bool = false
var save_path = "user://save_data.json"
var player_scores: Dictionary = {}
var last_selected_song_id: String = ""
var last_selected_diff_index: int = 0
var settings_path = "user://settings.json"

func _ready():
	load_scores()
	load_settings()

func load_scores():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data != null:
			player_scores = data

func save_new_score(song_id: String, diff_type: String, new_score: int):
	if not player_scores.has(song_id):
		player_scores[song_id] = {}
		
	var current_high = player_scores[song_id].get(diff_type, 0)
	
	if new_score > current_high:
		player_scores[song_id][diff_type] = new_score
		
		# 寫入硬碟
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(player_scores))
		file.close()

func save_settings():
	var settings_data = {
		"device_offset": device_offset,
		"note_speed_mult": note_speed_mult,
		"bg_brightness": bg_brightness,
		"effect_height_ratio": effect_height_ratio
	}
	
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data))
		file.close()

func load_settings():
	# 檢查有沒有舊的設定檔
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		
		# 如果成功解析出字典，就覆蓋掉目前的預設值
		if data != null and typeof(data) == TYPE_DICTIONARY:
			device_offset = data.get("device_offset", 0.0)
			note_speed_mult = data.get("note_speed_mult", 1.0)
			bg_brightness = data.get("bg_brightness", 0.4)
			effect_height_ratio = data.get("effect_height_ratio", 1.0)
