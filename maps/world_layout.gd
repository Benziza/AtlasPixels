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
