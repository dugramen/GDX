class_name GDX
extends Control

var already_updating = false
var first_render = true
var StyleDrawer = preload("res://addons/gdx/Styler.tscn")
var style_sheet := {}
const default_theme: Theme = preload('res://addons/gdx/new_theme.tres')

# TODO rename to a more explicit name
# Possibly AutoIndexedList or ComponentList
class AutoIndexer:
	var next_index = 0
	var dictionary: Dictionary = {}
	var dict: 
		get: return dictionary
	
	func _init(arr := []): append_array(arr)
	func size(): return dictionary.size()
	func append(val): dictionary[next_index] = val; next_index += 1;
	func append_array(arr: Array): for val in arr: append(val)
	func read(key): return dictionary[key]
	func update(key, val): if key in dictionary: dictionary[key] = val
	func delete(key): dictionary.erase(key)
	
	func map(callable: Callable):
#		var result := {}
		var result := []
		for key in dictionary:
			var val = dictionary[key]
			var new_val = callable.call(key, val)
			result.append(new_val)
#			result[str(key)] = new_val
		return result

class GDXComponent: var function: Callable
# Required for using reusable components
func Component(function: Callable) -> GDXComponent:
	var comp := GDXComponent.new()
	comp.function = function
	return comp

class Element:
	var base_type: Object = null
	var props := {}
	var children := []
	var identifier := ''
	var uncalled_funcs: Array[Callable] = []
	func _init(array: Array):
		for val in array:
			handle_value_types(val)
	func is_valid(): return base_type != null
	func call_functions(instance: Node = base_type.new()):
		for fun in uncalled_funcs:
			handle_value_types(fun.call(instance))
	func handle_value_types(val):
		if base_type == null:
			if val is Object and 'new' in val:
				base_type = val
			elif val is GDXComponent:
				base_type = val
		elif val is Node:
			base_type = val
		elif val is Dictionary:
			props.merge(val, true)
		elif val is Array:
			children.append_array(val)
		elif val is String:
			identifier += val
		elif val is Callable:
			uncalled_funcs.append(val)


func _ready():
	deep_merge(style_sheet, _style_sheet())
	gdx(render())
	first_render = false

func _style_sheet(): pass

func update(target = null):
	if already_updating: return
	already_updating = true
	await get_tree().process_frame
	already_updating = false
	
	if target and target.has_meta('component_tree'):
		var tree = target.get_meta('component_tree')
		gdx(tree, target.get_parent(), {}, target.name as String)
	else:
		gdx(render())

# TODO split gdx function into separate smaller functions
func gdx(tree, parent = self, extra_props := {}, index = 0, name_override = null):
	if not is_instance_valid(parent): return
	var element = tree if tree is Element else Element.new(tree)
	
	if element.base_type is GDXComponent:
		var child: Node
		if index is String and parent.has_node(index as String): 
			child = parent.get_node(index as String)
		elif index is int and parent.get_child_count() > index:
			child = parent.get_child(index)
		
		element.props.merge({children = element.children}, true)
		var function_result
		var st = null
		
		# check for any saved state
		if child != null:
			if child.has_meta('state'):
				st = child.get_meta('state')
				function_result = element.base_type.function.call(element.props, st)
		if st == null:
			# Usually first render, where initial state is set by the component itself
			function_result = element.base_type.function.call(element.props)
		
		extra_props['state'] = function_result[0]
		return gdx(function_result[1], parent, extra_props, index, name_override)
	
	# If item is component
	elif element.is_valid():
		var is_instance = element.base_type is Node
		
		# Allow both built in types and instantiable scenes
		var instance: Node
		
		if is_instance:
			instance = element.base_type
		else:
			instance = element.base_type.new()
		if name_override != null:
			instance.name = str(name_override)
		
		# On rerenders there may already be children
		var child: Node
		if index is String and parent.has_node(index as String): 
			child = parent.get_node(index as String)
		elif index is int and parent.get_child_count() > index:
			child = parent.get_child(index)
		
		if child != null:
			# Use existing child
			if child.get_class() == instance.get_class():
				instance = child
			# Replace existing child with new type
			else:
				child.replace_by(instance)
		# Add instance if not already has child
		else:
			parent.add_child.call_deferred(instance, true)
		
		instance.set_meta('component_tree', tree)
		var props = extra_props.duplicate() # Props recieved from parent
		var child_props := {} # Props to give children
		
		# Call functions into Dictionary or Array
		element.call_functions(instance)
		
		# Merge extra props from 'child_props' property of parent
		props.merge(element.props, false)
		
		if 'child_props' in props:
			child_props = props['child_props']
		
		if is_instance_valid(instance):
			handle_props(instance, props)  
		
		# Handle children
		gdx(element.children, instance, child_props)
	
	# To pass in array of elements directly
	else:
		var i = 0
		var j = 0
		var child_keys := {}
		while i < tree.size():
			if tree[i] == null:
				i += 1
				continue
			var new_element = Element.new(tree[i])
			if new_element.is_valid():
				if 'key' in new_element.props:
					var key = str(new_element.props.key)
					child_keys[key] = true
					gdx(new_element, parent, extra_props, key, key)
				else:
					gdx(new_element, parent, extra_props, j)
				j += 1
			i += 1
		if child_keys.is_empty():
			if parent.get_child_count() > j:
				for x in range(j, parent.get_child_count()):
					parent.get_child(x).queue_free()
		else:
			for child in parent.get_children():
				if not child.name in child_keys:
					child.queue_free()


func handle_props(instance: Node, props):
	if props is Dictionary and 'class_name' in props:
		var classes = props['class_name']
		if classes is String: classes = classes.split(' ')
		for _class in classes:
			if not _class in style_sheet: continue
			var class_props = style_sheet[_class]
			deep_merge(props, class_props)
		props.erase('class_name')
	
	if 'state' in props:
		instance.set_meta('state', props['state'])
	else:
		if instance.has_meta('state'):
			instance.remove_meta('state')
	
	var theme_override_map := {
		'override_constant': 'add_theme_constant_override',
		'override_font': 'add_theme_font_override',
		'override_color': 'add_theme_color_override',
		'override_font_size': 'add_theme_font_size_override',
		'override_stylebox': 'add_theme_stylebox_override',
	}
	for prop in props:
		var prop_val = props[prop]
		if instance.has_signal(prop):
			var sig: Signal = instance.get(prop)
			for connection in sig.get_connections():
				sig.disconnect(connection.callable)
			if prop_val is Callable and !instance.is_connected(prop, prop_val):
				instance.connect(prop, prop_val)
			elif prop_val is Array and !instance.is_connected(prop, prop_val[0]):
				instance.connect(prop, prop_val[0], prop_val[1])
			continue
		
		if prop in theme_override_map:
			var function = instance.get(theme_override_map[prop])
			for override_key in prop_val:
				var override_val = prop_val[override_key]
				if not override_key is Array:
					override_key = [override_key]
				for override in override_key:
					function.call(override, override_val)
			continue
		
		match prop:
			'class_name':
				pass
			'child_props':
				if props['child_props'] is Dictionary:
					pass
			'state':
				pass
			'style':
				var _style = props['style']
				if _style is Callable:
					_style = _style.call(instance)
				if _style is Dictionary:
					handle_style(instance, _style)
				# TODO Allow return a StyleBox directly
			'theme_override':
				for key in prop_val:
					for k in prop_val[key]:
						instance.call('add_theme_' + key + '_override', k, prop_val[key][k])
			'on_render':
				props['on_render'].call()
			'on_first_render':
				if first_render:
					props['on_first_render'].call()
			'disable_styles':
				var styles = props['disable_styles']
				
			_:
				call_or_set(instance, prop, props[prop])


func handle_style(source: Node, style: Dictionary, detect_signals = true):
	var empty := StyleBoxEmpty.new()
	
	for s in default_theme.get_stylebox_list(source.get_class()):
		source.add_theme_stylebox_override(s, empty)
	
	var style_box = StyleBoxFlat.new()
	var rect = func(r): return r
	var transition = 0
	
	if 'hovered' in style:
		var hover_style = style['hovered']
		if hover_style is Dictionary:
			try_connect(source.mouse_entered, on_mouse_entered.bind(source, style, hover_style))
			try_connect(source.mouse_exited, on_mouse_exited.bind(source, style, hover_style))
		else:
			style = spread(style, hover_style[0])
	if 'pressed' in style:
		var press_style = style['pressed']
		if press_style is Dictionary:
			try_connect(source.gui_input, on_gui_input.bind(source, style, press_style))
		else:
			style = spread(style, press_style[0])
	
	var behind_parent = true
	for key in style:
		var val = style[key]
		match key:
			'show_behind_parent':
				behind_parent = val
			'z_index':
				RenderingServer.canvas_item_set_z_index(source.get_canvas_item(), val)
			'rect':
				rect = val
			'transition':
				transition = val
			'set_content_margin_all':
				empty.content_margin_bottom = val
				empty.content_margin_left = val
				empty.content_margin_right = val
				empty.content_margin_top = val
			_:
				if key.begins_with('content_margin_'):
					empty.set(key, val)
		call_or_set(style_box, key, val)
	transition_style(source, style_box, rect, transition, behind_parent)


func transition_style(source: Node, new_style: StyleBoxFlat, rect: Callable, transition, behind_parent = true):
	var duration = transition
	if source.has_meta('styler'):
		var styler = source.get_meta('styler')
		if !is_instance_valid(styler):
			return
		styler.rect_func = rect
		var stylebox: StyleBoxFlat = styler.style_box
		
		var tween = create_tween().set_parallel()
		if source.has_meta('tween'):
			var t: Tween = source.get_meta('tween')
			t.kill()
		source.set_meta('tween', tween)
		
		for property in new_style.get_property_list():
			var prop = property.name
			if property.usage & PROPERTY_USAGE_STORAGE and stylebox.get(prop) != new_style.get(prop):
				tween.tween_property(stylebox, prop, new_style.get(prop), duration)
		tween.tween_method(func(a): if is_instance_valid(styler): styler.queue_redraw(), 0, 1, duration)
	else:
		var styler = StyleDrawer.instantiate()
		styler.style_box = new_style
		styler.show_behind_parent = behind_parent
		styler.rect_func = rect
		source.add_child(styler, false, Node.INTERNAL_MODE_FRONT)
		source.set_meta('styler', styler)


func deep_merge(d1, d2, overwrite := false):
	if not d2 is Dictionary: return
	
	for key in d2:
		var val = d2[key]
		if key in d1:
			if d1[key] is Dictionary and d2[key] is Dictionary:
				deep_merge(d1[key], d2[key])
			elif overwrite:
				d1[key] = val
		else:
			d1[key] = val

func map_i(array: Array, callable: Callable):
	var result = []
	for i in array.size():
		var val = array[i]
		result.append(callable.call(val, i))
	return result

func map_key(dict: Dictionary, callable: Callable):
	var result := {}
	for key in dict:
		var val = dict[key]
		var call_val = callable.call(key, val)
		if call_val is Dictionary:
			result.merge(call_val, true)
		elif call_val is Array:
			result.merge({str(key): call_val}, true)
	return result


func spread(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := {}
	result.merge(base, true)
	result.merge(extra, true)
	return result

func spread_array(base: Array, extra: Array) -> Array:
	var result := []
	result.append_array(base)
	result.append_array(extra)
	return result

func dict_to_stylebox(dict: Dictionary):
	var stylebox := StyleBoxFlat.new()
	for key in dict:
		call_or_set(stylebox, key, dict[key])
	return stylebox

func disconnect_signal(sig: Signal):
	for connection in sig.get_connections():
		var callable = connection.callable
		sig.disconnect(callable)

func on_gui_input(event, source, style, press_style):
	if event is InputEventMouseButton:
		if event.pressed:
			style['pressed'] = [press_style]
			handle_style(source, style)
		else:
			style['pressed'] = press_style
			handle_style(source, style)

func on_mouse_entered(source, style, hover_style):
	style['hovered'] = [hover_style]
	handle_style(source, style)

func on_mouse_exited(source, style, hover_style):
	style['hovered'] = hover_style
	handle_style(source, style)

func try_connect(sig: Signal, callback: Callable, flags: ConnectFlags = 0):
	if !sig.is_connected(callback):
		sig.connect(callback, flags)

func reconnect(sig: Signal, callback: Callable, flags: ConnectFlags = 0):
	if sig.is_connected(callback):
		sig.disconnect(callback)
	sig.connect(callback, flags)

func new_connect(sig: Signal, callback: Callable, flags: ConnectFlags = 0):
	for connection in sig.get_connections():
		sig.disconnect(connection.callable)
	sig.connect(callback, flags)

func call_or_set(object, key, val):
	if object.has_method(key):
		if val is Array:
			object.get(key).callv(val)
		else:
			object.get(key).call(val)
	else:
		object.set_indexed(key, val)


func render():
	return [Label, {text = "Defalt Component"}]
