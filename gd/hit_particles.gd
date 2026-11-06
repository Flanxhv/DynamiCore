extends CPUParticles2D

func setup(pixel_width: float, hit_color: Color):
	color = hit_color
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE

	emission_rect_extents = Vector2(pixel_width / 2.0, 5.0)

	var base_amount = int(pixel_width * 0.05)
	amount = clampi(base_amount, 8, 60)

	restart()
	emitting = true
	if not is_inside_tree():
		await tree_entered
	await get_tree().create_timer(lifetime + 0.02).timeout
