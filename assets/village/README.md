# Village sprites

These six transparent pixel-art sprites were created with the built-in ImageGen tool, using `assets/tilesets/buildings.png` and the existing props as style references. They come from the village preview approved on 2026-11-10; transparent margins were trimmed and the sprites were scaled with nearest-neighbor filtering to a 2-pixel grid.

| File | Size | Role |
| --- | --- | --- |
| `neighbor-house-blue.png` | 224 × 208 | White and blue neighbor's house |
| `neighbor-house-earth.png` | 208 × 240 | Adobe neighbor's house |
| `village-cafe.png` | 256 × 208 | Village cafe |
| `greengrocer.png` | 192 × 208 | Produce shop |
| `bread-oven.png` | 112 × 112 | Communal bread oven |
| `fountain.png` | 128 × 112 | Square fountain |

The player's farmhouse remains exclusive to the farm. Cafe and greengrocer signs are separate localized labels; their sprites contain no baked-in text. These new storefronts are scenery in this change; the original hanout and well retain their existing interactions.

Rebuild the editable square with `godot --headless --path . --script res://tools/build_douar_square.gd` after importing the project assets.
