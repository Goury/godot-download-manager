@tool
extends EditorPlugin

## Registers the DLClient autoload singleton when the plugin is enabled.

const AUTOLOAD_NAME: String = "DLClient"
const AUTOLOAD_PATH: String = "res://addons/download_manager/download_client.gd"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
