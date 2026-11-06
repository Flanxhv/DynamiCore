extends Control

@onready var credit_modal: Control = $CreditModal
@onready var dialog_panel: PanelContainer = $CreditModal/DialogPanel
@onready var mask: ColorRect = $CreditModal/Mask
var _modal_tween: Tween
func _ready() :
	credit_modal.visible = false
	
	# 連接關閉按鈕點擊信號
	$CreditModal/DialogPanel/CloseButton.pressed.connect(_close_credit_modal)
	BgmManager.play_bgm()
	UiSoundManager.bind_buttons(self)
	
func _on_play_button_pressed():
	#beta
	BgmManager.stop_bgm()
	Transition.change_scene("uid://nfkrp5p1relk")

func _on_chart_button_pressed():
	# Chart Download
	Transition.change_scene("uid://vo74jk8d8m7r")

func _on_credit_button_pressed():
	_open_credit_modal()
	
func _on_upload_button_pressed():
	var dialog = FileDialog.new()
	add_child(dialog)
	
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Choose the song, chart, and bg file to import(.zip)"
	dialog.use_native_dialog = true
	
	dialog.filters = PackedStringArray(["*.zip ; ZIP Archive"])
	
	dialog.file_selected.connect(func(zip_file_path: String):
		# 保留防呆檢查
		if zip_file_path.get_extension().to_lower() != "zip":
			Toast.show_toast("Please select a .zip file!", 1.5)
			dialog.queue_free()
			return
		
		_import_zip_package(zip_file_path)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	dialog.popup_centered_ratio(0.9)
	

func _open_credit_modal() -> void:
	if _modal_tween and _modal_tween.is_valid():
		_modal_tween.kill()
		
	credit_modal.visible = true
	
	mask.modulate.a = 0.0
	dialog_panel.scale = Vector2(0.9, 0.9)
	dialog_panel.pivot_offset = dialog_panel.size / 2.0
	
	_modal_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_modal_tween.tween_property(mask, "modulate:a", 1.0, 0.15)
	_modal_tween.tween_property(dialog_panel, "scale", Vector2.ONE, 0.15)

func _close_credit_modal() -> void:
	if _modal_tween and _modal_tween.is_valid():
		_modal_tween.kill()
		
	_modal_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_modal_tween.tween_property(mask, "modulate:a", 0.0, 0.12)
	_modal_tween.tween_property(dialog_panel, "scale", Vector2(0.95, 0.95), 0.12)
	
	_modal_tween.chain().tween_callback(func(): credit_modal.visible = false)

func _import_zip_package(zip_path: String):
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		Toast.show_toast("Cannot read the .zip file!", 1.5)
		return
	
	var files = reader.get_files()
	if files.is_empty():
		Toast.show_toast("There is no file in the .zip file!", 1.5)
		reader.close()
		return
	
	# 以檔名作為 Song ID (去除 .zip 副檔名)
	var zip_name = zip_path.get_file().get_basename()
	var song_id = "custom_" + zip_name.validate_filename()
	var target_folder = "user://songs/" + song_id + "/"
	
	DirAccess.make_dir_recursive_absolute(target_folder)
	
	var found_audio = false
	var has_meta = false
	
	# 1. 遍歷並解壓縮所有檔案
	for inner_file in files:
		if inner_file.begins_with("__MACOSX") or inner_file.begins_with("."):
			continue
		if inner_file.ends_with("/"):
			continue
			
		var file_data: PackedByteArray = reader.read_file(inner_file)
		var file_name = inner_file.get_file()
		var ext = file_name.get_extension().to_lower()
		
		if ext in ["mp3", "ogg", "wav"]:
			_save_raw_file(target_folder + "music." + ext, file_data)
			found_audio = true
		elif ext in ["png", "jpg", "jpeg", "webp"]:
			_convert_buffer_to_png(file_data, target_folder + "bg.png")
		elif ext == "xml":
			# 存入譜面檔 (例如 HARD.xml, GIGA.xml)
			_save_raw_file(target_folder + file_name, file_data)
		elif file_name == "meta.json":
			_save_raw_file(target_folder + "meta.json", file_data)
			has_meta = true
			
	reader.close()
	
	# 2. 檢查是否有音訊檔
	if not found_audio:
		Toast.show_toast("Import failed: no music file in .zip!", 2.0)
		return

	# ========================================================
	# ★ 核心位置：讀取 meta.json 並比對難度與譜面是否齊全
	# ========================================================
	var meta_path = target_folder + "meta.json"
	
	if not has_meta or not FileAccess.file_exists(meta_path):
		Toast.show_toast("Import failed: meta.json is missing!", 2.0)
		# 若要求必須要有 meta.json，缺檔時可直接中斷並清理資料夾
		# OS.move_to_trash(ProjectSettings.globalize_path(target_folder))
		return
	
	# 讀取並解析 meta.json
	var meta_file = FileAccess.open(meta_path, FileAccess.READ)
	var meta_json_text = meta_file.get_as_text()
	meta_file.close()
	
	var meta_data = JSON.parse_string(meta_json_text)
	if typeof(meta_data) != TYPE_DICTIONARY:
		Toast.show_toast("Import failed: meta.json format invalid!", 2.0)
		return
		
	# 檢查 difficulty 裡的每個譜面檔案是否存在
	var difficulties: Array = meta_data.get("difficulty", [])
	if difficulties.is_empty():
		Toast.show_toast("Import failed: no difficulty found in meta.json!", 2.0)
		return

	var missing_charts: Array[String] = []
	for diff_entry in difficulties:
		# "HARD 11" -> 切出 "HARD"
		var diff_type = diff_entry.split(" ")[0].strip_edges()
		var expected_chart_file = diff_type + ".xml"
		
		# 檢查剛剛寫入的資料夾內是否有這份譜面
		if not FileAccess.file_exists(target_folder + expected_chart_file):
			missing_charts.append(expected_chart_file)
	
	if not missing_charts.is_empty():
		var err_msg = "Missing charts: " + ", ".join(missing_charts)
		Toast.show_toast(err_msg, 2.5)
		print("❌ 缺少譜面檔案: ", missing_charts)
		return

	# 補充/確保資料夾路徑寫入 meta.json (方便後續遊戲讀取)
	meta_data["folder_path"] = target_folder
	var update_meta = FileAccess.open(meta_path, FileAccess.WRITE)
	if update_meta:
		update_meta.store_string(JSON.stringify(meta_data))
		update_meta.close()

	Toast.show_toast("Import Success!", 1.5)

func _save_raw_file(path: String, data: PackedByteArray):
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()

func _convert_buffer_to_png(buffer: PackedByteArray, dest_path: String):
	if buffer.size() < 4: return
	var img = Image.new()
	if img.load_png_from_buffer(buffer) == OK or \
	   img.load_jpg_from_buffer(buffer) == OK or \
	   img.load_webp_from_buffer(buffer) == OK:
		img.save_png(dest_path)
