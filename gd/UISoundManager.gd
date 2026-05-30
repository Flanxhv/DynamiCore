extends Node

# 建立兩個播放器，一個負責點擊，一個負責懸停
var click_player = AudioStreamPlayer.new()
var hover_player = AudioStreamPlayer.new()

func _ready():
	# ★ 極度重要：設定為 ALWAYS，這樣即使遊戲暫停 (Pause)，選單按鈕也才會有聲音！
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 載入音效檔案 (請替換成你實際的音效檔路徑)
	click_player.stream = preload("uid://bifhqxn2b6i17")
	hover_player.stream = preload("uid://8qh5srpry2x2")
	
	# (可選) 如果你有使用音訊匯流排，可以指定到 UI 軌道
	# click_player.bus = "UI"
	
	# 把播放器加入到場景樹中
	add_child(click_player)
	add_child(hover_player)

# 供外部呼叫的播放函式
func play_click():
	click_player.play()

func play_hover():
	hover_player.play()


func bind_buttons(node: Node):
	for child in node.get_children():
		# 如果這個節點是按鈕 (包含 Button, TextureButton 等)
		if child is BaseButton:
			# 檢查是否已經綁定過，避免重複綁定
			if not child.pressed.is_connected(play_click):
				child.pressed.connect(play_click)
			
			if not child.mouse_entered.is_connected(play_hover):
				child.mouse_entered.connect(play_hover)
				
		# 遞迴檢查底下的子節點 (確保藏在 VBoxContainer 裡面的按鈕也能被找到)
		if child.get_child_count() > 0:
			bind_buttons(child)
