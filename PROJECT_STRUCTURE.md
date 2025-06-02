# Project Structure

```
godot-wfc/
├── Main.gd                     # Main application controller
├── Main.tscn                   # Main scene with UI layout
├── project.godot               # Godot project configuration
├── icon.svg                    # Project icon
├── README.md                   # Project documentation
├── PROJECT_STRUCTURE.md        # This file
│
├── addons/wfc/                 # WFC addon structure
│   ├── ui/                     # UI components
│   │   ├── MapDisplay.gd       # Main map visualization
│   │   ├── MapCursor.gd        # Cursor control and animation
│   │   ├── ProbabilityPalette.gd  # Tile probability display
│   │   ├── TileProbabilityDialog.gd  # Probability editing dialog
│   │   ├── TileProbabilityDialog.tscn
│   │   ├── TileMatchesDialog.gd     # Tile adjacency viewer
│   │   └── TileMatchesDialog.tscn
│   │
│   ├── core/                   # WFC algorithm (to be implemented)
│   │   ├── WFC.gd             # Main WFC algorithm class
│   │   ├── TilesetData.gd     # Tileset resource class
│   │   └── MapGenerator.gd    # High-level generation interface
│   │
│   └── utils/                  # Utility classes (to be implemented)
│       ├── TilesetConverter.gd # PNG to tileset converter
│       ├── PickleImporter.gd  # Python pickle file importer
│       └── AdjacencyAnalyzer.gd # Tile adjacency rule extraction
│
├── theme/                      # UI theming
│   └── wfc_theme.tres         # Custom dark theme
│
└── data/                       # Tileset data
    ├── README.md              # Data folder documentation
    └── (tileset .tres files)  # Processed tileset resources
```

## File Responsibilities

### Main Application
- **Main.gd**: Central controller, handles UI events and coordinates between components
- **Main.tscn**: Root scene with complete UI layout

### UI Components
- **MapDisplay.gd**: Handles tile rendering, camera controls, and user interaction
- **MapCursor.gd**: Animated cursor with position tracking and selection
- **ProbabilityPalette.gd**: Displays possible tiles and probabilities at cursor position
- **TileProbabilityDialog.gd**: Modal for editing individual tile probabilities
- **TileMatchesDialog.gd**: Shows which tiles can connect to selected tile

### Core Algorithm (Future)
- **WFC.gd**: Main Wave Function Collapse implementation
- **TilesetData.gd**: Resource class for storing tile data and rules
- **MapGenerator.gd**: High-level interface for map generation

### Utilities (Future)
- **TilesetConverter.gd**: Converts PNG images to tileset resources
- **PickleImporter.gd**: Imports Python pickle files from original project
- **AdjacencyAnalyzer.gd**: Analyzes tile patterns to create adjacency rules

### Resources
- **wfc_theme.tres**: Custom UI theme with dark colors and modern styling
- **TilesetData resources**: Processed tileset data in Godot format

## Signal Flow

```
User Input → Main.gd → MapDisplay.gd → UI Updates
                    ↓
            ProbabilityPalette.gd
                    ↓
            Status Updates → UI Labels
```

## Implementation Status

- ✅ Complete UI framework
- ✅ User interaction system
- ✅ Visual components and theming
- ⏳ WFC algorithm (pending)
- ⏳ Data pipeline (pending)
- ⏳ Tileset conversion (pending)