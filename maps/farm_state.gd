extends RefCounted
## Farming rules and versioned save data, independent of rendering and input.
const START_MINUTE := 6 * 60
const END_MINUTE := 26 * 60
const SECONDS_PER_TICK := 7.0
const CAN_CAPACITY := 40
const CROPS := {
	"mint": {"name": "Mint", "days": 4, "stages": [0, 1, 2, 4], "regrow": 0, "seed_price": 5, "price": 15},
	"tomato": {"name": "Tomato", "days": 11, "stages": [0, 3, 7, 11], "regrow": 4, "seed_price": 10, "price": 35}
}
var beds: Dictionary = {}
var day := 1
var minute := START_MINUTE
var tick_seconds := 0.0
var water := CAN_CAPACITY
var coins := 100
var inventory := {"mint_seed": 20, "tomato_seed": 20, "mint": 0, "tomato": 0}
var selected_tool := 0
var player_position := Vector2(864, 352)

static func empty_bed() -> Dictionary:
	return {"crop": "", "growth": 0, "watered": false, "regrow": -1}

func initialize(initial_beds: Dictionary) -> void:
	beds = initial_beds.duplicate(true)

func is_ready(cell: Vector2i) -> bool:
	if not beds.has(cell) or beds[cell].crop == "":
		return false
	var bed: Dictionary = beds[cell]
	return bed.regrow == 0 or (bed.regrow == -1 and bed.growth >= CROPS[bed.crop].days)

func stage(cell: Vector2i) -> int:
	var bed: Dictionary = beds[cell]
	if bed.crop == "":
		return -1
	if is_ready(cell):
		return 3
	if bed.regrow > 0:
		return 2
	var thresholds: Array = CROPS[bed.crop].stages
	return 2 if bed.growth >= thresholds[2] else (1 if bed.growth >= thresholds[1] else 0)

func plant(cell: Vector2i, crop: String) -> String:
	if not beds.has(cell):
		return "Plant in a prepared brown bed."
	if not CROPS.has(crop):
		return "Choose a seed first."
	if beds[cell].crop != "":
		return "There is already a crop here."
	if inventory[crop + "_seed"] <= 0:
		return "No seeds left. Visit the hanout."
	inventory[crop + "_seed"] -= 1
	beds[cell].crop = crop
	beds[cell].growth = 0
	beds[cell].regrow = -1
	return ""

func water_bed(cell: Vector2i) -> String:
	if not beds.has(cell):
		return "Water a prepared bed, or refill at the well / saqya."
	if beds[cell].watered:
		return "Already watered today."
	if is_ready(cell):
		return "Ready to harvest! Pick it first."
	if water <= 0:
		return "The can is empty. Refill at the well or saqya."
	water -= 1
	beds[cell].watered = true
	return ""

func harvest(cell: Vector2i) -> String:
	if not is_ready(cell):
		return "This crop is not ready yet."
	var bed: Dictionary = beds[cell]
	var crop: String = bed.crop
	inventory[crop] += 1
	if CROPS[crop].regrow > 0:
		bed.regrow = CROPS[crop].regrow
	else:
		bed.crop = ""
		bed.growth = 0
		bed.regrow = -1
	return ""

func refill() -> void:
	water = CAN_CAPACITY

func buy_seeds(crop: String) -> String:
	if not CROPS.has(crop):
		return "Unknown seed."
	var cost: int = CROPS[crop].seed_price * 5
	if coins < cost:
		return "Not enough coins. Sell some of your harvest."
	coins -= cost
	inventory[crop + "_seed"] += 5
	return ""

func sell_harvest() -> int:
	var total := 0
	for crop: String in CROPS:
		total += inventory[crop] * CROPS[crop].price
		inventory[crop] = 0
	coins += total
	return total

func advance_time(seconds: float) -> bool:
	tick_seconds += maxf(seconds, 0.0)
	while tick_seconds >= SECONDS_PER_TICK and minute < END_MINUTE:
		tick_seconds -= SECONDS_PER_TICK
		minute += 10
	if minute >= END_MINUTE:
		tick_seconds = 0.0
	return minute >= END_MINUTE

func next_day() -> Dictionary:
	var grown := 0
	var missed := 0
	for cell: Vector2i in beds:
		var bed: Dictionary = beds[cell]
		if bed.crop != "" and not is_ready(cell):
			if bed.watered:
				if bed.regrow > 0:
					bed.regrow -= 1
				else:
					bed.growth += 1
				grown += 1
			else:
				missed += 1
		bed.watered = false
	day += 1
	minute = START_MINUTE
	tick_seconds = 0.0
	return {"grown": grown, "missed": missed}

func clock_text() -> String:
	return "%02d:%02d" % [(minute / 60) % 24, minute % 60]

func describe(cell: Vector2i) -> String:
	if not beds.has(cell):
		return ""
	var bed: Dictionary = beds[cell]
	var moisture := "Watered" if bed.watered else "Dry"
	if bed.crop == "":
		return "Empty bed  /  %s" % moisture
	var crop_name: String = CROPS[bed.crop].name
	if is_ready(cell):
		return "%s  /  Ready to harvest (E)" % crop_name
	if bed.regrow > 0:
		return "%s  /  Regrows in %d watered nights  /  %s" % [crop_name, bed.regrow, moisture]
	return "%s  /  %d of %d nights  /  %s" % [crop_name, bed.growth, CROPS[bed.crop].days, moisture]

func to_data() -> Dictionary:
	var records: Array = []
	for cell: Vector2i in beds:
		var record: Dictionary = beds[cell].duplicate()
		record["x"] = cell.x
		record["y"] = cell.y
		records.append(record)
	return {"version": 1, "day": day, "minute": minute, "tick_seconds": tick_seconds,
		"water": water, "coins": coins, "inventory": inventory.duplicate(), "selected_tool": selected_tool,
		"player": [player_position.x, player_position.y], "beds": records}

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

func restore(data: Variant) -> bool:
	# Validate everything before mutating live state. A bad file cannot partially load.
	if not data is Dictionary or data.get("version") != 1:
		return false
	for spec in [["day", 1, 1000000], ["minute", START_MINUTE, END_MINUTE], ["water", 0, CAN_CAPACITY], ["coins", 0, 100000000], ["selected_tool", 0, 3]]:
		if not whole(data.get(spec[0]), spec[1], spec[2]):
			return false
	if int(data.minute) % 10 != 0:
		return false
	var ticks: Variant = data.get("tick_seconds")
	if not (ticks is int or ticks is float) or not is_finite(float(ticks)) or ticks < 0 or ticks >= SECONDS_PER_TICK:
		return false
	var saved_inventory: Variant = data.get("inventory")
	if not saved_inventory is Dictionary:
		return false
	var restored_inventory: Dictionary = {}
	for key: String in inventory:
		if not whole(saved_inventory.get(key), 0, 1000000):
			return false
		restored_inventory[key] = int(saved_inventory[key])
	var pos: Variant = data.get("player")
	if not pos is Array or pos.size() != 2:
		return false
	for value: Variant in pos:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	if pos[0] < 8 or pos[0] > 1272 or pos[1] < 16 or pos[1] > 896:
		return false
	var records: Variant = data.get("beds")
	if not records is Array or records.size() != beds.size():
		return false
	var restored: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary or not whole(record.get("x"), 0, 39) or not whole(record.get("y"), 0, 27):
			return false
		var cell := Vector2i(int(record.x), int(record.y))
		if not beds.has(cell) or restored.has(cell) or not record.get("watered") is bool:
			return false
		var crop: Variant = record.get("crop")
		if not crop is String or (crop != "" and not CROPS.has(crop)):
			return false
		var max_age: int = 0 if crop == "" else CROPS[crop].days
		var max_regrow: int = -1 if crop != "tomato" else CROPS.tomato.regrow
		if not whole(record.get("growth"), 0, max_age) or not whole(record.get("regrow"), -1, max_regrow):
			return false
		if record.regrow >= 0 and record.growth != max_age:
			return false
		restored[cell] = {"crop": crop, "growth": int(record.growth), "watered": record.watered, "regrow": int(record.regrow)}
	beds = restored
	day = int(data.day)
	minute = int(data.minute)
	tick_seconds = float(ticks)
	water = int(data.water)
	coins = int(data.coins)
	inventory = restored_inventory
	selected_tool = int(data.selected_tool)
	player_position = Vector2(float(pos[0]), float(pos[1]))
	return true

func save_file(path: String) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_data()))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return restore(JSON.parse_string(FileAccess.get_file_as_string(path)))
