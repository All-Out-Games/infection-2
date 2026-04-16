---
name: inventory
description: Any item or inventory system in your game MUST use the API described in this skill. Do not create custom inventory/item systems. 
---
1. **Item_Definition** - Template defining what an item IS (name, icon, stack size, custom properties)
2. **Item_Instance** - An actual item in the world/inventory (has a count, can be moved)
3. **Inventory** - Container holding item instances in slots
4. Every Player has `player.default_inventory` built in

> **Persistence:** To automatically save player inventories across sessions, call `Scene.set_auto_save_player_inventory(true)` in `ao_before_scene_load`.

## Creating Custom Item Types
Extend `Item_Definition` and `Item_Instance` for custom properties:

```csl
Weapon_Definition :: class : Item_Definition {
    damage: int;
    fire_rate: float;
    description: string;
}

Weapon_Item :: class : Item_Instance {
    durability: int @ao_serialize;
    kills: int @ao_serialize;
}
```

## Registering Item Definitions
Register in `ao_before_scene_load` using `Items.register_item_definition`:

```csl
all_weapon_definitions: [..]Weapon_Definition;

ao_before_scene_load :: proc() {
    sword_icon := get_asset(Texture_Asset, "icons/sword.png");
    sword_defn := Items.register_item_definition(
        {"sword", "Iron Sword", sword_icon, 1, .COMMON},
        Weapon_Definition,
        instance_type = Weapon_Item
    );
    sword_defn.damage = 10;
    sword_defn.description = "A sturdy iron sword.";
    all_weapon_definitions.append(sword_defn);

    bullet_icon := get_asset(Texture_Asset, "icons/bullet.png");
    ammo_defn := Items.register_item_definition({"ammo", "Bullets", bullet_icon, 99, .COMMON});
}
```

### Item_Definition_Desc Fields
```csl
Item_Definition_Desc :: struct {
    id: string;
    name: string;
    icon: Texture_Asset;
    stack_size: s64; // Max stack (1 = not stackable, -1 = infinite)
    tier: Item_Tier; // .COMMON, .UNCOMMON, .RARE, .EPIC, .LEGENDARY, .MYTHIC
}
```

## Creating and Managing Items
```csl
// Typed instance - returns Weapon_Item directly (no cast needed)
item := Items.create_item_instance(sword_defn, Weapon_Item, 1);

basic_item := Items.create_item_instance(basic_defn, 10);
```

### Giving an Item to a Player
Create an instance, then move it into their inventory with `Items.move_item_to_inventory`:

```csl
item := Items.create_item_instance(sword_defn, 1);
will_destroy: bool;
if Items.can_move_item_to_inventory(item, player.default_inventory, ref will_destroy) {
    Items.move_item_to_inventory(item, player.default_inventory);
}
```

To drop an item in the world instead, see the `inventory-droppable-placeable-items` skill (`Dropped_Item.spawn`).

### Adding Items to Inventory
```csl
will_destroy_item: bool;
if Items.can_move_item_to_inventory(item, player.default_inventory, ref will_destroy_item) {
    Items.move_item_to_inventory(item, player.default_inventory);
    // will_destroy_item is true if item merged into existing stack
}

destroyed_item: bool;
amount_moved := Items.move_as_many_items_as_possible_to_inventory(item, player.default_inventory, ref destroyed_item);
```

### Removing / Destroying Items
```csl
Items.remove_item_from_inventory(item, player.default_inventory);
Items.destroy_item_instance(item); // Entire stack
Items.destroy_item_instance(item, 5); // Only 5 from stack
```

### Iterating Inventory
```csl
for i: 0..player.default_inventory.capacity-1 {
    item := player.default_inventory.get_item(i);
    if item == null continue;

    defn := item.get_definition();
    weapon_defn := defn.(Weapon_Definition);
    if weapon_defn != null {
        log_info("Found weapon with % damage", {weapon_defn.damage});
    }
}
```

### Swapping Items
```csl
if Items.can_swap_items(inventory_a, inventory_b, slot_a, slot_b) {
    Items.swap_items(inventory_a, inventory_b, slot_a, slot_b);
}
```

## Inventory API Reference
### Items Struct (Static Functions)

```csl
Items :: struct {
    create_inventory  :: proc(unique_id: string, capacity: s64) -> Inventory;
    destroy_inventory :: proc(inventory: Inventory) -> bool;
    set_capacity      :: proc(inventory: Inventory, capacity: s64);

    register_item_definition :: proc(desc: Item_Definition_Desc, $Definition_Type: typeid = Item_Definition, instance_type: typeid = Item_Instance) -> Definition_Type;

    create_item_instance  :: proc(definition: Item_Definition, count: s64 = 1) -> Item_Instance;
    create_item_instance  :: proc(definition: Item_Definition, $T: typeid, count: s64 = 1) -> T;
    destroy_item_instance :: proc(instance: Item_Instance, count: s64 = -1); // -1 = entire stack

    calculate_room_in_inventory_for_item :: proc(definition: Item_Definition, inventory: Inventory) -> s64;
    can_move_item_to_inventory           :: proc(instance: Item_Instance, inventory: Inventory, will_destroy_item: ref bool) -> bool;
    move_item_to_inventory               :: proc(instance: Item_Instance, inventory: Inventory);
    move_as_many_items_as_possible_to_inventory :: proc(instance: Item_Instance, inventory: Inventory, destroyed_item: ref bool) -> s64;
    remove_item_from_inventory           :: proc(instance: Item_Instance, inventory: Inventory);
    can_swap_items                       :: proc(inventory_a: Inventory, inventory_b: Inventory, slot_a: s64, slot_b: s64) -> bool;
    swap_items                           :: proc(inventory_a: Inventory, inventory_b: Inventory, slot_a: s64, slot_b: s64);

    draw_inventory :: proc(rect: Rect, inventory: Inventory, options: Inventory_Draw_Options) -> bool;
    draw_hotbar    :: proc(player: Player, inventory: Inventory, options: Inventory_Draw_Options) -> Draw_Hotbar_Result;
}
```

### Item_Definition Methods
```csl
defn.get_name() -> string;
defn.get_id() -> string;
defn.get_icon() -> Texture_Asset;
```

### Item_Instance Fields & Methods

```csl
item.quantity // s64, read-only — stack count
item.slot_index // s64, read-only — slot in parent inventory
item.inventory // Inventory, read-only — parent inventory (null if not in one)
item.get_definition() -> Item_Definition;
```

### Inventory Methods

```csl
inventory.get_item(index: s64) -> Item_Instance; // May return null
inventory.capacity
```

### Type checking items

Use `#type` and cast to distinguish custom types:

```csl
defn := item.get_definition();
if defn.#type == Weapon_Definition {
    weapon_defn := defn.(Weapon_Definition);
}
if item.#type == Weapon_Item {
    weapon_item := item.(Weapon_Item);
}
```

## Drawing Inventory UI
You must draw the inventory in `ao_late_update` inside `is_local_or_server()`.

### Hotbar (required)
```csl
ao_late_update :: method(dt: float) {
    if this.is_local_or_server() {
        options := Inventory_Draw_Options.default();
        options.hotbar_item_count = 5;
        options.enable_use_from_hotbar = true;
        options.scroll_item_selection = true;
        options.keyboard_item_selection = true;

        result := Items.draw_hotbar(this, default_inventory, options);

        if #alive(result.selected_item) {
            use_item(this, result.selected_item);
        }
        if #alive(result.dropped_item) {
            drop_item(this, result.dropped_item);
        }
    }
}
```

### Popup Inventory Grid (Chests, etc...)
```csl
inventory_rect := UI.get_safe_screen_rect().inset(100);
options := Inventory_Draw_Options.default();
options.title = "Inventory";
options.show_exit_button = true;
options.show_background = true;
options.columns = 5;
options.rows = 4;

closed := Items.draw_inventory(inventory_rect, player.default_inventory, options);
if closed { inventory_open = false; }
```

### Inventory_Draw_Options

```csl
Inventory_Draw_Options :: struct {
    title: string;
    show_exit_button: bool;
    allow_drag_drop: bool;
    drag_drop_color_multiplier: v4;
    hotbar_item_count: s32; // default: 6
    columns: s32;
    rows: s32;
    force_select_hotbar_index: s32; // -1 = none
    hide_bag_button: bool;
    enable_selection: bool;
    scroll_item_selection: bool;
    enable_use_from_hotbar: bool;
}
```

### Draw_Hotbar_Result

> **Important:** `selected_item` and `dropped_item` may be non-null yet reference
> items that were destroyed during the same frame (e.g. consumed on use, merged
> into a stack). A `!= null` check alone is **not** sufficient — always guard with
> `#alive()` before calling methods on them.

```csl
Draw_Hotbar_Result :: struct {
    selected_item: Item_Instance; // null if none (use #alive() before access)
    selected_item_index: s64;
    dropped_item: Item_Instance; // null if none (use #alive() before access)
    entire_rect: Rect;
    inventory_open: bool;
    inventory_open_t: float; // Animation progress 0-1
}
```
