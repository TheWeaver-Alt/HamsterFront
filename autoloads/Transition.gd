extends CanvasLayer
## Transition — scene changes with a pixel wipe.
## API (stable): Transition.change_scene(path: String) and Transition.reload_scene().
## Implementation is owned by the UI polish pass; this default just switches immediately.

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func change_scene(path: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)


func reload_scene() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
