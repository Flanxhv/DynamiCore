extends CanvasLayer

# ★ 在這裡填入你的「遊玩場景」根節點名稱！
# 如果玩家在這個場景裡，就不會觸發選單的點擊特效
var excluded_scenes = ["Main", "main"] 

func _ready():
	# layer 設為 100，保證在所有 UI 之上
	layer = 100 
	
	# ★ 讓這個腳本即使在遊戲暫停時 (結算畫面、暫停選單) 依然能產生特效！
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	# 偵測是否為「按下」事件 (同時支援滑鼠左鍵與手機觸控)
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		# 檢查當前所在的場景
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.name in excluded_scenes:
			return # 如果在打歌的遊玩場景，就直接退出，不生成特效
			
		# 如果是選單介面，就在點擊位置生成爆裂特效
		_spawn_burst(event.position)

# ==========================================
# ★ 核心魔法：純程式碼繪製的三角爆裂特效
# ==========================================
func _spawn_burst(pos: Vector2):
	var burst_node = Node2D.new()
	burst_node.position = pos
	add_child(burst_node)
	
	var triangle_count = 10 
	var tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 無視暫停
	
	for i in range(triangle_count):
		var tri = Polygon2D.new()
		tri.color = Color(0.0, 0.911, 0.854, 0.814) 
		
		# 繪製一個極小的等腰三角形
		tri.polygon = PackedVector2Array([
			Vector2(0, -8),  # 尖端
			Vector2(-4, 4),  # 左下角
			Vector2(4, 4)    # 右下角
		])
		
		# 計算向外爆裂的角度 (平均分配 360 度，加上一點隨機偏移讓它更自然)
		var angle = (PI * 2 / triangle_count) * i + randf_range(-0.3, 0.3)
		
		# 讓三角形的尖端永遠朝向飛出的方向
		tri.rotation = angle + PI/2 
		
		burst_node.add_child(tri)
		
		# 設定隨機飛出的距離
		var dist = randf_range(60.0,180.0)
		var target_pos = Vector2(cos(angle), sin(angle)) * dist
		
		# 動畫 A：向外飛出 (0.4 秒，帶有平滑減速)
		tween.tween_property(tri, "position", target_pos, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		# 動畫 B：同時縮小到不見
		tween.tween_property(tri, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# 所有三角形的動畫播完後，刪除這個暫存的特效節點，避免記憶體洩漏
	tween.chain().tween_callback(burst_node.queue_free)
