# WFC Development Plan - Phase 2

## 🎯 Phase 2A: Core Implementation (Priority 1)

### Task 1: TilesetData Resource Class
**Estimated Time**: 2-3 hours
**Files to Create**: 
- `addons/wfc/core/TilesetData.gd`
- `addons/wfc/core/TilesetData.tres` (example)

**Implementation Details**:
```gdscript
class_name TilesetData extends Resource

@export var tile_size: int = 16
@export var tile_textures: Dictionary = {}  # tile_id -> Texture2D
@export var adjacency_rules: Dictionary = {}  # tile_id -> [south, east, north, west] sets
@export var base_probabilities: Dictionary = {}  # tile_id -> [s_prob, e_prob, n_prob, w_prob]
```

**Acceptance Criteria**:
- [ ] Can store tile textures
- [ ] Can define adjacency rules for each direction
- [ ] Can save/load as .tres file
- [ ] Has validation methods

### Task 2: Basic WFC Algorithm
**Estimated Time**: 4-5 hours
**Files to Create**:
- `addons/wfc/core/WFC.gd`

**Key Methods**:
- `initialize(width, height, tileset_data)`
- `find_lowest_entropy() -> Vector2i`
- `place_tile(pos, tile_id)`
- `update_probabilities(pos)`
- `generate_step() -> bool`

**Acceptance Criteria**:
- [ ] Can initialize empty map
- [ ] Can calculate entropy at each position
- [ ] Can place tiles and update constraints
- [ ] Returns true/false for generation success

### Task 3: UI Integration
**Estimated Time**: 2-3 hours
**Files to Modify**:
- `Main.gd`
- `MapDisplay.gd`

**Integration Points**:
- Connect generate buttons to WFC
- Display real tiles from WFC algorithm
- Show actual entropy in status bar
- Update probability palette with real data

**Acceptance Criteria**:
- [ ] Buttons trigger real WFC generation
- [ ] Map shows actual tile placement
- [ ] Status shows real entropy values
- [ ] Palette shows real probabilities

## 🔧 Phase 2B: Algorithm Polish (Priority 2)

### Task 4: Full Constraint Propagation
**Estimated Time**: 3-4 hours

**Features**:
- Update entire map when tile placed
- Optimize for performance (avoid redundant calculations)
- Handle edge cases (map boundaries)

### Task 5: Contradiction Handling
**Estimated Time**: 2-3 hours

**Features**:
- Detect when no valid tiles exist
- Implement simple restart mechanism
- Show user feedback for failures
- Add option for backtracking (future)

## 📋 Implementation Order

### Week 1 Goals:
1. ✅ **Day 1-2**: Complete UI (DONE!)
2. **Day 3**: TilesetData resource class
3. **Day 4-5**: Basic WFC algorithm
4. **Day 6**: UI integration
5. **Day 7**: Testing and fixes

### Week 2 Goals:
1. **Day 1-2**: Full constraint propagation
2. **Day 3**: Contradiction handling
3. **Day 4-5**: Create test tilesets manually
4. **Day 6-7**: Performance testing and optimization

## 🧪 Testing Strategy

### Unit Tests:
- TilesetData loading/saving
- WFC entropy calculations
- Constraint propagation logic
- Tile placement validation

### Integration Tests:
- Full generation cycle (5x5 map)
- UI responsiveness during generation
- Error handling for edge cases

### Performance Tests:
- 50x50 map generation time
- Memory usage monitoring
- UI responsiveness during large generations

## 💡 Implementation Tips

### For TilesetData:
- Start with hardcoded simple tileset (4 tiles)
- Use enum for directions: `enum Direction { SOUTH, EAST, NORTH, WEST }`
- Validate adjacency rules are symmetric

### For WFC Algorithm:
- Use `PackedInt32Array` for tile_array (performance)
- Use `Array[Dictionary]` for probabilities (flexibility)
- Implement entropy caching to avoid recalculation

### For UI Integration:
- Use signals for loose coupling
- Update UI on timer (not every tile placement)
- Show progress for large generations

## 🚀 Quick Start for Phase 2

To begin Phase 2, start with:

1. **Create TilesetData.gd** with basic structure
2. **Create a 2x2 test tileset** (4 tiles, simple rules)
3. **Implement WFC.initialize()** method
4. **Test with 5x5 map** to validate core logic

This approach ensures early wins and validates the architecture before building complexity.

## 🎯 Success Criteria for Phase 2A

Phase 2A is complete! ✅
- [✅] Can generate a 5x5 map with 4-tile set
- [✅] UI buttons trigger real generation
- [✅] Entropy display shows real values
- [✅] No crashes or infinite loops
- [✅] Basic contradiction detection works
- [✅] Generation completes in <1 second for 10x10 map

**Phase 2A Complete! Ready for Phase 2B optimization! 🎉**