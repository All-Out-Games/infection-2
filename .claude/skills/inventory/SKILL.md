---
name: inventory
description: "Inventory system documentation. Reference this only when working with items and inventories."
---
# CSL Inventory System

The inventory system provides a complete item management solution with support for item definitions, instances, storage, and UI.

## Core Concepts

1. **Item_Definition** - A template that defines what an item IS (name, icon, stack size, custom properties)
2. **Item_Instance** - An actual item in the game world/inventory (has a count, can be moved around)
3. **Inventory** - A container that holds item instances in slots
4. **default_inventory** - Every Player has a built-in inventory accessible via `player.default_inventory`

## Creating Custom Item Types

You can extend `Item_Definition` and `Item_Instance` to add custom properties:

```csl
// Custom definition with extra properties
Weapon_Definition :: class : Item_Definition {
    damage: int;
    fire_rate: float;
    description: string;
}

// Custom instance with per-item data
Weapon_Item :: class : Item_Instance {
    // Add @ao_serialize for data that should be saved/loaded
    durability: int @ao_serialize;
    kills: int @ao_serialize;
}
```

## Registering Item Definitions

Register item definitions in `ao_before_scene_load`. Use the `Items.create_item_definition` helper:

```csl
// Global storage for definitions
all_weapon_definitions: [..]Item_Definition;

ao_before_scene_load :: proc() {
    // Create item definitions
    // Arguments: {id, name, icon_path, stack_size, definition_type, instance_type}
    sword_defn := create_item_definition(
        {"sword", "Iron Sword", "icons/sword.png", 1, Weapon_Definition, Weapon_Item},
        Weapon_Definition
    );
    sword_defn.damage = 10;
    sword_defn.fire_rate = 1.0;
    sword_defn.description = "A sturdy iron sword.";
    
    // Store for later use
    all_weapon_definitions->append(sword_defn);
    
    // Stackable item example (stack_size = -1 for infinite)
    ammo_defn := create_item_definition(
        {"ammo", "Bullets", "icons/bullet.png", 99, Item_Definition, Item_Instance},
        Item_Definition
    );
}
```

### Item_Definition_Desc Fields

```csl
Item_Definition_Desc :: struct {
    id: string;              // Unique identifier (e.g., "sword", "health_potion")
    name: string;            // Display name (e.g., "Iron Sword")
    icon: string;            // Path to icon texture (e.g., "icons/sword.png")
    stack_size: s64;         // Max stack size (1 = not stackable, -1 = infinite)
    definition_type: typeid; // Your Item_Definition subclass type
    instance_type: typeid;   // Your Item_Instance subclass type
}
```

## Creating and Managing Items

### Creating Item Instances

```csl
// With custom instance type - returns Weapon_Item directly (no cast needed)
item := Items.create_item_instance(sword_defn, Weapon_Item, 1);

// Without custom instance type - returns Item_Instance
basic_item := Items.create_item_instance(basic_defn, 10); // 10 stacked items
```

### Adding Items to Inventory

```csl
// Check if there's room first
will_destroy_item: bool;
if Items.can_move_item_to_inventory(item, player.default_inventory, ref will_destroy_item) {
    Items.move_item_to_inventory(item, player.default_inventory);
    // will_destroy_item is true if item merged into existing stack
}

// Or move as many as possible (for partial transfers)
destroyed_item: bool;
amount_moved := Items.move_as_many_items_as_possible_to_inventory(item, player.default_inventory, ref destroyed_item);
```

### Removing Items from Inventory

```csl
// Remove from inventory (item still exists, just not in any inventory)
Items.remove_item_from_inventory(item, player.default_inventory);

// Destroy an item entirely
Items.destroy_item_instance(item);       // Destroy entire stack
Items.destroy_item_instance(item, 5);    // Destroy only 5 from the stack
```

### Accessing Inventory Contents

```csl
// Iterate through inventory slots
for i: 0..player.default_inventory.capacity-1 {
    item := player.default_inventory->get_item(i);
    if item == null continue;
    
    // Get the item's definition
    defn := item->get_definition();
    
    // Cast to your custom type if needed
    weapon_defn := defn.(Weapon_Definition);
    if weapon_defn != null {
        log_info("Found weapon with % damage", {weapon_defn.damage});
    }
}
```

### Swapping Items

```csl
// Swap items between two inventory slots
if Items.can_swap_items(inventory_a, inventory_b, slot_a, slot_b) {
    Items.swap_items(inventory_a, inventory_b, slot_a, slot_b);
}
```

## Inventory API Reference

### Items Struct (Static Functions)

```csl
Items :: struct {
    // Inventory management
    create_inventory  :: proc(unique_id: string, capacity: s64) -> Inventory;
    destroy_inventory :: proc(inventory: Inventory) -> bool;
    set_capacity      :: proc(inventory: Inventory, capacity: s64);
    
    // Item definition creation
    create_item_definition :: proc(desc: Item_Definition_Desc) -> Item_Definition;
    
    // Item instance management
    create_item_instance  :: proc(definition: Item_Definition, count: s64 = 1) -> Item_Instance;
    create_item_instance  :: proc(definition: Item_Definition, $T: typeid, count: s64 = 1) -> T;  // Returns typed instance
    destroy_item_instance :: proc(instance: Item_Instance, count: s64 = -1);  // -1 = entire stack
    
    // Inventory operations
    calculate_room_in_inventory_for_item :: proc(definition: Item_Definition, inventory: Inventory) -> s64;
    can_move_item_to_inventory           :: proc(instance: Item_Instance, inventory: Inventory, will_destroy_item: ref bool) -> bool;
    move_item_to_inventory               :: proc(instance: Item_Instance, inventory: Inventory);
    move_as_many_items_as_possible_to_inventory :: proc(instance: Item_Instance, inventory: Inventory, destroyed_item: ref bool) -> s64;
    remove_item_from_inventory           :: proc(instance: Item_Instance, inventory: Inventory);
    can_swap_items                       :: proc(inventory_a: Inventory, inventory_b: Inventory, slot_a: s64, slot_b: s64) -> bool;
    swap_items                           :: proc(inventory_a: Inventory, inventory_b: Inventory, slot_a: s64, slot_b: s64);
    
    // UI Drawing
    draw_inventory :: proc(rect: Rect, inventory: Inventory, options: Inventory_Draw_Options) -> bool;
    draw_hotbar    :: proc(player: Player, inventory: Inventory, options: Inventory_Draw_Options) -> Draw_Hotbar_Result;
}
```

### Item_Definition Methods

```csl
defn->get_name() -> string;        // Display name
defn->get_id() -> string;          // Unique ID
defn->get_icon() -> Texture_Asset; // Icon texture
```

### Item_Instance Methods

```csl
item->get_definition() -> Item_Definition;  // Get the definition this instance was created from
```

### Inventory Methods

```csl
inventory->get_item(index: s64) -> Item_Instance;  // Get item at slot (may be null)
inventory.capacity                                  // Read-only capacity
```

## Drawing Inventory UI

Draw inventory UI in the player's `ao_update` or `ao_late_update` (inside `is_local_or_server()` check).

### Hotbar

```csl
ao_late_update :: method(dt: float) {
    if this->is_local_or_server() {
        // Draw hotbar at bottom of screen
        options := Inventory_Draw_Options.default();
        options.hotbar_item_count = 5;
        options.enable_use_from_hotbar = true;
        options.scroll_item_selection = true;
        options.keyboard_item_selection = true;
        
        result := Items.draw_hotbar(this, default_inventory, options);
        
        // Handle item selection
        if result.selected_item != null {
            use_item(this, result.selected_item);
        }
        
        // Handle drag-drop out of inventory
        if result.dropped_item != null {
            drop_item(this, result.dropped_item);
        }
    }
}
```

### Full Inventory Grid

```csl
// Draw a full inventory grid in a rect
inventory_rect := UI.get_safe_screen_rect()->inset(100);
options := Inventory_Draw_Options.default();
options.title = "Inventory";
options.show_exit_button = true;
options.show_background = true;
options.columns = 5;
options.rows = 4;

closed := Items.draw_inventory(inventory_rect, player.default_inventory, options);
if closed {
    // User clicked exit button
    inventory_open = false;
}
```

### Inventory_Draw_Options

```csl
Inventory_Draw_Options :: struct {
    title: string;                      // Title text for inventory panel
    show_exit_button: bool;             // Show X button to close
    show_scroll_bar: bool;              // Show scroll bar for overflow
    show_background: bool;              // Draw background panel
    allow_drag_drop: bool;              // Allow dragging items
    drag_drop_color_multiplier: v4;     // Tint for dragged items
    hotbar_item_count: s32;             // Number of hotbar slots (default: 6)
    columns: s32;                       // Grid columns
    rows: s32;                          // Grid rows
    force_select_hotbar_index: s32;     // Force select specific slot (-1 = none)
    hide_bag_button: bool;              // Hide the "open bag" button on hotbar
    enable_selection: bool;             // Allow selecting items
    scroll_item_selection: bool;        // Scroll wheel changes selection
    keyboard_item_selection: bool;      // Number keys select items
    enable_use_from_hotbar: bool;       // Clicking hotbar uses item
    
    default :: proc() -> Inventory_Draw_Options;  // Get default options
}
```

### Draw_Hotbar_Result

```csl
Draw_Hotbar_Result :: struct {
    selected_item: Item_Instance;       // Item that was selected/used (or null)
    selected_item_index: s64;           // Index of selected item
    dropped_item: Item_Instance;        // Item that was dragged out (or null)
    entire_rect: Rect;                  // The rect the hotbar was drawn in
    inventory_open: bool;               // Whether full inventory is open
    inventory_open_t: float;            // Animation progress (0-1)
}
```

## Complete Example

```csl
// Item definitions
Artifact_Definition :: class : Item_Definition {
    tier: Item_Tier;
    description: string;
    damage_bonus: float;
}

Artifact_Item :: class : Item_Instance {
    // Per-instance data
    modifier: float @ao_serialize;
}

Item_Tier :: enum {
    COMMON;
    UNCOMMON;
    RARE;
    EPIC;
    LEGENDARY;
}

// Store definitions globally
all_artifacts: [..]Item_Definition;

ao_before_scene_load :: proc() {
    // Register items
    sword := create_item_definition(
        {"sword_common", "Iron Sword", "icons/sword.png", 1, Artifact_Definition, Artifact_Item},
        Artifact_Definition
    );
    sword.tier = .COMMON;
    sword.damage_bonus = 5;
    sword.description = "A basic iron sword.";
    all_artifacts->append(sword);
}

// Grant item to player
try_give_item :: proc(player: Player, defn: Item_Definition) {
    item := Items.create_item_instance(defn, Artifact_Item);
    rng := rng_seed_time();
    item.modifier = rng_range_float(ref rng, 0, 2);
    
    will_destroy: bool;
    if Items.can_move_item_to_inventory(item, player.default_inventory, ref will_destroy) {
        Items.move_item_to_inventory(item, player.default_inventory);
        player->add_notification(format_string("Obtained %!", {defn->get_name()}));
    }
    else {
        // Inventory full - destroy the item we just created
        Items.destroy_item_instance(item);
        player->add_notification("Inventory full!");
    }
}

// Calculate total damage bonus from equipped items
calculate_damage_bonus :: proc(player: Player) -> float {
    total := 0.0;
    for i: 0..player.default_inventory.capacity-1 {
        item := player.default_inventory->get_item(i);
        if item == null continue;

        defn := item->get_definition();
        if defn.#type == Artifact_Definition {
            artifact_defn := defn.(Artifact_Definition);
            total += artifact_defn.damage_bonus;
        }

        if item.#type == Artifact_Item {
            artifact_item := item.(Artifact_Item);
            total += artifact_item.modifier;
        }
    }
    return total;
}
```

