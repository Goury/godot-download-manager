extends Node2D

## Example scene demonstrating the DownloadProgress workflow.
## With auto_start=false: checks cache first, prompts user, then downloads.
## With auto_start=true: downloads immediately without prompting.

@onready var downloader: DownloadProgress = $DownloadProgress
@onready var title_label: Label = $CanvasLayer/VBoxContainer/TitleLabel
@onready var progress_bar: ProgressBar = $CanvasLayer/VBoxContainer/ProgressBar
@onready var status_label: Label = $CanvasLayer/VBoxContainer/StatusLabel
@onready var update_button: Button = $CanvasLayer/VBoxContainer/UpdateButton

var _current_file: String = ""

func _ready() -> void:
	update_button.visible = false
	title_label.text = "Checking for updates..."

	downloader.check_completed.connect(_on_check_completed)
	downloader.started.connect(_on_started)
	downloader.group_progress.connect(_on_group_progress)
	downloader.group_completed.connect(_on_group_completed)
	downloader.all_completed.connect(_on_all_completed)
	downloader.file_started.connect(_on_file_started)
	update_button.pressed.connect(_on_update_pressed)

#region Signal Handlers

func _on_check_completed(needs_download: bool, download_bytes: int) -> void:
	if needs_download:
		title_label.text = "Update available!"
		status_label.text = "%.2f MB to download" % [download_bytes / 1048576.0]
		update_button.visible = true

func _on_update_pressed() -> void:
	update_button.visible = false
	downloader.start()

func _on_started() -> void:
	title_label.text = "Downloading..."

func _on_file_started(file_name: String) -> void:
	_current_file = file_name

func _on_group_progress(group_name: String, group_index: int, group_count: int, downloaded: int, total: int) -> void:
	title_label.text = "Downloading: %s (%d/%d)" % [group_name, group_index + 1, group_count]
	if total > 0:
		progress_bar.value = float(downloaded) / float(total) * 100.0
		status_label.text = "%s (%.2f / %.2f MB)" % [_current_file, downloaded / 1048576.0, total / 1048576.0]
	else:
		status_label.text = _current_file

func _on_group_completed(group_name: String, success: bool) -> void:
	print("Group '%s': %s" % [group_name, "OK" if success else "FAILED"])
	progress_bar.value = 0

func _on_all_completed(success: bool) -> void:
	if success:
		title_label.text = "Ready!"
		progress_bar.value = 100.0
		status_label.text = "All content is up to date"
		print("Entering game!")
	else:
		title_label.text = "Download failed"
		status_label.text = "Some files could not be downloaded"
		status_label.modulate = Color.RED

#endregion
