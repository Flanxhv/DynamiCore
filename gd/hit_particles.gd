extends CPUParticles2D

# amount 與 emission_shape 已固定在 .tscn，執行期不要再改
# （改 amount 會重新分配粒子緩衝區，是命中瞬間卡頓的主因）
# restart() / emitting 統一由 main_ts.gd 的 _play_pooled_particle 處理
func setup(pixel_width: float, hit_color: Color):
	color = hit_color
	emission_rect_extents = Vector2(pixel_width / 2.0, 5.0)
