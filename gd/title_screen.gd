extends Control

func _ready():
	UiSoundManager.bind_buttons(self)
func _on_button_pressed():
	# 切換到主選單場景
	Transition.change_scene("uid://dnda82ibqdnuq")
