#!/usr/bin/env python3
"""
Extract adjacency rules from the original Python flowers.pickle file
and convert them to Godot .tres format for testing.
"""

import pickle
import sys
import json

def load_pickle_data(pickle_path):
    """Load the pickle data and extract components"""
    print(f"Loading pickle file: {pickle_path}")
    
    # The pickle might contain multiple objects, let's load them all
    objects = []
    with open(pickle_path, 'rb') as f:
        try:
            while True:
                obj = pickle.load(f)
                objects.append(obj)
                print(f"Loaded object {len(objects)}: {type(obj)}")
        except EOFError:
            pass
    
    print(f"Total objects loaded: {len(objects)}")
    
    for i, obj in enumerate(objects):
        print(f"\nObject {i}: {type(obj)}")
        if isinstance(obj, dict):
            print(f"  Keys: {list(obj.keys())[:10]}...")  # Show first 10 keys
            print(f"  Total keys: {len(obj.keys())}")
            
            # Sample a few key-value pairs
            for j, (key, value) in enumerate(list(obj.items())[:3]):
                print(f"    Sample {j}: {key} -> {type(value)}")
                if hasattr(value, '__len__') and len(value) <= 10:
                    print(f"      Value: {value}")
                elif hasattr(value, '__len__'):
                    print(f"      Value length: {len(value)}")
        elif hasattr(obj, '__len__'):
            print(f"  Length: {len(obj)}")
            if len(obj) <= 10:
                print(f"  Content: {obj}")
        else:
            print(f"  Value: {obj}")
    
    return objects

def extract_adjacency_rules(objects):
    """Extract adjacency rules from pickle data structure"""
    
    # Look through all loaded objects for adjacency rules
    for i, obj in enumerate(objects):
        print(f"\nAnalyzing object {i} for adjacency rules...")
        
        if isinstance(obj, dict):
            # Look for tile IDs as keys
            sample_keys = list(obj.keys())[:5]
            print(f"Sample keys: {sample_keys}")
            
            # Check if this looks like adjacency data
            for key in sample_keys:
                value = obj[key]
                print(f"Key {key}: {type(value)}")
                
                if hasattr(value, '__len__') and len(value) == 4:
                    print(f"  Found 4-element structure for key {key}")
                    
                    # Check if each element is a list/set of neighbors
                    all_directions_valid = True
                    for direction_idx, direction_data in enumerate(value):
                        if hasattr(direction_data, '__iter__') and not isinstance(direction_data, str):
                            neighbors = list(direction_data)
                            print(f"    Direction {direction_idx}: {len(neighbors)} neighbors")
                            if len(neighbors) > 0:
                                print(f"      Sample neighbors: {neighbors[:5]}")
                        else:
                            print(f"    Direction {direction_idx}: Not iterable - {direction_data}")
                            all_directions_valid = False
                    
                    if all_directions_valid:
                        print(f"  ✅ Object {i} looks like adjacency rules!")
                        return convert_adjacency_dict(obj)
            
        print(f"  ❌ Object {i} doesn't look like adjacency rules")
    
    print("Could not find adjacency rules in any object")
    return None

def convert_adjacency_dict(adjacency_dict):
    """Convert the adjacency dictionary to our format"""
    converted_rules = {}
    
    print(f"\nConverting adjacency rules for {len(adjacency_dict)} tiles...")
    
    for tile_id, directions in adjacency_dict.items():
        print(f"Tile {tile_id}:")
        
        if hasattr(directions, '__len__') and len(directions) == 4:
            converted_directions = []
            
            for direction_idx, neighbors in enumerate(directions):
                direction_names = ["North", "East", "South", "West"]
                
                if hasattr(neighbors, '__iter__') and not isinstance(neighbors, str):
                    # Convert set to sorted list
                    neighbor_list = sorted(list(neighbors))
                    print(f"  {direction_names[direction_idx]}: {neighbor_list}")
                    converted_directions.append(neighbor_list)
                else:
                    print(f"  {direction_names[direction_idx]}: {neighbors} (not iterable)")
                    converted_directions.append([])
            
            converted_rules[tile_id] = converted_directions
        else:
            print(f"  ❌ Unexpected structure: {directions}")
    
    return converted_rules

def format_for_godot_tres(adjacency_rules):
    """Format adjacency rules for Godot .tres file"""
    
    # Build the adjacency_rules section for .tres file
    tres_lines = ["adjacency_rules = {"]
    
    # Sort tile IDs for consistent output
    for tile_id in sorted(adjacency_rules.keys()):
        directions = adjacency_rules[tile_id]
        
        # Format as: tile_id: [[north], [east], [south], [west]]
        direction_strs = []
        for direction in directions:
            # Convert neighbor list to string format
            neighbor_str = "[" + ", ".join(map(str, sorted(direction))) + "]"
            direction_strs.append(neighbor_str)
        
        line = f"{tile_id}: [{', '.join(direction_strs)}],"
        tres_lines.append(line)
    
    tres_lines.append("}")
    
    return "\n".join(tres_lines)

def main():
    pickle_path = "/Users/sunnigen/Godot/kivy-wfc-master/data/flowers.pickle"
    
    try:
        # Load and analyze the pickle file
        pickle_data = load_pickle_data(pickle_path)
        
        print("\n" + "="*50)
        print("DETAILED STRUCTURE ANALYSIS")
        print("="*50)
        
        # Deep analysis of structure
        if isinstance(pickle_data, tuple):
            for i, item in enumerate(pickle_data):
                print(f"\nTuple item {i}:")
                print(f"  Type: {type(item)}")
                
                if isinstance(item, dict):
                    print(f"  Keys: {list(item.keys())}")
                    # Sample first few items
                    for j, (key, value) in enumerate(list(item.items())[:3]):
                        print(f"    {key}: {type(value)} - {value if j < 2 else '...'}")
                elif hasattr(item, '__len__'):
                    print(f"  Length: {len(item)}")
                    if len(item) > 0:
                        print(f"  Sample: {item if len(str(item)) < 200 else str(item)[:200] + '...'}")
        
        print("\n" + "="*50)
        print("EXTRACTING ADJACENCY RULES")
        print("="*50)
        
        # Extract adjacency rules
        adjacency_rules = extract_adjacency_rules(pickle_data)
        
        if adjacency_rules:
            print(f"\nSuccessfully extracted {len(adjacency_rules)} tile adjacency rules!")
            
            # Show sample of extracted rules
            print("\nSample adjacency rules:")
            for tile_id in sorted(list(adjacency_rules.keys())[:5]):
                print(f"Tile {tile_id}: {adjacency_rules[tile_id]}")
            
            # Generate Godot .tres format
            print("\n" + "="*50)
            print("GENERATING GODOT FORMAT")
            print("="*50)
            
            tres_format = format_for_godot_tres(adjacency_rules)
            
            # Save to file
            output_path = "/Users/sunnigen/Godot/kivy-wfc-master/godot-wfc/imported_adjacency_rules.tres"
            with open(output_path, 'w') as f:
                f.write(tres_format)
            
            print(f"Saved adjacency rules to: {output_path}")
            
            # Also save as JSON for easier inspection
            json_path = "/Users/sunnigen/Godot/kivy-wfc-master/godot-wfc/imported_adjacency_rules.json"
            with open(json_path, 'w') as f:
                json.dump(adjacency_rules, f, indent=2)
            
            print(f"Saved adjacency rules as JSON to: {json_path}")
            
            # Show preview of output
            print(f"\nPreview of .tres format:")
            print(tres_format[:500] + "..." if len(tres_format) > 500 else tres_format)
            
        else:
            print("Failed to extract adjacency rules")
            return 1
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())