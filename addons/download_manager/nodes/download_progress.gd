@tool
class_name DownloadProgress
extends Node

## Orchestrates sequential group downloads. Add DownloadGroup nodes as children.
## Emits signals only — the user is responsible for building their own UI.

#region Exports

## Root directory for all downloaded files. Each group saves to a subfolder within this path.
@export var base_folder: String = "user://downloads/"

## Number of concurrent download threads per group.
@export_range(1, 16) var max_threads: int = 8

## When true, downloads begin immediately on scene ready.
## When false, a cache check runs first and emits [signal check_completed],
## allowing the user to prompt before calling [method start].
@export var auto_start: bool = false

#endregion

#region Signals

## Emitted when downloading begins (after [method start] is called).
signal started()

## Emitted after the cache check completes (only when [member auto_start] is false).
## If [param needs_download] is false, [signal all_completed] follows immediately.
## If true, call [method start] to begin downloading.
signal check_completed(needs_download: bool, download_bytes: int)

## Emitted every frame while a group is downloading.
## [param downloaded] and [param total] are in bytes.
signal group_progress(group_name: String, group_index: int, group_count: int, downloaded: int, total: int)

## Emitted when a group finishes (all tasks reached a terminal state).
signal group_completed(group_name: String, success: bool)

## Emitted when a file begins downloading. [param file_name] has no directory prefix.
signal file_started(file_name: String)

## Emitted when all groups have completed (or were fully cached).
signal all_completed(success: bool)

#endregion

#region Internal State

enum _State { IDLE, CHECKING, RESOLVING, DOWNLOADING, DONE }

var _thread_pool: DownloadThreadPool
var _groups: Array[DownloadGroup] = []
var _current_group_index: int = -1
var _has_any_error: bool = false
var _state: _State = _State.IDLE

var _manifest_thread: Thread = null
var _check_thread: Thread = null
var _check_mutex: Mutex = Mutex.new()
var _check_done: bool = false
var _check_result: Dictionary = {}

#endregion

#region Lifecycle

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	_scan_groups()
	if auto_start:
		start.call_deferred()
	else:
		check.call_deferred()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _state:
		_State.CHECKING:
			_process_checking()
		_State.RESOLVING:
			_process_resolving()
		_State.DOWNLOADING:
			_process_downloading()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _check_thread and _check_thread.is_alive():
		_check_thread.wait_to_finish()
	if _manifest_thread and _manifest_thread.is_alive():
		_manifest_thread.wait_to_finish()
	if _thread_pool:
		_thread_pool.shutdown()

#endregion

#region Public API

## Runs a background cache check for all groups.
## Emits [signal check_completed] when done.
## If all files are already cached, also emits [signal all_completed].
func check() -> void:
	if _state != _State.IDLE or _groups.is_empty():
		check_completed.emit(false, 0)
		all_completed.emit(true)
		return

	_state = _State.CHECKING
	_check_mutex.lock()
	_check_done = false
	_check_result = {}
	_check_mutex.unlock()
	_check_thread = Thread.new()
	_check_thread.start(_do_check)
	set_process(true)

## Begins downloading. Call directly if [member auto_start] is true,
## or after receiving [signal check_completed] with needs_download == true.
## Can also be called after completion to retry failed downloads.
func start() -> void:
	if _groups.is_empty():
		return
	if _state != _State.IDLE and _state != _State.DONE:
		return

	if _state == _State.DONE:
		for group: DownloadGroup in _groups:
			group.reset()

	_has_any_error = false
	_current_group_index = -1
	_state = _State.IDLE

	if _thread_pool:
		_thread_pool.shutdown()
	_thread_pool = DownloadThreadPool.new()
	_thread_pool.start(max_threads)

	started.emit()
	_advance_to_next_group()
	set_process(true)

## Returns the display name of the group currently being downloaded.
func get_current_group_name() -> String:
	if _current_group_index >= 0 and _current_group_index < _groups.size():
		return _groups[_current_group_index].get_display_name()
	return ""

## Returns the zero-based index of the current group.
func get_current_group_index() -> int:
	return _current_group_index

## Returns the DownloadGroup at the given index, or null if out of range.
func get_group(index: int) -> DownloadGroup:
	if index >= 0 and index < _groups.size():
		return _groups[index]
	return null

## Returns the total number of groups.
func get_group_count() -> int:
	return _groups.size()

## Returns true while a download or resolution is in progress.
func is_running() -> bool:
	return _state == _State.RESOLVING or _state == _State.DOWNLOADING

#endregion

#region Cache Check (runs in background thread)

func _do_check() -> void:
	var download_bytes: int = 0
	var needs_download: bool = false

	for group: DownloadGroup in _groups:
		if group.is_remote_source():
			group.resolve_tasks_from_url(base_folder)
		else:
			group.resolve_tasks(base_folder)

		for task: DownloadTask in group._get_tasks():
			if not DownloadWorker._try_cache(task):
				needs_download = true
				download_bytes += task.expected_size

	_check_mutex.lock()
	_check_result = {"needs_download": needs_download, "download_bytes": download_bytes}
	_check_done = true
	_check_mutex.unlock()

func _process_checking() -> void:
	_check_mutex.lock()
	var done: bool = _check_done
	_check_mutex.unlock()

	if not done:
		return

	if _check_thread:
		_check_thread.wait_to_finish()
		_check_thread = null

	_check_mutex.lock()
	var needs: bool = _check_result.get("needs_download", false)
	var dl_bytes: int = _check_result.get("download_bytes", 0)
	_check_mutex.unlock()

	if needs:
		_state = _State.IDLE
		set_process(false)
		check_completed.emit(true, dl_bytes)
	else:
		for group: DownloadGroup in _groups:
			for task: DownloadTask in group._get_tasks():
				task.sync_exact_bytes(task.expected_size, task.expected_size)
				task.set_status(DownloadTask.Status.DONE)
		_state = _State.DONE
		set_process(false)
		check_completed.emit(false, 0)
		all_completed.emit(true)

#endregion

#region Download Flow

func _scan_groups() -> void:
	_groups.clear()
	for child: Node in get_children():
		if child is DownloadGroup:
			_groups.append(child)

func _advance_to_next_group() -> void:
	_current_group_index += 1

	if _current_group_index >= _groups.size():
		_finish_all()
		return

	var group: DownloadGroup = _groups[_current_group_index]

	if group.is_remote_source() and not group.is_resolved():
		_state = _State.RESOLVING
		_manifest_thread = Thread.new()
		_manifest_thread.start(_resolve_remote_group.bind(group))
	else:
		_enqueue_group(group)

func _resolve_remote_group(group: DownloadGroup) -> void:
	group.resolve_tasks_from_url(base_folder)

func _enqueue_group(group: DownloadGroup) -> void:
	var tasks: Array[DownloadTask]
	if group.is_resolved():
		tasks = group._get_tasks()
	else:
		tasks = group.resolve_tasks(base_folder)

	if tasks.is_empty():
		group_completed.emit(group.get_display_name(), true)
		_advance_to_next_group()
		return

	_state = _State.DOWNLOADING
	for task: DownloadTask in tasks:
		_thread_pool.enqueue(task, _on_task_started, _on_task_progress, _on_task_completed)

func _process_resolving() -> void:
	var group: DownloadGroup = _groups[_current_group_index]
	if not group.is_resolved():
		return
	if _manifest_thread:
		_manifest_thread.wait_to_finish()
		_manifest_thread = null
	_enqueue_group(group)

func _process_downloading() -> void:
	if _current_group_index < 0 or _current_group_index >= _groups.size():
		return

	var group: DownloadGroup = _groups[_current_group_index]
	var agg: Dictionary = group.get_aggregate_progress()

	group_progress.emit(group.get_display_name(), _current_group_index, _groups.size(), agg.dl, agg.total)

	if group.is_finished():
		var success: bool = not group.has_errors()
		if not success:
			_has_any_error = true
		group_completed.emit(group.get_display_name(), success)
		_advance_to_next_group()

func _finish_all() -> void:
	_state = _State.DONE
	set_process(false)
	all_completed.emit(not _has_any_error)

#endregion

#region Worker Thread Callbacks

func _on_task_started(task: DownloadTask) -> void:
	file_started.emit(task.save_path.get_file())

func _on_task_progress(_task: DownloadTask) -> void:
	pass

func _on_task_completed(_task: DownloadTask, _success: bool) -> void:
	pass

#endregion

#region Editor Warnings

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if base_folder == "":
		warnings.append("base_folder is not configured.")
	var has_group: bool = false
	for child: Node in get_children():
		if child is DownloadGroup:
			has_group = true
			break
	if not has_group:
		warnings.append("Add at least one DownloadGroup as a child node.")
	return warnings

#endregion
