extends CoreDownloader

class_name ImageDownloader

var file_sub_path: String
var item_id: int


func get_url() -> String:
	return "%s/v1/api/images/%s" % [self.base_path, self.file_sub_path]


func _init(item_id: int, base_path, file_sub_path: String, headers: Array) -> void:
	super(base_path, headers)
	self.item_id = item_id
	self.file_sub_path = file_sub_path


func do_redirect_request(redirect_url, export_path: String) -> void:
	var file_name = "%s.%s" % [self.item_id, self.file_sub_path.get_extension()]
	var file_path = "%s/%s" % [export_path, file_name]

	var redirect_request = HTTPRequest.new()
	add_child(redirect_request)

	redirect_request.request_completed.connect(
		func(result, response_code, headers, body):
			if response_code != 200:
				print("error on download. status_code: %s" % response_code)
				print(body.get_string_from_utf8())
				emit_signal("download_completed", true)

				return

			var dictionary = FileAccess.open(file_path, FileAccess.WRITE)
			dictionary.store_buffer(body)
			dictionary.close()

			print("Downloaded: %s" % file_path)

			emit_signal("download_completed", false)
	)

	redirect_request.request(redirect_url, [], HTTPClient.METHOD_GET)
