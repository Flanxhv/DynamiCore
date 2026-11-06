extends MarginContainer

@onready var bg_button = $BgButton
@onready var ranked_bar = $BgButton/HBoxContainer/RankedBar
@onready var love_bar = $BgButton/HBoxContainer/LoveBar
@onready var title_label = $BgButton/HBoxContainer/TitleLabel

var song_data: Dictionary

# 建立一個自訂信號，當按鈕被點擊時，把自己的資料傳出去
signal item_clicked(data: Dictionary, item_node: MarginContainer)

func _ready():
	bg_button.pressed.connect(func(): item_clicked.emit(song_data, self))

# 讓外部呼叫這個函式來初始化資料
# 讓外部呼叫這個函式來初始化資料
func setup(data: Dictionary):
	song_data = data
	title_label.text = data.get("title", "Unknown Title")
	
	# ==========================================
	# ★ 安全轉換 RANKED 狀態 (處理字串、數字與布林值)
	# ==========================================
	var raw_ranked = data.get("ranked", false)
	if typeof(raw_ranked) == TYPE_STRING:
		ranked_bar.visible = (raw_ranked.strip_edges().to_lower() == "true")
	elif typeof(raw_ranked) in [TYPE_INT, TYPE_FLOAT]:
		ranked_bar.visible = (raw_ranked > 0)
	else:
		ranked_bar.visible = bool(raw_ranked)

	# ==========================================
	# ★ 安全轉換 LOVE 狀態 (處理字串、數字與布林值)
	# ==========================================
	var raw_loved = data.get("loved", false)
	if typeof(raw_loved) == TYPE_STRING:
		love_bar.visible = (raw_loved.strip_edges().to_lower() == "true")
	elif typeof(raw_loved) in [TYPE_INT, TYPE_FLOAT]:
		love_bar.visible = (raw_loved > 0)
	else:
		love_bar.visible = bool(raw_loved)
		

func set_focus_ratio(ratio: float):
	# 1. 橫向位置凸起 (維持你喜歡的排版手感)
	var offset_x = lerp(0.0, 80.0, ratio)
	add_theme_constant_override("margin_left", offset_x)
	
	# ==========================================
	# ★ 2. 分段控制亮度 (完美還原參考圖的層次感)
	# ==========================================
	var color_value: float
	var alpha_value: float
	
	if ratio > 0.8:
		# 【聚光燈區】：這是保留給「正中央那首歌」的專屬過渡區
		# 當 ratio 從 0.8 滑到 1.0 時，亮度會從 40% 灰「快速飆升」到 100% 純白
		var t = (ratio - 0.8) / 0.2 # 將 0.8~1.0 轉換為 0.0~1.0 的進度條
		
		color_value = lerp(0.4, 1.0, t) 
		alpha_value = lerp(0.7, 1.0, t)
	else:
		# 【環境光區】：這是給「相鄰曲目」到「邊緣曲目」的區塊
		# 就算它離中心很近(ratio=0.8)，它的顏色最高也只能到達 0.4 (也就是截圖裡的灰暗色)
		var t = ratio / 0.8 # 將 0.0~0.8 轉換為 0.0~1.0 的進度條
		
		color_value = lerp(0.25, 0.4, t) # 顏色從 10% 灰過渡到 40% 灰 (鎖死亮度上限)
		alpha_value = lerp(0.4, 0.7, t) # 透明度從完全透明過渡到 70% 顯示
		
	modulate = Color(color_value, color_value, color_value, alpha_value)
