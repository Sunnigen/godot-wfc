# WFC Tileset Data

This folder contains all tileset-related data for the Wave Function Collapse implementation.

## 📁 Folder Structure

### `input_maps/`
**Store your source tilemap PNG files here**
- Generated maps from original WFC implementation
- Example maps for analysis
- Any tilemap images you want to analyze

```
input_maps/
├── flowers_map.png      # Your tilemap PNG files
├── dungeon_map.png
└── grass_terrain.png
```

### `generated_tilesets/`
**Auto-generated .tres tileset files**
- Created by the "Analyze Tilemap" tool
- Ready-to-use TilesetData resources
- Contains tiles + adjacency rules

```
generated_tilesets/
├── flowers.tres         # Generated from flowers_map.png
├── dungeon.tres         # Generated from dungeon_map.png
└── grass.tres
```

### `extracted_tiles/`
**Individual tile images (auto-generated)**
- PNG files for each unique tile found
- Organized by tileset name
- Used for debugging and reference

```
extracted_tiles/
├── flowers/
│   ├── tile_01.png
│   ├── tile_02.png
│   └── ...
└── dungeon/
    ├── tile_01.png
    └── ...
```

## 🔄 Workflow

1. **Place your tilemap PNG** → `input_maps/`
2. **Click "Analyze Tilemap"** → Select from input_maps/
3. **Generated tileset** → Saved to `generated_tilesets/`
4. **Individual tiles** → Extracted to `extracted_tiles/`
5. **Load tileset** → Use "Load Tileset" button

## 📋 Supported Formats

- **Input**: PNG images (any size, grid-based tiles)
- **Output**: Godot .tres resource files
- **Tile sizes**: 8x8 to 128x128 pixels
- **Grid-based**: No spacing between tiles

## 🎯 Next Steps

1. Place your tilemap PNG files in `input_maps/`
2. Use the "Analyze Tilemap" dialog to process them
3. Generated tilesets will be available in "Load Tileset"