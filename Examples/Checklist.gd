extends GDX

# Main app
func check_list(props, state := { # State variables declared in here
	# AutoIndexer is a special object that holds a dictionay, but acts like an array
	# Automatically indexes elements, which are added with 'append'
	items = AutoIndexer.new(),
}):
	# A component's structure is [state, [tree of elements]]
	return [
		# Required for remembering state
		state, 
		# UI element structure is an array [ element_type, {props}, [children] ]
		# A dictionary is for props, and an array is for children
		# Both are optional, and can be omitted and placed in any order
		# Multiple dictionaries and arrays will be merged into one
		[VBoxContainer, {
			size_flags_horizontal = SIZE_SHRINK_CENTER,
			size_flags_vertical = SIZE_EXPAND_FILL,
		}, [
			[Button, {
				text = 'Add Task',
				custom_minimum_size = Vector2(200, 0),
				size_flags_vertical = SIZE_FILL if state.items.size() > 0 else SIZE_EXPAND + SIZE_SHRINK_CENTER,
				mouse_default_cursor_shape = CURSOR_POINTING_HAND,
				# Signals can be connected as normal props by setting the value to a Callable
				pressed = func():
					state.items.append("item " + str(state.items.next_index))
					# UI updates are triggered manually for now
					update(), 
			}],
			[VBoxContainer, 
				# AutoIndexer has a special map function
				# Similar to Array.map but with dictionary (key, values)
				state.items.map(func(key, val): return [
					# 'list_item' is a functional component
					# Components have to be placed with Component(Callable)
					Component(list_item), {key = key}, {
						# All props below will be passed to 
						text = val,
						setText = func(text): state.items.dict[key] = text; update(),
						deleteItem = func(): state.items.dict.erase(key); update(),
					},
				]),
			]]
		]
	]

# Reusable functional component
# Props are passed into the 1st argument
# 2nd argument is for decalring state that will be remember accross UI updates
func list_item( props, state := {}):
	# Always return [state, [tree of elements]]
	return [
		state,
		[HBoxContainer, {
			size_flags_horizontal = SIZE_EXPAND_FILL,
		}, [
			[CheckBox, { mouse_default_cursor_shape = CURSOR_POINTING_HAND }],
			
			# Sometimes you need access to a UI element itself
			# For this you can use a Callable/Lambda, which is passed a reference to that element
			# The callable can return a dictionary or array to acts as props or children respectively
			[LineEdit, func(this: LineEdit): return { # 'this' is a reference to the LineEdit instance
				custom_minimum_size = Vector2(100, 40),
				size_flags_horizontal = SIZE_EXPAND_FILL,
				expand_to_text_length = true,
				select_all_on_focus = true,
				text = props.text,
				# Below is where we needed access to the instance
				ready = func(): this.grab_focus(),
				# I use the 'focus_exited' signal instead of the 'text_changed' signal because 
				# Godot's LineEdit and TextEdit don't work nicely as controlled components.
				# Their cursor position is reset every time you set the text manually.
				# So it's better to just update it once, when you know the user is done typing
				focus_exited = func(): props.setText.call(this.text),
			}],
			
			[Button, { 
				text = 'Delete',
				pressed = props.deleteItem,
				mouse_default_cursor_shape = CURSOR_POINTING_HAND,
			}],
		]]
	]

# Override this function to display your app
func render():
	# The render function is what will run on every update
	# App logic should usually be written in a separate functional component, so it can save state
	# The MarginContainer is just full screening, adding margins, and adding a background color
	return [
		MarginContainer, 
		{ 
			focus_mode = FOCUS_CLICK,
			# Override theme properties with 'override_constant', 'override_font', 'override_color' etc
			override_constant = {
				# Using Arrays as keys lets you set multiple properties to the same value
				['margin_left', 'margin_right']: 32,
				['margin_top', 'margin_bottom']: 12,
			},
			# Lets you draw a custom style_box on any element
			# MarginContainer doesn't normally support styling. This allows you to add some
			style = { 
				bg_color = Color.DARK_OLIVE_GREEN,
			},
			# If a prop key is a function on the element, it will be called with the prop value as arguments
			# For passing multiple arguments, use an array as the prop val
			set_anchors_and_offsets_preset = PRESET_FULL_RECT
		},
		[Component(check_list)]
	]
