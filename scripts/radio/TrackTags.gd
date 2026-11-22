extends RefCounted

const AUDIO_SUFFIXES := ["mp3", "ogg", "wav"]
const TAG_LIMIT := 262144


static func read(path: String) -> Dictionary:
	var tags := {}
	var filename := path.get_file().trim_suffix(".audio")
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		match filename.get_extension().to_lower():
			"mp3":
				tags = _mp3(file)
			"ogg":
				tags = _ogg(file)
			"wav":
				tags = _wav(file)
	var parts := filename.get_basename().replace("_", " ").split(" - ", false, 1)
	if parts.size() < 2:
		parts = filename.get_basename().replace("_", " ").split(" — ", false, 1)
	var title := str(tags.get("title", "")).strip_edges()
	var artist := str(tags.get("artist", "")).strip_edges()
	return {
		"title": title if not title.is_empty() else (parts[1] if parts.size() > 1 else filename.get_basename()),
		"artist": artist if not artist.is_empty() else (parts[0] if parts.size() > 1 else "Unknown artist")
	}


static func _mp3(file: FileAccess) -> Dictionary:
	var tags := {}
	var header := file.get_buffer(10)
	if header.size() != 10:
		return tags
	var version := header[3]
	if header.slice(0, 3).get_string_from_ascii() == "ID3" and version in [2, 3, 4]:
		var frames := file.get_buffer(mini(_syncsafe(header, 6), TAG_LIMIT))
		var cursor := 0
		if version > 2 and header[5] & 64 and frames.size() >= 4:
			cursor = _syncsafe(frames, 0) if version == 4 else _big_endian(frames, 0, 4) + 4
		var id_size := 3 if version == 2 else 4
		var frame_header := 6 if version == 2 else 10
		while cursor >= 0 and cursor + frame_header <= frames.size() and frames[cursor] != 0:
			var id := frames.slice(cursor, cursor + id_size).get_string_from_ascii()
			var size_at := cursor + id_size
			var length := _syncsafe(frames, size_at) if version == 4 else _big_endian(frames, size_at, id_size)
			var data_at := cursor + frame_header
			if length <= 0 or data_at + length > frames.size():
				break
			if id in ["TIT2", "TT2", "TPE1", "TP1"]:
				var text := frames.slice(data_at, data_at + length)
				if header[5] & 128 or (version == 4 and frames[cursor + 9] & 2):
					text = _remove_unsynchronization(text)
				tags["title" if id in ["TIT2", "TT2"] else "artist"] = _id3_text(text)
			cursor = data_at + length
	if (not tags.has("title") or not tags.has("artist")) and file.get_length() >= 128:
		file.seek(file.get_length() - 128)
		var footer := file.get_buffer(128)
		if footer.slice(0, 3).get_string_from_ascii() == "TAG":
			tags.get_or_add("title", _latin(footer.slice(3, 33)))
			tags.get_or_add("artist", _latin(footer.slice(33, 63)))
	return tags


static func _id3_text(bytes: PackedByteArray) -> String:
	if bytes.size() < 2:
		return ""
	var encoding := bytes[0]
	var body := bytes.slice(1)
	match encoding:
		0:
			return _latin(body)
		1, 2:
			var big_endian := encoding == 2
			if body.size() >= 2:
				if body[0] == 254 and body[1] == 255:
					big_endian = true
					body = body.slice(2)
				elif body[0] == 255 and body[1] == 254:
					body = body.slice(2)
			body.resize(body.size() - body.size() % 2)
			if big_endian:
				for index in range(0, body.size(), 2):
					var first := body[index]
					body[index] = body[index + 1]
					body[index + 1] = first
			return body.get_string_from_utf16().strip_edges()
		3:
			return body.get_string_from_utf8().strip_edges()
	return ""


static func _remove_unsynchronization(data: PackedByteArray) -> PackedByteArray:
	var clean := PackedByteArray()
	for index in data.size():
		if index > 0 and data[index] == 0 and data[index - 1] == 255:
			continue
		clean.append(data[index])
	return clean


static func _syncsafe(data: PackedByteArray, at: int) -> int:
	return ((data[at] & 127) << 21) | ((data[at + 1] & 127) << 14) | ((data[at + 2] & 127) << 7) | (data[at + 3] & 127)


static func _big_endian(data: PackedByteArray, at: int, length: int) -> int:
	var value := 0
	for index in range(at, at + length):
		value = value * 256 + data[index]
	return value


static func _latin(data: PackedByteArray) -> String:
	var value := ""
	for byte: int in data:
		if byte == 0:
			break
		value += String.chr(byte)
	return value.strip_edges()


static func _ogg(file: FileAccess) -> Dictionary:
	var packet := PackedByteArray()
	while file.get_position() < mini(file.get_length(), TAG_LIMIT):
		var page := file.get_buffer(27)
		if page.size() != 27 or page.slice(0, 4).get_string_from_ascii() != "OggS":
			break
		var lengths := file.get_buffer(page[26])
		for length: int in lengths:
			packet.append_array(file.get_buffer(length))
			if packet.size() > TAG_LIMIT:
				return {}
			if length < 255:
				if packet.size() >= 11 and packet[0] == 3 and packet.slice(1, 7).get_string_from_ascii() == "vorbis":
					return _vorbis_comments(packet, 7)
				packet.clear()
	return {}


static func _vorbis_comments(packet: PackedByteArray, at: int) -> Dictionary:
	var result := {}
	var cursor := at + 4 + packet.decode_u32(at)
	if cursor + 4 > packet.size():
		return result
	var count := mini(packet.decode_u32(cursor), 256)
	cursor += 4
	for index in count:
		if cursor + 4 > packet.size():
			break
		var length := packet.decode_u32(cursor)
		cursor += 4
		if cursor + length > packet.size():
			break
		var pair := packet.slice(cursor, cursor + length).get_string_from_utf8().split("=", true, 1)
		if pair.size() == 2 and pair[0].to_lower() in ["title", "artist"]:
			result.get_or_add(pair[0].to_lower(), pair[1])
		cursor += length
	return result


static func _wav(file: FileAccess) -> Dictionary:
	var result := {}
	var header := file.get_buffer(12)
	if header.size() != 12 or header.slice(0, 4).get_string_from_ascii() != "RIFF":
		return result
	for index in 256:
		if file.get_position() + 8 > file.get_length():
			break
		var name := file.get_buffer(4).get_string_from_ascii()
		var length := file.get_32()
		var at := file.get_position()
		if length > file.get_length() - at:
			break
		if name == "LIST" and length >= 4 and length <= TAG_LIMIT:
			var data := file.get_buffer(length)
			if data.slice(0, 4).get_string_from_ascii() == "INFO":
				var cursor := 4
				while cursor + 8 <= data.size():
					var id := data.slice(cursor, cursor + 4).get_string_from_ascii()
					var size := data.decode_u32(cursor + 4)
					cursor += 8
					if size > data.size() - cursor:
						break
					if id in ["INAM", "IART"]:
						result["title" if id == "INAM" else "artist"] = _latin(data.slice(cursor, cursor + size))
					cursor += size + (size % 2)
		file.seek(at + length + (length % 2))
	return result
