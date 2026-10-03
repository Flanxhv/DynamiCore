extends Button

# 請依實際在 ScoreTriangle 底下的子節點名稱調整路徑
@onready var percent_label: Label = $PercentageLabel
@onready var rank_label: Label = $RankLabel
@onready var pgm_label: Label = $JudgementsLabel

var current_record: Dictionary = {}
var is_showing_detail: bool = false # false: 顯示百分比與評級, true: 顯示 P/G/M

func _ready() -> void:
	# 點擊自身時切換顯示內容
	pressed.connect(_on_score_triangle_pressed)

func _on_score_triangle_pressed() -> void:
	# 若無紀錄則不切換
	if current_record.is_empty():
		return
	is_showing_detail = !is_showing_detail
	_update_ui()

# 供外部（song_select.gd）呼叫更新成績資料
func update_score_data(record: Dictionary) -> void:
	current_record = record
	is_showing_detail = false # 換歌或切換難度時重設為預設模式
	_update_ui()

func _update_ui() -> void:
	# 情況一：完全沒有遊玩紀錄
	if current_record.is_empty():
		percent_label.visible = true
		rank_label.visible = false
		pgm_label.visible = false
		percent_label.text = "N/A"
		return

	# 情況二：預設顯示百分比與評級
	if not is_showing_detail:
		percent_label.visible = true
		rank_label.visible = true
		pgm_label.visible = false
		
		# 分數滿分 1,000,000 計算百分比
		var score = current_record.get("score", 0)
		var percentage: float = (float(score) / 1000000.0) * 100.0
		percent_label.text = "%.2f%%" % percentage
		
		var rank_str = current_record.get("rank", "F")
		rank_label.text = rank_str
		_apply_rank_color(rank_str)
	# 情況三：點擊後切換為 Perfect / Good / Miss
	else:
		percent_label.visible = false
		rank_label.visible = false
		pgm_label.visible = true
		
		var p = current_record.get("perfect", 0)
		var g = current_record.get("good", 0)
		var m = current_record.get("miss", 0)
		pgm_label.text = "%d/%d/%d" % [p, g, m]

func _apply_rank_color(rank: String) -> void:
	# 1. 確保 modulate 恢復為純白無染色，避免干擾
	rank_label.modulate = Color.WHITE
	
	# 決定純色
	var target_color = Color.WHITE
	match rank:
		"Ω": target_color = Color("#4DFFFF")
		"Ψ": target_color = Color("#FFFF37")
		"Χ": target_color = Color("#FF2222")
		"A": target_color = Color("#FFDC35")
		"B": target_color = Color("#73BF00")
		"C": target_color = Color("#0088FF")
		"D": target_color = Color("#8B4513")
		"E": target_color = Color("#A9A9A9")
		_:   target_color = Color.WHITE

	# ★ 核心修正：如果有 LabelSettings，就直接改它的 font_color
	if rank_label.label_settings != null:
		# duplicate() 避免改到其他共用此 LabelSettings 的文字
		rank_label.label_settings = rank_label.label_settings.duplicate()
		rank_label.label_settings.font_color = target_color
	else:
		# 沒有 LabelSettings 時，走原本的 Theme Override
		rank_label.add_theme_color_override("font_color", target_color)
