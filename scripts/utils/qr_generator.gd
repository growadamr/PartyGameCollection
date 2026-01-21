class_name QRGenerator
extends RefCounted

## QR Code generator for Godot 4
## Generates QR codes as Image objects
## Supports Version 1-6 QR codes with automatic version selection

const EC_LEVEL_L = 0  # 7% error correction

# Data capacity (bytes) for each version at EC Level L
const VERSION_CAPACITY = {
	1: 17,
	2: 32,
	3: 53,
	4: 78,
	5: 106,
	6: 134
}

# QR code sizes
const VERSION_SIZE = {
	1: 21,
	2: 25,
	3: 29,
	4: 33,
	5: 37,
	6: 41
}

# Alignment pattern positions
const ALIGNMENT_POSITIONS = {
	1: [],
	2: [6, 18],
	3: [6, 22],
	4: [6, 26],
	5: [6, 30],
	6: [6, 34]
}

# EC codewords per version at Level L
const EC_CODEWORDS = {
	1: 7,
	2: 10,
	3: 15,
	4: 20,
	5: 26,
	6: 18
}

var _version: int
var _size: int
var _gf_exp: Array = []
var _gf_log: Array = []

func _init():
	_init_gf_tables()

static func generate(text: String, module_size: int = 8, quiet_zone: int = 4) -> Image:
	var qr = QRGenerator.new()
	return qr._generate_qr(text, module_size, quiet_zone)

func _generate_qr(text: String, module_size: int, quiet_zone: int) -> Image:
	# Select appropriate version based on text length
	_version = _select_version(text.length())
	if _version == 0:
		push_error("Text too long for QR code")
		return null

	_size = VERSION_SIZE[_version]

	print("QR: Using version ", _version, " (", _size, "x", _size, ") for ", text.length(), " bytes")

	# Encode data
	var data_bits = _encode_data(text)
	var codewords = _bits_to_codewords(data_bits)

	# Add error correction
	var ec = _generate_ec(codewords)
	var all_codewords = codewords + ec

	# Create and fill QR matrix
	var matrix = _create_matrix()
	_add_finder_patterns(matrix)
	_add_alignment_patterns(matrix)
	_add_timing_patterns(matrix)
	_add_dark_module(matrix)
	_reserve_format_area(matrix)
	_place_data(matrix, all_codewords)
	_apply_mask(matrix)
	_add_format_info(matrix)

	return _matrix_to_image(matrix, module_size, quiet_zone)

func _select_version(data_length: int) -> int:
	for v in range(1, 7):
		if VERSION_CAPACITY[v] >= data_length + 3:  # +3 for mode and count overhead
			return v
	return 0

func _init_gf_tables():
	_gf_exp.resize(512)
	_gf_log.resize(256)
	var x = 1
	for i in range(255):
		_gf_exp[i] = x
		_gf_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11d
	for i in range(255, 512):
		_gf_exp[i] = _gf_exp[i - 255]

func _gf_mul(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return _gf_exp[(_gf_log[a] + _gf_log[b]) % 255]

func _encode_data(text: String) -> Array:
	var bits = []
	var capacity = VERSION_CAPACITY[_version]

	# Mode indicator (byte mode = 0100)
	bits.append_array([0, 1, 0, 0])

	# Character count (8 bits for version 1-9)
	var count = text.length()
	for i in range(7, -1, -1):
		bits.append((count >> i) & 1)

	# Data bytes
	for c in text.to_utf8_buffer():
		for i in range(7, -1, -1):
			bits.append((c >> i) & 1)

	# Terminator
	var data_bits = capacity * 8
	var terminator = mini(4, data_bits - bits.size())
	for i in range(terminator):
		bits.append(0)

	# Pad to byte boundary
	while bits.size() % 8 != 0:
		bits.append(0)

	# Pad codewords
	var pads = [[1,1,1,0,1,1,0,0], [0,0,0,1,0,0,0,1]]
	var idx = 0
	while bits.size() < data_bits:
		bits.append_array(pads[idx])
		idx = (idx + 1) % 2

	return bits.slice(0, data_bits)

func _bits_to_codewords(bits: Array) -> Array:
	var codewords = []
	for i in range(0, bits.size(), 8):
		var byte = 0
		for j in range(8):
			if i + j < bits.size():
				byte = (byte << 1) | bits[i + j]
		codewords.append(byte)
	return codewords

func _generate_ec(data: Array) -> Array:
	var num_ec = EC_CODEWORDS[_version]
	var gen = _get_generator_poly(num_ec)

	var msg = data.duplicate()
	for i in range(num_ec):
		msg.append(0)

	for i in range(data.size()):
		var coef = msg[i]
		if coef != 0:
			for j in range(gen.size()):
				msg[i + j] ^= _gf_mul(gen[j], coef)

	return msg.slice(data.size())

func _get_generator_poly(degree: int) -> Array:
	var poly = [1]
	for i in range(degree):
		var new_poly = []
		new_poly.resize(poly.size() + 1)
		new_poly.fill(0)
		for j in range(poly.size()):
			new_poly[j] ^= _gf_mul(poly[j], _gf_exp[i])
			new_poly[j + 1] ^= poly[j]
		poly = new_poly
	return poly

func _create_matrix() -> Array:
	var matrix = []
	for y in range(_size):
		var row = []
		row.resize(_size)
		row.fill(-1)
		matrix.append(row)
	return matrix

func _add_finder_patterns(matrix: Array) -> void:
	_draw_finder(matrix, 0, 0)
	_draw_finder(matrix, _size - 7, 0)
	_draw_finder(matrix, 0, _size - 7)

func _draw_finder(matrix: Array, x: int, y: int) -> void:
	for dy in range(-1, 8):
		for dx in range(-1, 8):
			var px = x + dx
			var py = y + dy
			if px < 0 or px >= _size or py < 0 or py >= _size:
				continue

			var in_outer = dx >= 0 and dx <= 6 and dy >= 0 and dy <= 6
			var in_inner = dx >= 1 and dx <= 5 and dy >= 1 and dy <= 5
			var in_core = dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4

			if in_core:
				matrix[py][px] = 1
			elif in_inner:
				matrix[py][px] = 0
			elif in_outer:
				matrix[py][px] = 1
			else:
				matrix[py][px] = 0  # Separator

func _add_alignment_patterns(matrix: Array) -> void:
	var positions = ALIGNMENT_POSITIONS[_version]
	if positions.is_empty():
		return

	for py in positions:
		for px in positions:
			# Skip if overlaps with finder patterns
			if (px <= 8 and py <= 8) or (px <= 8 and py >= _size - 9) or (px >= _size - 9 and py <= 8):
				continue
			_draw_alignment(matrix, px, py)

func _draw_alignment(matrix: Array, cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var dist = maxi(absi(dx), absi(dy))
			matrix[cy + dy][cx + dx] = 1 if (dist == 0 or dist == 2) else 0

func _add_timing_patterns(matrix: Array) -> void:
	for i in range(8, _size - 8):
		var val = (i + 1) % 2
		if matrix[6][i] == -1:
			matrix[6][i] = val
		if matrix[i][6] == -1:
			matrix[i][6] = val

func _add_dark_module(matrix: Array) -> void:
	matrix[_size - 8][8] = 1

func _reserve_format_area(matrix: Array) -> void:
	# Around top-left
	for i in range(9):
		if matrix[8][i] == -1:
			matrix[8][i] = 0
		if matrix[i][8] == -1:
			matrix[i][8] = 0
	# Around top-right
	for i in range(8):
		if matrix[8][_size - 1 - i] == -1:
			matrix[8][_size - 1 - i] = 0
	# Around bottom-left
	for i in range(7):
		if matrix[_size - 1 - i][8] == -1:
			matrix[_size - 1 - i][8] = 0

func _place_data(matrix: Array, codewords: Array) -> void:
	var bits = []
	for cw in codewords:
		for i in range(7, -1, -1):
			bits.append((cw >> i) & 1)

	var bit_idx = 0
	var x = _size - 1
	var upward = true

	while x >= 0:
		if x == 6:
			x -= 1
			continue

		var y_range = range(_size - 1, -1, -1) if upward else range(_size)

		for y in y_range:
			for dx in [0, -1]:
				var cx = x + dx
				if cx >= 0 and matrix[y][cx] == -1:
					if bit_idx < bits.size():
						matrix[y][cx] = bits[bit_idx]
						bit_idx += 1
					else:
						matrix[y][cx] = 0

		x -= 2
		upward = not upward

func _apply_mask(matrix: Array) -> void:
	# Mask 0: (row + col) % 2 == 0
	for y in range(_size):
		for x in range(_size):
			if _is_data_area(x, y) and (x + y) % 2 == 0:
				matrix[y][x] ^= 1

func _is_data_area(x: int, y: int) -> bool:
	# Finder patterns and separators
	if x <= 8 and y <= 8:
		return false
	if x >= _size - 8 and y <= 8:
		return false
	if x <= 8 and y >= _size - 8:
		return false
	# Timing patterns
	if x == 6 or y == 6:
		return false
	# Alignment patterns (for version >= 2)
	if _version >= 2:
		var positions = ALIGNMENT_POSITIONS[_version]
		for py in positions:
			for px in positions:
				if (px <= 8 and py <= 8) or (px <= 8 and py >= _size - 9) or (px >= _size - 9 and py <= 8):
					continue
				if x >= px - 2 and x <= px + 2 and y >= py - 2 and y <= py + 2:
					return false
	return true

func _add_format_info(matrix: Array) -> void:
	# Format info for EC Level L (01) and Mask 0 (000)
	# Data bits: 01000, after BCH and XOR mask: 111011111000100
	var format_bits = [1,1,1,0,1,1,1,1,1,0,0,0,1,0,0]

	# Place first copy around top-left finder
	# Horizontal: bits 0-7 at row 8, columns 0,1,2,3,4,5,7,8 (skip col 6 for timing)
	var pos_h = [0,1,2,3,4,5,7,8]
	for i in range(8):
		matrix[8][pos_h[i]] = format_bits[i]

	# Vertical: bits 8-14 at column 8, rows 7,5,4,3,2,1,0 (skip row 6 for timing)
	var pos_v = [7,5,4,3,2,1,0]
	for i in range(7):
		matrix[pos_v[i]][8] = format_bits[8 + i]

	# Place second copy around top-right and bottom-left finders
	# Horizontal at row 8: bits 0-7 at columns n-1 down to n-8
	for i in range(7):
		matrix[8][_size - 1 - i] = format_bits[i]
	matrix[8][_size - 8] = format_bits[7]

	# Vertical at column 8: bits 8-14 at rows n-7 up to n-1
	for i in range(7):
		matrix[_size - 7 + i][8] = format_bits[8 + i]

func _matrix_to_image(matrix: Array, module_size: int, quiet_zone: int) -> Image:
	var img_size = _size * module_size + quiet_zone * 2
	var img = Image.create(img_size, img_size, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)

	for y in range(_size):
		for x in range(_size):
			if matrix[y][x] == 1:
				var px = quiet_zone + x * module_size
				var py = quiet_zone + y * module_size
				for dy in range(module_size):
					for dx in range(module_size):
						img.set_pixel(px + dx, py + dy, Color.BLACK)

	return img
