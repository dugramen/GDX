extends Control

@export var style_box: StyleBoxFlat
@export var rect_func: Callable = func(r): return r
var rect = null

func _draw():
	var new_rect = rect_func.call(Rect2(-position, get_parent_area_size()))
	if rect == null:
		rect = new_rect
	else:
		var t := create_tween().set_parallel()
		t.tween_property(self, 'rect', new_rect, .3)
		t.tween_method(func(a): queue_redraw(), 0, 1, .3)
	if style_box:
		draw_style_box(style_box, rect)
