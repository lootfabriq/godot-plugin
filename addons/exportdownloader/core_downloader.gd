extends Control

class_name CoreDownloader

var base_path: String
var headers: Array


signal download_completed(is_err: bool)


func _init(base_path: String, headers: Array) -> void:
	self.base_path = base_path
	self.headers = headers


func get_url() -> String:
	return ""


func download(export_path: String) -> void:
	var url = get_url()
		
	var download_dictionary_request = HTTPRequest.new()
	add_child(download_dictionary_request)

	download_dictionary_request.request_completed.connect(
		func(result, response_code, headers, body):
			# we expecting redirect from server to the file storage.
			if response_code != 307:
				print("expected 307 code: ", url)
				emit_signal("download_completed", true)
				return

			for header in headers:
				if header.begins_with("Location:".to_lower()):
					var redirect_url = header.replace("Location: ".to_lower(), "").strip_edges()

					self.do_redirect_request(redirect_url, export_path)
					return

			emit_signal("download_completed", true)
			print("Header Location not found")
	)

	print(url)
	download_dictionary_request.request(url, self.headers, HTTPClient.METHOD_GET)


# template method
func do_redirect_request(redirect_url, export_path: String) -> void:
	pass
