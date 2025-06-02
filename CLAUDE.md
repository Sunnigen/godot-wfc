# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Wave Function Collapse (WFC) implementation in Godot 4.3+ that recreates a Python/Kivy WFC map generator. The project generates tile-based maps using the WFC algorithm based on tileset patterns and adjacency rules.

## Commands

### Running the Project
```bash
# Open project in Godot 4.3+
godot --path . --editor
# Or run directly
godot --path . Main.tscn
```

### Project Requirements
- Godot 4.3+ engine
- No external dependencies required

## Architecture

### Core Components

1. **Main Application (`Main.gd`)**:
   - Central controller coordinating all UI components
   - Handles user input events and keyboard shortcuts
   - Manages map generation settings (size, tileset, generation mode)
   - Default map size: 14x14, tile size: 16px, display size: 32px

2. **WFC Algorithm (`addons/wfc/core/WFC.gd`)**:
   - Core Wave Function Collapse implementation using entropy-based tile selection
   - Manages tile placement, probability propagation, and contradiction detection
   - Tracks undecided positions and calculates lowest entropy locations
   - Emits signals for tile placement, generation completion, and errors

3. **TilesetData Resource (`addons/wfc/core/TilesetData.gd`)**:
   - Godot Resource class storing tile textures, adjacency rules, and probabilities
   - Uses Direction enum: SOUTH=0, EAST=1, NORTH=2, WEST=3
   - Manages tile-to-tile connection rules in each cardinal direction
   - Includes base probability weights for tile placement

4. **UI Components**:
   - **MapDisplay.gd**: Sprite2D-based tile visualization with camera controls (zoom 1x-20x, pan)
   - **MapCursor.gd**: Animated cursor with position tracking and tile selection
   - **ProbabilityPalette.gd**: Scrollable list showing possible tiles and probabilities at cursor
   - **TileProbabilityDialog.gd**: Modal for editing individual tile probability weights
   - **TileMatchesDialog.gd**: Visualization of tile adjacency rules

### Key Data Structures

- **tile_array**: 2D Array storing placed tile IDs (0 = undecided)
- **probability_array**: 2D Array of Dictionaries mapping tile_id -> probability
- **adjacency_rules**: Dictionary mapping tile_id -> Array[Array] for [S,E,N,W] valid neighbors
- **undecided_positions**: Array[Vector2i] tracking tiles still to be decided
- **lowest_entropy**: Array tracking position and entropy value for next tile placement

### Input Controls

- **Space**: Toggle continuous generation mode
- **1**: Generate one tile step
- **5**: Generate five tile steps  
- **R**: Reset map to blank state
- **WASD/Arrow Keys**: Move cursor around map
- **Mouse Wheel**: Zoom in/out (1x to 20x)
- **Double-click**: Select tile and show information dialogs

## Implementation Status

- ✅ **Phase 1 Complete**: Full UI framework with all components functional
- ⚠️ **Phase 2 In Progress**: WFC algorithm implementation
  - TilesetData resource class partially implemented
  - Basic WFC structure in place but core generation logic pending
  - UI integration points established but not fully connected

## Important Implementation Details

### WFC Algorithm Flow
1. Initialize probability arrays with all possible tiles
2. Find position with lowest entropy (fewest possible tiles)
3. Select and place tile based on weighted probability
4. Propagate constraints to neighboring positions
5. Update entropy calculations and repeat until complete or contradiction

### Signal Architecture
```
User Input → Main.gd → MapDisplay/WFC → UI Updates
                    ↓
            ProbabilityPalette ← probabilities_changed
                    ↓
            Status Updates → Labels/Dialogs
```

### File Naming Conventions
- Core algorithm files: `addons/wfc/core/`
- UI components: `addons/wfc/ui/`
- Utility classes: `addons/wfc/utils/`
- Resource files: `.tres` extension for Godot resources
- Scene files: `.tscn` extension for UI layouts

### Development Patterns
- Use RefCounted for algorithm classes, Resource for data classes
- Emit signals for loose coupling between components
- Store tileset data as Godot Resources (.tres files)
- Follow Godot naming conventions (snake_case for variables/functions)
- Use typed arrays where possible: `Array[Vector2i]`, `Array[Dictionary]`