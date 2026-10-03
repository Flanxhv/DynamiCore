extends Node

# 建立兩個播放器，一個負責點擊，一個負責懸停
var click_player = AudioStreamPlayer.new()
var hover_player = AudioStreamPlayer.new()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	click_player.stream = preload("uid://bifhqxn2b6i17")
	hover_player.stream = preload("uid://8qh5srpry2x2")
	
	add_child(click_player)
	add_child(hover_player)

func play_click():
	click_player.play()

func play_hover():
	hover_player.play()


func bind_buttons(node: Node):
	for child in node.get_children():
		if child is BaseButton:
			if not child.pressed.is_connected(play_click):
				child.pressed.connect(play_click)
			
			if not child.mouse_entered.is_connected(play_hover):
				child.mouse_entered.connect(play_hover)
				
		if child.get_child_count() > 0:
			bind_buttons(child)
