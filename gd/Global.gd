extends Node

var current_song_data: Dictionary = {}
var current_chart_path: String = "" # 記錄最終選擇的具體難度譜面路徑

var note_speed_mult: float = 1.0  # 下落速度倍率 (預設 1.0x)
var device_offset: float = 0.00    # 裝置聲音延遲校準 (單位：秒)
var bg_brightness: float = 0.4    # 背景暗化亮度 (0.0 全黑 ~ 1.0 原圖)
var effect_height_ratio = 1.0 
var hit_effect_style: bool = false
var song_list: Array = [
	{
		"id": "base_song_03", # 確保有給一個唯一的 ID 用來存分數
		"title": "Rain then clear",
		"artist": "kuro",
		"charter": "flanxhv\n*Song copyright is held by the artist, and used in this game with permission.",
		"folder_path": "res://built_in_songs/base_3/",
		"audio_path": "res://built_in_songs/base_3/music.mp3", # 或 .mp3
		"preview_path": "res://built_in_songs/base_3/music.mp3",
		"cover_path": "res://built_in_songs/base_3/cover.png",
		"difficulty": ["MEGA 13"], # 填入這首歌有的難度
		"ranked": false,
		"loved": false
	},
]
var auto_play: bool = false
var mirror_mode: bool = false
var save_path = "user://save_data.json"
var player_scores: Dictionary = {}
var last_selected_song_id: String = ""
var last_selected_diff_index: int = 0
var settings_path = "user://settings.json"

const SAVE_PATH = "user://records.cfg"
# ==========================================
# ★ 新增：單曲專屬校準值的存檔路徑與變數
# ==========================================
var offset_save_path = "user://song_offsets.json"
var saved_offsets: Dictionary = {} 
# ==========================================

func _ready():
	load_scores()
	load_settings()
	load_offsets() # ★ 新增：遊戲啟動時載入所有單曲校準值

func load_scores():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data != null:
			player_scores = data

func save_new_score(song_id: String, diff_type: String, score_data: Dictionary):
	if not player_scores.has(song_id):
		player_scores[song_id] = {}
		
	# 取得目前的歷史最高分（相容舊版直接存 int 的情況）
	var old_record = player_scores[song_id].get(diff_type, 0)
	var current_high_score: int = 0
	
	if typeof(old_record) == TYPE_DICTIONARY:
		current_high_score = old_record.get("score", 0)
	elif typeof(old_record) == TYPE_INT or typeof(old_record) == TYPE_FLOAT:
		current_high_score = int(old_record)

	var new_score: int = score_data.get("score", 0)

	# 只有突破最高分時才更新存檔
	if new_score > current_high_score:
		player_scores[song_id][diff_type] = {
			"score": new_score,
			"rank": score_data.get("rank", "F"),
			"max_combo": score_data.get("max_combo", 0),
			"perfect": score_data.get("perfect", 0),
			"good": score_data.get("good", 0),
			"miss": score_data.get("miss", 0)
		}
		
		# 寫入硬碟
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(player_scores, "\t")) # "\t" 讓 json 排版好讀
			file.close()
			print("🏆 刷新最高分並寫入存檔：", new_score)

# ★ 新增：供其他場景（例如選曲畫面、結算面板）調取資料的方法
func get_song_score_data(song_id: String, diff_type: String) -> Dictionary:
	if not player_scores.has(song_id):
		return {}
	
	var record = player_scores[song_id].get(diff_type, null)
	if record == null:
		return {}
		
	# 相容舊存檔只有純整數分數的狀況
	if typeof(record) == TYPE_INT or typeof(record) == TYPE_FLOAT:
		return {
			"score": int(record),
			"rank": "F",
			"max_combo": 0,
			"perfect": 0,
			"good": 0,
			"miss": 0
		}
		
	return record

func save_settings():
	var settings_data = {
		"device_offset": device_offset,
		"note_speed_mult": note_speed_mult,
		"bg_brightness": bg_brightness,
		"effect_height_ratio": effect_height_ratio,
		"hit_effect_style": hit_effect_style
	}
	
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data))
		file.close()

func load_settings():
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if data != null and typeof(data) == TYPE_DICTIONARY:
			device_offset = data.get("device_offset", 0.0)
			note_speed_mult = data.get("note_speed_mult", 1.0)
			bg_brightness = data.get("bg_brightness", 0.4)
			effect_height_ratio = data.get("effect_height_ratio", 1.0)
			hit_effect_style = data.get("hit_effect_style", false)

# ==========================================
# ★ 新增：單曲專屬校準值的讀寫系統
# ==========================================
func load_offsets():
	if FileAccess.file_exists(offset_save_path):
		var file = FileAccess.open(offset_save_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		
		if data != null and typeof(data) == TYPE_DICTIONARY:
			saved_offsets = data

func save_song_offset(song_id: String, offset: float):
	saved_offsets[song_id] = offset
	
	var file = FileAccess.open(offset_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_offsets))
		file.close()

func get_song_offset(song_id: String) -> float:
	return saved_offsets.get(song_id, 0.0)
