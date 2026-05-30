shader_type canvas_item;

// 將進度條上限拉長到 2.0
uniform float progress : hint_range(0.0, 2.0) = 0.0; 
uniform float columns = 48.0;
uniform float rows = 27.0;

void fragment() {
    vec2 grid_uv = vec2(UV.x * columns, UV.y * rows);
    vec2 cell_coord = floor(grid_uv);
    vec2 local_uv = fract(grid_uv) - 0.5; 
    
    float threshold = (cell_coord.x + cell_coord.y) / (columns + rows);
    
    // 將 0.0~2.0 的進度拆分成「淡入」與「淡出」兩個階段
    float p_in = clamp(progress, 0.0, 1.0);
    float p_out = clamp(progress - 1.0, 0.0, 1.0);
    
    // 計算方塊大小：淡入時變大，淡出時從同樣的方向被扣除！
    float size_in = clamp((p_in * 2.0) - threshold, 0.0, 1.0);
    float size_out = clamp((p_out * 2.0) - threshold, 0.0, 1.0);
    float size = size_in - size_out;
    
    if (abs(local_uv.x) < size / 2.0 && abs(local_uv.y) < size / 2.0) {
        COLOR = vec4(0.05, 0.81, 0.771, 1.0);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
