extends GDX

var tasks = {}
var deleted_tasks = []
var container = 0

var hovered = false
var pressed = false



func _style_sheet():
	return {
		'center': {
			size_flags_horizontal = SIZE_SHRINK_CENTER,
			size_flags_vertical = SIZE_SHRINK_CENTER,
		},
	}


func task(props := {}, state = {
	checked = 0,
	counter = 0,
	text = "Yooo",
}):
	return [state, 
		[HBoxContainer, func(this: HBoxContainer):
			if props.label in deleted_tasks:
				var t := create_tween()
				t.tween_property(this, "modulate:a", 0, 0.2)
				t.tween_callback(func(): 
					tasks.erase(props.label); 
					deleted_tasks.erase(props.label);
					update())
			else:
				this.modulate.a = 1
			return {
				theme_override = {
					color = {
						default = Color.WHITE
					},
					stylebox = {
						pressed = (func():
							var box := StyleBoxFlat.new()
							box.set_border_width_all(8)
							return box
							).call(),
						
					}
				}
			}, 
			[
				[CheckBox, func(this: CheckBox): {
					pressed = func(): state.checked += 1; update();
				}],
				
				[Label, {text = 'Hello ' + str(props.label)}],
				
				props.children,
				
				[Label, {text = str(state.counter)}],
				
				[TextEdit, func(a: TextEdit): return {
					custom_minimum_size = Vector2(200, 32),
					text = state.text,
					text_changed = func(): state.text = a.text; update()
				}],
				
				[Button, {pressed = func(): state.counter += 1; update()}], 
				
				[Button, {
					pressed = func(): 
						deleted_tasks.append(props.label)
						update()
						}
				]
			]
		]
	]

func thing(props := {text = 'jumble'}, state = {
	count = 0
}):
	return [state, [Button,
		func(a): 
		return {
			'class_name' = 'center red',
			include = '',
			state = state,
			text = props.text + ": " + str(state.count),
			pressed = func(): print('pressed from thing'); state.count += 1; update(),
		},
		func(a): return [
			[Label, {text = str(state.count)}]
		]
	]]

func button(props := {}, state = {
	pressed = false,
	hovered = false,
}):
	return [state, [Button, func(this: Button): return spread(props, {
		mouse_entered = func(): state.hovered = true; update(this),
		mouse_exited = func(): state.hovered = false; update(this),
		button_down = func(): state.pressed = true; update(this),
		button_up = func(): state.pressed = false; update(this),
		theme_override = {
			color = {
				font_color = Color.BLACK,
				
			}
		},
		style = (func():
			var result := {
				transition = .2,
				bg_color = Color.BLACK if state.hovered else Color.LIGHT_BLUE,
			}
			if state.pressed:
				result.merge({
					set_expand_margin_all = -4
				}, true)
			if hovered:
				result.merge({
					
				}, true)
			return result
			).call()
	}), 
	props.children]]


func render():
	return [
		[VBoxContainer, {size = Vector2(1000, 500)}, [
			[Label, {text = 'Title'}],
			
			[Component(thing), {text = 'just checking'}],
			[Component(thing), {text = 'just checking'}],
			
			[Component(button), {text = 'Yoo'}, [ColorRect]],
			
#			thing.call({text = 'just pooing'}),
			
			[OptionButton, func(a: OptionButton):
				a.clear()
				a.add_item("Vertical")
				a.add_item("Horizontal")
				a.select(container)
				return {
					item_selected = func(index): container = index; update()
				}
				],
			
			[Button, func(this: Button): 
				return {
					text = "Add task + ",
					size_flags_horizontal = SIZE_SHRINK_CENTER,
					mouse_entered = func(): 
						hovered = true; 
						update(this)
						,
					mouse_exited = func(): 
						hovered = false; 
						update(this); 
						print('exited')
						,
					button_down = func(): 
						pressed = true 
						update(this)
						,
					button_up = func(): 
						tasks[Time.get_ticks_msec()] = "Hello"
						pressed = false; 
						update()
						pass,
					mouse_default_cursor_shape = CURSOR_POINTING_HAND,
					style = (func(a := StyleBoxFlat.new()):
						var result = {
							set_border_width_all = 4,
							set_corner_radius_all = 20,
							set_content_margin_all = 16,
							content_margin_top = 8,
							content_margin_bottom = 8,
							bg_color = Color.CORAL,
							transition = 0.2,
						}
						if hovered:
							result.merge({
								set_corner_radius_all = 0,
								bg_color = Color.LIGHT_CORAL,
							}, true)
						if pressed:
							result.merge({
								set_expand_margin_all = -4,
								set_corner_radius_all = 20,
								transition = 0.1,
							}, true)
						return result
						).call()
			}],
			
			[ScrollContainer, {
				size_flags_vertical = SIZE_EXPAND_FILL,
			}, [
				[(func(): return [VBoxContainer, HFlowContainer][container]).call(), 
					{
						size_flags_horizontal = SIZE_EXPAND_FILL,
					},
					tasks.keys().map(func(key):
						return [
							Component(self.task), {
								key = key,
								label = key,
								text = tasks[key],
							}
						]),
					
					map_key(tasks, func(key, val): 
						return [Component(self.task), {label = key, text = val}]
						)
				],
			]],
			
			(func(): 
				if tasks.size() >= 5:
					return [Label, {text="5 or more"}]
				).call(),
		]]
	]
