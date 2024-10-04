@tool
extends Control

const host = "https://api.lootfabriq.io"
# const host = "http://localhost:7000"

const dictionary_downloader = preload("res://addons/exportdownloader/dictionary_downloader.gd")
const image_downloader = preload("res://addons/exportdownloader/image_downloader.gd")

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(_on_report_request_completed)
	$VBoxContainer/DownloadDictionariesButton.pressed.connect(_on_download_dictionaries_button_pressed)

func get_headers() -> Array:
	return ["x-lootf-token: %s" % $VBoxContainer/TextEditAPIKey.text]


func _on_download_dictionaries_button_pressed() -> void:
	var instance_id = int($VBoxContainer/TextEditInstanceID.text)
	if instance_id == 0:
		print("Fill in Instance ID")
		return
	
	if len($VBoxContainer/TextEditAPIKey.text) == 0:
		print("Fill in API KEY")
		return

	if not DirAccess.dir_exists_absolute($VBoxContainer/TextEditExportPath.text):
		var code = DirAccess.make_dir_recursive_absolute($VBoxContainer/TextEditExportPath.text)
		if code != 0:
			print("Creating ", $VBoxContainer/TextEditExportPath.text, " failed")
			return

	if not DirAccess.dir_exists_absolute($VBoxContainer/TextEditExportImagePath.text):
		var code = DirAccess.make_dir_recursive_absolute($VBoxContainer/TextEditExportImagePath.text)
		if code != 0:
			print("Creating ", $VBoxContainer/TextEditExportImagePath.text, " failed")
			return


	var url = "%s/v1/api/instances/%d/reports/last-completed" % [host, instance_id]

	http_request.request(url, get_headers(), HTTPClient.METHOD_GET)


func _on_report_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	$VBoxContainer/ProgressBar.max_value = len(json["dictionaries"])
	$VBoxContainer/ProgressBar.value = 0
	
	print("Report: %s" % json['id'])

	for dictionary in json["dictionaries"]:
		$VBoxContainer/ProgressBar.value += 1

		var downloader = dictionary_downloader.new(host, dictionary["template_id"], dictionary["file"], get_headers())
		add_child(downloader)
		downloader.download($VBoxContainer/TextEditExportPath.text)
		var is_err = await downloader.download_completed
		if is_err:
			print("Dictionary ", dictionary["template_id"], " download failed")
			continue

		downloader.queue_free()
	
	print("=> Dictionaries downloaded")

	await download_images($VBoxContainer/TextEditExportPath.text, $VBoxContainer/TextEditExportImagePath.text)


func download_images(dictionary_export_path, image_export_path: String):
	var file_path = "%s/%s" % [dictionary_export_path, "image.json"]

	var dictionary = FileAccess.open(file_path, FileAccess.READ)
	var content = dictionary.get_as_text()
	dictionary.close()

	var versions = get_versions(image_export_path)
	var images = JSON.parse_string(content)

	if images == null:
		print("image.json dictionary is empty")
		return

	$VBoxContainer/ProgressBar.max_value = len(images)
	$VBoxContainer/ProgressBar.value = 0

	var total: int
	var skipped: int
	var downloaded: int
	
	for image in images:
		total += 1
		$VBoxContainer/ProgressBar.value += 1

		if not is_image_download_required(versions, image['id'], image['img']['v']):
			skipped += 1
			continue

		var downloader = image_downloader.new(
			image["id"],
			host,
			image['img']['p'],
			get_headers())

		add_child(downloader)
		downloader.download(image_export_path)

		var is_err = await downloader.download_completed
		if is_err:
			print("Image ", image["id"], " download failed")
			continue

		versions[int(image['id'])] = image['img']['v']
		downloaded += 1

		downloader.queue_free()
	
	save_versions(image_export_path, versions)
	print("=> Image synced")
	print("Total: ", total)
	print("Skipped: ", skipped)
	print("Downloaded: ", downloaded)


func get_versions_file_path(image_export_path) -> String:
	return "%s/%s" % [image_export_path, "versions.json"]


func get_versions(image_export_path) -> Dictionary:
	var versions_file_path = get_versions_file_path(image_export_path)
	var version_map = {}

	if FileAccess.file_exists(versions_file_path):
		var versions_dictionary = FileAccess.open(versions_file_path, FileAccess.READ)
		var content = versions_dictionary.get_as_text()
		versions_dictionary.close()

		var versions = JSON.parse_string(content)
		for version in versions:
			version_map[int(version["id"])] = version["version"]
	
	return version_map


func save_versions(image_export_path: String, version_map: Dictionary) -> void:
	var versions_file_path = get_versions_file_path(image_export_path)
	var versions: Array

	for id in version_map:
		versions.append({
			"id": int(id),
			"version": version_map[id]
		})

	var payload = JSON.stringify(versions)

	var dictionary = FileAccess.open(versions_file_path, FileAccess.WRITE)
	dictionary.store_string(payload)
	dictionary.close()


func is_image_download_required(versions: Dictionary, item_id: int, new_version: int) -> bool:
	# not local stored version
	if item_id not in versions:
		return true

	# existing version less then in the new dictionary
	return versions[item_id] < new_version
