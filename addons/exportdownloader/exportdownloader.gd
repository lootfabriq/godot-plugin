@tool
extends EditorPlugin

var tool_scene = preload("res://addons/exportdownloader/tool_panel.tscn")
var panel

func _enter_tree() -> void:
	panel = tool_scene.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, panel)

func _exit_tree() -> void:
	remove_control_from_docks(panel)
	panel.queue_free()
