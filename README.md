# AtlasPixels

The goal is to create a top-down pixel art game inspired by Stardew Valley, with a Moroccan setting and culture.

To preview the douar locally with Godot 4.7, run:

```sh
godot --path . --script res://tools/preview_douar.gd
```

The preview uses the normal follow camera and its 2× gameplay zoom. On first launch it opens the douar with a copy of your farm save; subsequent launches resume the preview's own progress in `.godot/qa/interactive-village-save.json`.
