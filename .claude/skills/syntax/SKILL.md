---
name: syntax
description: When writing new CSL code you must reference these docs to understand the syntax of .csl files.
---

## Declarations

```csl
my_variable: int = 42; // Explicit type
my_variable := 42; // Type inferred
my_variable: int; // Zero-initialized
```

Integer literals coerce to float, but not the reverse.

> **Struct fields cannot have inline defaults.**

### Constants

`::` instead of `:=`. Must be compile-time constant. Global variable initializers must also be constant (use `ao_start` or `ao_before_scene_load` for runtime init).

`PI` is already defined as a builtin — do not redefine it.

```csl
PI :: 3.14159265359; // DON'T — already exists
MY_SPEED :: 5.0; // DO — custom constants are fine
```

## Types

### Primitive Types

- Signed integers: `s8`, `s16`, `s32`, `s64`
- Unsigned integers: `u8`, `u16`, `u32`, `u64`
- Booleans: `bool`
- Floats: `f32`, `f64`
- Vector types: `v2`, `v3`, `v4` (float fields `.x`, `.y`, `.z`, `.w`; constructed with `v2{10, 20}`)
- `string`, `typeid`, `any`

## Structs

Structs are value types (shallow-copied on assignment/pass).

```csl
Food_Definition :: struct {
    name: string;
    food_value: int;
}
```

## Classes

Classes are reference types, allocated with `new`.

```csl
Foo :: class {
    value: int;
    position: v2;
}

foo := new(Foo); // type inference
foo: Foo = new(); // explicit type, inferred new
foo: Foo = new(Foo); // fully explicit
```

### Inheritance

```csl
Dog :: class : Animal {
    breed: string;
}
```

## Procedures

```csl
add :: proc(a: int, b: int) -> int {
    return a + b;
}
```

### Methods

Use `method()` instead of `proc()` inside a struct or class.

```csl
Dog :: class {
    name: string;

    bark :: method() {
        log_info("% says bark!", {name}); // implicit this.name
    }
}

dog := new(Dog);
dog.bark();
```

### Arrays

- **Fixed**: `[N]T` -- compile-time size, initialized with `{...}`
- **Slice**: `[]T` -- a view into array data (common for parameters)
- **Dynamic**: `[..]T` -- resizable list (`.count`, `.capacity`); implicitly converts to `[]T`

```csl
fixed: [4]int = {1, 2, 3, 4};
spawn_points: [3]v2 = {{0, 0}, {5, 0}, {0, 5}};
dyn: [..]int;
view: []int = dyn;

hit := Damage_Desc{amount=10, knockback={2, 1}}; // named fields use = (NOT :)
```

### Dynamic Arrays

```csl
numbers: [..]int;
numbers.append(10);
numbers.pop();
numbers.clear();
numbers.reserve(64);

// Remove -- optional mode: .ONE (default) or .ALL
numbers.unordered_remove_by_value(10);
numbers.ordered_remove_by_value(999, .ALL);
numbers.unordered_remove_by_index(0);
numbers.ordered_remove_by_index(0);
```

## Control Flow
No parentheses around conditions. Enum values use `.` prefix in `switch`:

```csl
switch tier {
    case .COMMON:    return {0.7, 0.7, 0.7, 1.0};
    case .RARE:      return {0.3, 0.5, 1.0, 1.0};
    default:         return {1.0, 1.0, 1.0, 1.0};
}
```

Cases support **multiple values** (comma-separated) and **ranges** (`..`, inclusive):

```csl
switch level {
    case 1, 2, 3: tier = .BEGINNER;
    case 4..10:   tier = .INTERMEDIATE;
    case 11..20, 25, 30..50: tier = .ADVANCED;
    default:      tier = .UNKNOWN;
}
```

Multi-statement bodies must use braces:

```csl
switch tier {
    case .COMMON, .UNCOMMON: {
        color = {0.7, 0.7, 0.7, 1.0};
        label = "Common";
    }
    default: {
        color = {1.0, 1.0, 1.0, 1.0};
        label = "Unknown";
    }
}
```

Do not write C-style fallthrough logic in CSL switch cases.

`..` ranges are **inclusive**: `for i: 0..9 { }` iterates 0 through 9.

`for` also handles custom iterators: `for player: component_iterator(My_Player) { }`

Custom iterator-based `for` loops require a `next :: method() -> bool` and a `current` field.

### Enums, `defer`, and `#alive`

```csl
Item_Tier :: enum {
    COMMON;
    RARE;
}

if !#alive(target) return;

UI.push_screen_draw_context();
defer UI.pop_draw_context();
```

`#alive(expr)` checks whether a class reference is still valid and MUST be used before accessing to prevent crashes. 
`defer` runs a statement when the current scope exits and is commonly used for UI push/pop cleanup.

## Type Casting

Use `expr.(T)` syntax: `b := 123.4.(int);`

## Member Access and Method Calls

```csl
increment :: proc(f: *Foo) { f.a += 1; }
f: Foo;
f.increment();
```

## Parameter Passing: ref

Mark both the parameter and callsite with `ref`. When forwarding a ref param, use `ref` again:

```csl
update_health :: proc(health: ref int, damage: int) {
    health -= damage;
}

hp := 100;
update_health(ref hp, 25);
```

## Polymorphic Procedures

`$T` on a parameter deduces the type from the callsite. `$T` is only used when **defining** polymorphic procs — callers always pass concrete types:

```csl
min :: proc(a: $T, b: T) -> T {
    if a < b return a;
    return b;
}

result := min(3, 5); // T is deduced as int
```

> `T` is not a type. Never write `component_iterator(T)` or `[..]T` — always use the actual type name like `component_iterator(Enemy)` or `[..]Enemy`.

## Function Pointers and Callbacks

**CSL has no closures.** Pair a callback field with a `userdata: Object` field. Any class instance can be stored as `Object` and cast back:

```csl
on_death_userdata: Object;
on_death: proc(player: Player, userdata: Object);

// Setting the callback:
player.on_death_userdata = this;
player.on_death = proc(player: Player, userdata: Object) {
    tracker := userdata.(Death_Tracker);
    tracker.death_count += 1;
};
```

## Using Keyword

`using` lets you access fields without a selector:
```csl
using position: v3;
x = 123; // Instead of position.x
```

## Runtime Type Checking

Use `.#type` to get the runtime type of a class instance:
```csl
if effect.#type == Slow_Effect {
    slow := effect.(Slow_Effect);
}
```

## Multiple Return Values

```csl
get_thing :: proc() -> Thing, bool {
    return g_thing, true;
}

thing, ok := get_thing();
if thing, ok := get_thing(); ok { }
