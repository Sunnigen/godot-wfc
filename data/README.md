# WFC Tileset Data

This folder will contain processed tileset data files in Godot's native resource format.

## File Structure

- `*.tres` - Tileset resource files containing:
  - Tile textures
  - Adjacency rules
  - Base probability data

## Converting from Python Pickle Files

To convert existing pickle files from the Python version:

1. Copy pickle files from the original project's `data/` folder
2. Use the tileset conversion utility (to be implemented)
3. Processed files will be saved here as `.tres` resources

## Example Tilesets

The original project includes these tilesets:
- `flowers.pickle` - Simple flower patterns
- `grass.pickle` - Grass terrain tiles
- `fe_*.pickle` - Fire Emblem game tiles
- `dungeon_simple.pickle` - Simple dungeon layouts

These will be converted to Godot format during implementation.