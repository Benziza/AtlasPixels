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
const CIVIC_SIZE := Vector2i(1024, 768)
const SQUARE_NORTH_EXIT := Rect2(608, 0, 96, 48)
const SQUARE_NORTH_RETURN := Vector2(656, 112)
const CIVIC_EXIT := Rect2(464, 720, 96, 48)
const CIVIC_SPAWN := Vector2(512, 656)
const CIVIC_INTERIOR_SIZE := Vector2i(640, 448)
const CIVIC_INTERIOR_SPAWN := Vector2(320, 384)
const CIVIC_INTERIOR_EXIT := Rect2(288, 420, 64, 28)
const CAIDAT_RETURN := Vector2(272, 432)
const HOSPITAL_RETURN := Vector2(752, 432)

static func is_interior(area: String) -> bool:
	return area in ["cafe", "caidat", "hospital"]

static func area_size(area: String) -> Vector2i:
	match area:
		"farm": return FARM_SIZE
		"douar": return SQUARE_SIZE
		"cafe": return CAFE_SIZE
		"civic": return CIVIC_SIZE
		"caidat", "hospital": return CIVIC_INTERIOR_SIZE
	return Vector2i.ZERO
