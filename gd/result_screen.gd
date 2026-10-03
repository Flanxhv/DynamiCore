extends CanvasLayer

# 抓取內層的滿版 Control 節點作為動畫目標
@onready var root_control: Control = $RootControl

@onready var result_song_label: Label = %SongNameLabel
@onready var result_diff_line: ColorRect = %SongNameRect2
@onready var result_score_label: RichTextLabel = %ScoreLabel
@onready var result_details_label: Label = %DetailsLabel
@onready var res_restart_btn: Button = %RestartButton
@onready var res_quit_btn: Button = %QuitButton
@onready var result_menu: Control = $RootControl/ResultMenu

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_button_styles()
	
	if res_restart_btn:
		res_restart_btn.pressed.connect(_on_restart_pressed)
	if res_quit_btn:
		res_quit_btn.pressed.connect(_on_quit_pressed)

func _setup_button_styles() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0.8)
	btn_style.border_color = Color(1, 1, 1, 1)
	btn_style.set_border_width_all(4)
	btn_style.set_corner_radius_all(8)
	
	for btn in [res_restart_btn, res_quit_btn]:
		if btn != null:
			btn.add_theme_stylebox_override("normal", btn_style)
			btn.add_theme_stylebox_override("hover", btn_style)
			btn.add_theme_stylebox_override("pressed", btn_style)
			btn.add_theme_stylebox_override("focus", btn_style)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_color_override("font_pressed_color", Color.GRAY)

func setup_and_show(judge_stats: Dictionary, max_combo: int) -> void:
	print("--- 真正進入了 ResultScreen 的 setup_and_show ---")
	var total_notes_judged = judge_stats["PERFECT"] + judge_stats["GOOD"] + judge_stats["MISS"]
	var final_score = 0
	var rank = "F"
	var rank_color = "#FFFFFF" 
	
	var song_id = Global.current_song_data.get("id", Global.current_song_data.get("title", "unknown_song"))
	var diff_type = Global.current_chart_path.get_file().get_basename()
	
	if result_diff_line != null:
		result_diff_line.color = _get_diff_color(diff_type)
		
	if Global.auto_play:
		final_score = 0
		rank = "AUTO"
		rank_color = "#00FFFF"
		result_details_label.text = "AUTO PLAY\n\nPERFECT: %d\nGOOD     : 0\nMISS     : 0" % total_notes_judged
	else:
		if total_notes_judged > 0:
			var raw_score = (judge_stats["PERFECT"] * 1.0 + judge_stats["GOOD"] * 0.65) / total_notes_judged
			final_score = int(raw_score * 1000000)

		if final_score >= 1000000:
			rank = "Ω"
			rank_color = "#4DFFFF"
		elif final_score >= 990000:
			rank = "Ψ"
			rank_color = "#FFFF37" 
		elif final_score >= 980000:
			rank = "Χ"
			rank_color = "#FF0000" 
		elif final_score >= 960000:
			rank = "A"
			rank_color = "#FFDC35"
		elif final_score >= 900000:
			rank = "B"
			rank_color = "#73BF00"
		elif final_score >= 800000:
			rank = "C"
			rank_color = "#0066CC"
		elif final_score >= 700000:
			rank = "D"
			rank_color = "#8B4513"
		elif final_score >= 600000:
			rank = "E"
			rank_color = "#A9A9A9"
		else:
			rank = "F"
			rank_color = "#000000"
		
		var prefix = ""
		if judge_stats["MISS"] == 0 and total_notes_judged > 0:
			prefix = "ALL PERFECT\n\n" if judge_stats["GOOD"] == 0 else "FULL COMBO\n\n"
			
		result_details_label.text = prefix + "MAX COMBO: %d\n\nPERFECT: %d\nGOOD: %d\nMISS: %d" % [
			max_combo,
			judge_stats["PERFECT"],
			judge_stats["GOOD"],
			judge_stats["MISS"]
		]

	result_song_label.text = Global.current_song_data.get("title", "")
	result_score_label.text = "[left]SCORE: %07d\nRANK : [color=%s]%s[/color][/left]" % [final_score, rank_color, rank]
	
	
	visible = true
	result_menu.visible = true
	
	# 1. 重設縮放中心點為面板正中央（縮放動畫才有打擊感）
	result_menu.pivot_offset = result_menu.size / 2.0
	
	# 2. 設定動畫起始狀態（縮小到 0.8 倍且全透明）
	result_menu.scale = Vector2(0.8, 0.8)
	result_menu.modulate.a = 0.0
	
	# 3. 建立並播放彈出動畫
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 確保全域暫停下也能跑
	tween.set_parallel(true)
	
	# 0.4 秒淡入
	tween.tween_property(result_menu, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 0.4 秒彈出（TRANS_BACK 會帶有彈性回彈效果）
	tween.tween_property(result_menu, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if not Global.auto_play:
		# 打包本次成績數據
		var current_result_data = {
			"score": final_score,
			"rank": rank,
			"max_combo": max_combo,
			"perfect": judge_stats["PERFECT"],
			"good": judge_stats["GOOD"],
			"miss": judge_stats["MISS"]
		}
		
		# 呼叫 Global 寫入
		Global.save_new_score(song_id, diff_type, current_result_data)
		
func _get_diff_color(diff_raw: String) -> Color:
	var upper_diff = diff_raw.to_upper()
	if "NORMAL" in upper_diff: return Color(0, 0.55, 0.65)
	elif "HARD" in upper_diff: return Color(0.95, 0.2, 0.25) 
	elif "MEGA" in upper_diff: return Color(0.6, 0.2, 0.8)
	elif "GIGA" in upper_diff: return Color(0.4, 0.4, 0.4)
	elif "CASUAL" in upper_diff: return Color(0, 0.8, 0.5)
	elif "TERA" in upper_diff: return Color(0, 0, 0)
	return Color(0.5, 0.5, 0.5)

func _on_restart_pressed():
	Transition.reload_scene()

func _on_quit_pressed():
	Transition.change_scene("uid://nfkrp5p1relk")
