# AtlasPixels

The goal is to create a top-down pixel art game inspired by Stardew Valley, with a Moroccan setting and culture.

Open `project.godot` in Godot 4.7 and press **F5**. Move with the **arrow keys** or **WASD** (ZQSD on AZERTY).

- **1 / 2:** mint / tomato seeds. **3:** watering can. **4:** harvest. Click a nearby bed or press **Space** to use the selected tool in front of you.
- **E:** harvest, refill at the well or saqya, shop at the hanout, or sleep at your front door. **Esc:** pause / save / new farm.
- Start planting in the empty nursery left of the house. Each watered night advances growth; a missed watering pauses it. Soil dries each morning. Mint takes **4 nights** and clears after harvest; tomatoes take **11**, then regrow every **4** watered nights.
- Days run **06:00–02:00**, with 10 game minutes per 7 real seconds. Sleep to advance early; at 02:00 you return home automatically. Menus and an inactive window pause time.
- Harvest goes into your basket. Sell it and buy more seeds at the hanout. Progress saves after actions, overnight, every 30 seconds and on normal exit to `user://farm-save.json`.

This first farming loop uses the existing prepared beds. Seasons, rain, energy and tool upgrades are not implemented. Mint growth and shop prices are custom balancing; tomato timing and the daily watering / clock rules follow the [crop](https://stardewvalleywiki.com/Crops), [tomato](https://stardewvalleywiki.com/Tomato), [watering](https://stardewvalleywiki.com/Watering_Cans) and [day cycle](https://stardewvalleywiki.com/Day_Cycle) references.

- `assets/`: current artwork, tilesets and animation resources.
- `characters/`: farmer scene and player controller.
- `maps/`: editable map, playable scene, farming state and interface.
- `tools/`: resource builders and regression checks.

To rebuild, run `build_character.gd`, `build_resources.gd`, import in Godot, then run `build_playable_map.gd` using `godot --headless --path . --script res://tools/<script>`. Rebuilding replaces generated resources and maps.

Run checks with `godot --headless --path . --fixed-fps 60 --script res://tools/test_playable_map.gd` and the same command with `test_farming.gd`. Tests use an isolated save under `.godot/qa/`, never your farm save.

Source artwork is in `assets/source/`. Godot manages the ignored `.godot/` cache automatically.
The pixel HUD uses original inventory icons and [Pixelify Sans](https://github.com/google/fonts/tree/main/ofl/pixelifysans); its font license is included in `assets/ui/OFL.txt`. Hover a slot for help; the first four are tools and the next two show harvested produce.
