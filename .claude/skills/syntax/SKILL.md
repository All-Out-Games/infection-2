---
name: syntax
description: When writing new CSL code you must reference these docs to understand the syntax of .csl files.
---

## Declarations

```csl
my_variable: int = 42;  // Explicit type
my_variable := 42;       // Type inferred
my_variable: int;        // Zero-initialized

a := 42;   // int (no decimal)
b := 42.0; // float (has decimal)
```

Integer literals coerce to float, but not the reverse.

### Constants

`::` instead of `:=`. Must be compile-time constant (no runtime values).

```csl
PI :: 3.14159265359;
PI: float : 3.14159265359;
```

## Types

### Primitive Types

- Signed integers: `s8`, `s16`, `s32`, `s64`
- Unsigned integers: `u8`, `u16`, `u32`, `u64`
- Booleans: `b8`, `b16`, `b32`, `b64`
- Floats: `f32`, `f64`
- Aliases: `int` == `s64`, `uint` == `u64`, `bool` == `b8`, `float` == `f32`
- Vector types: `v2`, `v3`, `v4` (float fields `.x`, `.y`, `.z`, `.w`)
- `string`, `typeid`, `any`

```csl
position: v2 = {10, 20};
offset := v3{1, 4, 9};
```

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

foo := new(Foo);       // type inference
foo: Foo = new();      // explicit type, inferred new
foo: Foo = new(Foo);   // fully explicit
```

### Inheritance

```csl
Animal :: class {
    name: string;
    age: int;
}

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

Use `::` for constant binding, `:=` if you need to reassign the proc later.

### Methods

Use `method()` instead of `proc()` inside a struct or class. Methods have implicit `this`; fields and other methods on `this` can be accessed without qualification.

```csl
Dog :: class {
    name: string;

    bark :: method() {
        log_info("% says bark!", {name});  // `name` == `this.name`
        woof();                             // calls this->woof()
    }

    woof :: method() {
        log_info("% says woof!", {name});
    }
}

dog := new(Dog);
dog.name = "Buddy";
dog->bark();
```

### Dynamic Arrays

`[..]T` -- resizable array. Fields: `.count`, `.capacity`. Implicitly converts to `[]T` (slice) when passed to procedures.

```csl
numbers: [..]int;
numbers->append(10);
numbers->append(20);
first := numbers[0];
numbers[1] = 999;

numbers->pop();
numbers->clear();
numbers->reserve(64);

// Remove by value -- optional mode: .ONE (default) or .ALL
numbers->unordered_remove_by_value(10);
numbers->ordered_remove_by_value(999, .ALL);
numbers->unordered_remove_by_index(0);
numbers->ordered_remove_by_index(0);
```

## Control Flow

`if`/`else if`/`else`, `while`, `continue`, `break` work as expected. No parentheses around conditions.

### Switch

Enum values use `.` prefix. Use `case:` (no value) for a default clause.
```csl
switch tier {
    case .COMMON:    return {0.7, 0.7, 0.7, 1.0};
    case .RARE:      return {0.3, 0.5, 1.0, 1.0};
    case .LEGENDARY: return {1.0, 0.8, 0.2, 1.0};
    case:            return {1.0, 1.0, 1.0, 1.0}; // default
}
```

### For Loops

`..` ranges are **inclusive**.
```csl
for i: 0..9 { }        // 0 to 9 inclusive
for item: my_array { }  // iterate elements
```

### Foreach (custom iterators)
```csl
foreach player: component_iterator(My_Player) {
    player->update(dt);
}
```

## Type Casting

Use `expr.(T)` syntax.
```csl
a := 123.4;
b := a.(int);     // truncates to 123
c := b.(float);
```

## Member Access and Method Calls

Use `.` for field access. Use `->` for calling methods.

Any procedure whose first parameter matches the type can be called as a method (UFCS):
```csl
Foo :: struct { a: int; }

increment :: proc(f: *Foo) {
    f.a += 1;
}

f: Foo;
f.a = 100;
f->increment();
```

## Parameter Passing: ref

Mark both the parameter and callsite with `ref`:

```csl
update_health :: proc(health: ref int, damage: int) {
    health -= damage;
}

hp := 100;
update_health(ref hp, 25);

// When passing a ref param to another ref param, use ref again
foo :: proc(health: ref int) {
    bar(ref health);
}
```

## Polymorphic Procedures

`$T` on a parameter deduces the type from the callsite:

```csl
min :: proc(a: $T, b: T) -> T {
    if a < b return a;
    return b;
}
```

## Function Pointers and Callbacks

**CSL has no closures.** Inline `proc() { ... }` cannot capture surrounding variables. Pair callbacks with a `userdata: Object` field:

```csl
Player :: class : Component {
    health: int;
    on_death_userdata: Object;
    on_death: proc(player: Player, userdata: Object);

    take_damage :: method(damage: int) {
        health -= damage;
        if health <= 0 && on_death != null {
            on_death(this, on_death_userdata);
        }
    }
}

Death_Tracker :: class : Component {
    death_count: int;

    ao_start :: method() {
        player := entity->get_component(Player);
        player.on_death_userdata = this;
        player.on_death = proc(player: Player, userdata: Object) {
            tracker := userdata.(Death_Tracker);
            tracker.death_count += 1;
        };
    }
}
```

## Using Keyword

`using` lets you access fields without a selector:
```csl
using position: v3;
x = 123;  // Instead of position.x
```

## Runtime Type Checking

Use `.#type` to get the runtime type of a class instance:
```csl
if effect.#type == Slow_Effect {
    slow := effect.(Slow_Effect);
    speed *= slow.speed_multiplier;
}
```

## Multiple Return Values

```csl
get_thing :: proc() -> Thing, bool {
    return g_thing, true;
}

thing, ok := get_thing();
if thing, ok := get_thing(); ok { }  // inline declaration in if
thing, _ := get_thing();              // discard with _
```
