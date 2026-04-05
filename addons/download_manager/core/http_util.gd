class_name HttpUtil
extends RefCounted

## Shared HTTP utilities for URL parsing and blocking requests.
## Used internally by DownloadWorker, DownloadGroup, and DownloadClient.

const CONNECT_TIMEOUT_MS: int = 10000
const REQUEST_TIMEOUT_MS: int = 10000
const DATA_TIMEOUT_MS: int = 10000
const USER_AGENT: String = "GodotDownloadManager/2.0"

#region URL Parsing

class ParsedUrl:
	var host: String
	var port: int
	var path: String
	var use_tls: bool

static func parse_url(raw_url: String) -> ParsedUrl:
	var result: ParsedUrl = ParsedUrl.new()
	var url: String = raw_url

	if url.begins_with("https://"):
		result.use_tls = true
		result.port = 443
		url = url.trim_prefix("https://")
	elif url.begins_with("http://"):
		result.use_tls = false
		result.port = 80
		url = url.trim_prefix("http://")
	else:
		result.use_tls = false
		result.port = 80

	var path_start: int = url.find("/")
	var host_part: String = url if path_start == -1 else url.substr(0, path_start)
	result.path = "/" if path_start == -1 else url.substr(path_start)

	var colon_pos: int = host_part.find(":")
	if colon_pos != -1:
		result.host = host_part.substr(0, colon_pos)
		result.port = host_part.substr(colon_pos + 1).to_int()
	else:
		result.host = host_part

	return result

#endregion

#region JSON Parsing

## Parses a JSON string into an array of file entries.
## Supports two formats:
##   Format 1 (plain array):  [{"url": ..., "size": ..., "hash": ...}, ...]
##   Format 2 (versioned):    {"version": 1, "files": [...]}
static func parse_manifest_json(text: String) -> Array:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_warning("HttpUtil: JSON parse error: " + json.get_error_message())
		return []
	if json.data is Array:
		return json.data
	if json.data is Dictionary and json.data.has("files") and json.data["files"] is Array:
		return json.data["files"]
	push_warning("HttpUtil: Invalid manifest format. Expected Array or {version, files}.")
	return []

#endregion

#region Blocking HTTP Fetch

## Fetches a URL and returns the response body as a string.
## Blocks the calling thread. Returns "" on any error.
static func fetch_url_blocking(url: String) -> String:
	var parsed: ParsedUrl = parse_url(url)
	var http: HTTPClient = HTTPClient.new()
	var tls: TLSOptions = TLSOptions.client() if parsed.use_tls else null

	var err: Error = http.connect_to_host(parsed.host, parsed.port, tls)
	if err != OK:
		push_warning("HttpUtil: Connection error for %s: %s" % [url, str(err)])
		return ""

	var start: int = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > CONNECT_TIMEOUT_MS:
			push_warning("HttpUtil: Connection timeout for " + url)
			return ""

	err = http.request(HTTPClient.METHOD_GET, parsed.path, ["User-Agent: " + USER_AGENT])
	if err != OK:
		push_warning("HttpUtil: Request error for %s: %s" % [url, str(err)])
		return ""

	var req_start: int = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - req_start > REQUEST_TIMEOUT_MS:
			push_warning("HttpUtil: Request timeout for " + url)
			return ""

	if not http.has_response():
		push_warning("HttpUtil: No response from " + url)
		return ""
	var response_code: int = http.get_response_code()
	if response_code != 200:
		push_warning("HttpUtil: HTTP %d from %s" % [response_code, url])
		return ""

	var body: PackedByteArray = PackedByteArray()
	var last_data: int = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk: PackedByteArray = http.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
			last_data = Time.get_ticks_msec()
		else:
			OS.delay_msec(10)
			if Time.get_ticks_msec() - last_data > DATA_TIMEOUT_MS:
				push_warning("HttpUtil: Data timeout fetching " + url)
				return ""

	return body.get_string_from_utf8()

#endregion

#region Source Detection

static func is_remote(source: String) -> bool:
	return source.begins_with("http://") or source.begins_with("https://")

#endregion
