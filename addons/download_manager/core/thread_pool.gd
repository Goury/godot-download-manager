class_name DownloadThreadPool
extends RefCounted

## Manages a pool of worker threads that process DownloadTask items.
## Tasks are dequeued and executed via DownloadWorker.execute().

#region Private State

var _threads: Array[Thread] = []
var _queue: Array[Array] = []  # Each item: [DownloadTask, Callable, Callable, Callable]
var _queue_mutex: Mutex = Mutex.new()
var _semaphore: Semaphore = Semaphore.new()
var _exit_mutex: Mutex = Mutex.new()
var _exit_flag: bool = false

#endregion

#region Public API

func start(thread_count: int = 4) -> void:
	for i: int in range(thread_count):
		var t: Thread = Thread.new()
		t.start(_worker_loop)
		_threads.append(t)

func enqueue(task: DownloadTask, on_started: Callable, on_progress: Callable, on_completed: Callable) -> void:
	_queue_mutex.lock()
	_queue.append([task, on_started, on_progress, on_completed])
	_queue_mutex.unlock()
	_semaphore.post()

func shutdown() -> void:
	_exit_mutex.lock()
	_exit_flag = true
	_exit_mutex.unlock()

	for i: int in range(_threads.size()):
		_semaphore.post()
	for t: Thread in _threads:
		if t.is_alive():
			t.wait_to_finish()
	_threads.clear()

#endregion

#region Worker Loop

func _should_exit() -> bool:
	_exit_mutex.lock()
	var val: bool = _exit_flag
	_exit_mutex.unlock()
	return val

func _worker_loop() -> void:
	while true:
		_semaphore.wait()
		if _should_exit():
			break

		var item: Array = []
		_queue_mutex.lock()
		if _queue.size() > 0:
			item = _queue.pop_front()
		_queue_mutex.unlock()

		if item.size() == 4:
			DownloadWorker.execute(
				item[0] as DownloadTask,
				item[1] as Callable,
				item[2] as Callable,
				item[3] as Callable
			)

#endregion
