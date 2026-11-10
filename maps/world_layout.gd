extends RefCounted
## Shared dimensions for collision, camera limits and save validation.
const TILE_SIZE := 32
const ORIGINAL_FARM_SIZE := Vector2i(1280, 896)
const FARM_SIZE := Vector2i(1536, 896)
const SQUARE_SIZE := Vector2i(1280, 896)
const FARM_EXIT := Rect2(1488, 352, 48, 96)
const SQUARE_EXIT := Rect2(0, 448, 48, 96)
const SQUARE_SPAWN := Vector2(112, 496)
const FARM_RETURN := Vector2(1440, 416)
const CAFE_SIZE := Vector2i(640, 448)
const CAFE_SPAWN := Vector2(320, 384)
const CAFE_EXIT := Rect2(288, 420, 64, 28)
# The doorway is on the left side of the cafe's facade, not its center.
const CAFE_DOOR := Vector2(964, 768)
const CAFE_RETURN := Vector2(964, 792)

static func area_size(area: String) -> Vector2i:
	match area:
		"farm": return FARM_SIZE
		"douar": return SQUARE_SIZE
		"cafe": return CAFE_SIZE
	return Vector2i.ZERO
