extends ColorRect

@onready var title_label = $TitleLabel
@onready var artist_label = $ArtistLabel
@onready var charter_label = $CharterLabel 
@onready var diff_container = $DiffContainer
@onready var ranked_label = $RankedLabel   
@onready var download_btn = $DownloadBtn
@onready var cover_image = $CoverImage # 你的縮圖顯示節點

var song_data: Dictionary

func _ready() :
	UiSoundManager.bind_buttons(self)
	download_btn.pressed.connect(_on_download_pressed)
	
func setup(data: Dictionary):
	#print("Title: ", title_label)
	#print("Artist: ", artist_label)
	#print("Charter: ", charter_label)
	#print("Diff: ", diff_container)
	song_data = data
	title_label.text = data["title"]
	artist_label.text = data["artist"]
	charter_label.text = "Charter: " + data["charter"]
	
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	artist_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	charter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	
	# ★ 處理 Ranked 狀態
	if has_node("RankedLabel"):
		ranked_label.visible = (data.get("ranked", "false") == "true")
	
	# ==========================================
	# ★ 核心魔法：動態生成難度標籤
	for child in diff_container.get_children():
		child.queue_free()
		
	var difficulties = data.get("difficulty", [])
	
	for diff in difficulties:
		var badge = _create_diff_badge(diff)
		diff_container.add_child(badge)
	# ==========================================
	
	# ★ 啟動背景抓圖機！
	_load_thumbnail_async()

# 專門用來生成單個「難度標籤」的輔助函式
func _create_diff_badge(diff_name: String) -> Label:
	var lbl = Label.new()
	var parts = diff_name.split(" ")
	var diff_type = parts[0] 
	var diff_level = parts[1] if parts.size() > 1 else "?"
	
	lbl.text = "%5s    " %diff_level
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	
	match diff_type.to_upper():
		"CASUAL": style.bg_color = Color(0, 0.8, 0.5) 
		"NORMAL": style.bg_color = Color(0, 0.55, 0.65)
		"HARD": style.bg_color = Color(0.95, 0.2, 0.25)
		"MEGA": style.bg_color = Color(0.6, 0.2, 0.8)
		"GIGA": style.bg_color = Color(0.4, 0.4, 0.4) 
		"TERA": style.bg_color = Color(0, 0, 0) 
		
	lbl.add_theme_stylebox_override("normal", style)
	lbl.add_theme_font_size_override("font_size", 28)
	
	return lbl

func _on_download_pressed():
	if not song_data.has("music_url") or song_data["music_url"] == "":
		download_btn.text = "No Music"
		return
		
	print("開始下載：", song_data["title"])
	download_btn.disabled = true
	
	var target_folder = "user://songs/" + song_data["id"] + "/"
	DirAccess.make_dir_recursive_absolute(target_folder)
	
	await _download_all_files(target_folder)

# ==========================================
# ★ 縮圖延遲載入與快取系統 (使用 PNG 儲存)
# ==========================================
func _load_thumbnail_async():
	if not song_data.has("cover_url") or song_data["cover_url"] == "":
		return
		
	var song_id = song_data["id"]
	var cache_dir = "user://cache/thumbs/"
	var cache_path = cache_dir + song_id + ".png" 
	
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)
		
	if FileAccess.file_exists(cache_path):
		var img = Image.load_from_file(cache_path)
		if img != null:
			var tex = ImageTexture.create_from_image(img)
			_fade_in_thumbnail(tex)
		return
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var err = http_request.request(song_data["cover_url"])
	if err != OK:
		http_request.queue_free()
		return
		
	var result = await http_request.request_completed
	var response_code = result[1]
	var body = result[3] 
	http_request.queue_free()
	
	if response_code == 200 and body.size() > 4:
		var img = Image.new()
		var decode_err = FAILED
		
		# ★ 核心魔法：讀取檔案的 Magic Bytes 來精準判斷圖片格式
		if body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E and body[3] == 0x47:
			decode_err = img.load_png_from_buffer(body)   # 這是 PNG
		elif body[0] == 0xFF and body[1] == 0xD8:
			decode_err = img.load_jpg_from_buffer(body)   # 這是 JPG
		elif body[0] == 0x52 and body[1] == 0x49: 
			decode_err = img.load_webp_from_buffer(body)  # 這是 WEBP (RIFF)
		else:
			print("❌ 未知的圖片格式，可能抓到錯誤網頁。標頭：", body[0], " ", body[1])
			
		if decode_err == OK:
			img.resize(384, 216, Image.INTERPOLATE_BILINEAR)
			var tex = ImageTexture.create_from_image(img)
			_fade_in_thumbnail(tex)
			img.save_png(cache_path)
		else:
			print("❌ 圖片解碼失敗，檔案大小：", body.size(), " bytes")

# 讓圖片出現時帶有高級淡入特效
func _fade_in_thumbnail(tex: Texture2D):
	cover_image.texture = tex
	cover_image.modulate.a = 0.0 # 先全透明
	var tween = create_tween()
	tween.tween_property(cover_image, "modulate:a", 1.0, 0.4) # 0.4秒淡入

# ==========================================
# ★ 循序漸進的異步檔案下載器
# ==========================================
# ==========================================
# ★ 循序漸進的異步檔案下載器
# ==========================================
func _download_all_files(folder: String):
	var success = true
	
	download_btn.text = "Music..."
	# 音樂不是圖片，is_image = false
	var music_success = await _download_single_file(song_data["music_url"], folder + "music.mp3", false)
	if not music_success: success = false
	
	if song_data.get("cover_url", "") != "":
		download_btn.text = "Cover..."
		# ★ 曲繪是圖片！開啟 is_image = true，啟動強制轉檔魔法
		var cover_success = await _download_single_file(song_data["cover_url"], folder + "bg.png", true)
		if not cover_success: success = false
		
	var chart_urls = song_data.get("chart_urls", {})
	for diff_name in chart_urls.keys():
		download_btn.text = diff_name + "Chart..."
		var chart_url = chart_urls[diff_name]
		var chart_success = await _download_single_file(chart_url, folder + diff_name + ".xml", false)
		if not chart_success: success = false
		
	if success:
		download_btn.text = "Got！"
		print("🎉 歌曲安裝完成！已存入：", folder)
		
		var meta_path = folder + "meta.json"
		var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
		if meta_file:
			song_data["folder_path"] = folder 
			meta_file.store_string(JSON.stringify(song_data))
			meta_file.close()
	else:
		download_btn.text = "Failed!"
		download_btn.disabled = false
		print("❌ 歌曲下載過程發生錯誤")

# ★ 新增了 is_image 參數
func _download_single_file(url: String, save_path: String, is_image: bool) -> bool:
	var request = HTTPRequest.new()
	add_child(request)
	
	# 只有「非圖片」(如 mp3, xml) 才讓引擎直接把資料寫進硬碟
	if not is_image:
		request.download_file = save_path 
	
	var err = request.request(url)
	if err != OK:
		print("❌ 無法發起網路請求：", url)
		request.queue_free()
		return false
		
	var result = await request.request_completed
	var response_code = result[1]
	var body = result[3] # 取得下載下來的二進制資料
	request.queue_free() 
	
	if response_code == 200:
		# ★ 核心魔法：如果是圖片，我們先暴力解碼，然後重新打包成 100% 純正的 PNG！
		if is_image and body.size() > 4:
			var img = Image.new()
			if img.load_png_from_buffer(body) == OK or \
			   img.load_jpg_from_buffer(body) == OK or \
			   img.load_webp_from_buffer(body) == OK:
				img.save_png(save_path) # 純正血統認證！
				return true
			else:
				print("❌ 下載的曲繪無法解析：", url)
				return false
		return true
	else:
		print("❌ 伺服器回傳錯誤代碼 (", response_code, ") 網址：", url)
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
		return false
