---
name: syntax
description: When writing new CSL code you must reference these docs to understand the syntax of .csl files.
---
## Basic Syntax

## Declarations

Declarations bind a name to a value.

### Variables

```csl
// General form
<name>: <type> = <expression>;
```

Either `<type>` or `<expression>` can be omitted. If the type is omitted, it is inferred from the type of the expression. If the expression is omitted, the variable is initialized to zero.

```csl
// Explicit type
my_variable: int = 42;

my_variable := 42; // type is inferred to be `int`

// Identical to `my_variable := 0;`
my_variable: int;
```

If a concrete type needs to be inferred, there are some rules the type system follows.

If there are no decimals, the type will be inferred as `int`. If there are, it will be inferred as `float`.

```csl
a := 42;   // type_of(a) == int
b := 42.0; // type_of(b) == float
```

If the expected type is float, an "integer-looking" number literal will implicitly coerce. The opposite is not true.

```csl
a: float = 42;   // All good
b: int   = 42.0; // Compile error! In this case 42.0 could technically coerce
                 // to an int since it is a whole number, but we keep it simple
                 // and disallow it because of the decimal.
```

### Constants

Constant declarations follow the same rules as variables except instead of `:=` it's `::`.

```csl
PI: float : 3.14159265359;
// or, using type inference
PI :: 3.14159265359;
```

Constants in this language are compile-time constants, not "immutable." So something like this is invalid:

```csl
a := 123;
b :: a; // `a` is not constant, so it cannot be assigned to a constant.
```

## Types

### Primitive Types

- Signed integers:
    - `s8`, `s16`, `s32`, `s64`
- Unsigned integers:
    - `u8`, `u16`, `u32`, `u64`
- Booleans:
    - `b8`, `b16`, `b32`, `b64`
- Floats:
    - `f32`, `f64`
- Aliases
    - `int` == `s64`
    - `uint` == `u64`
    - `bool` == `b8`
    - `float` == `f32`
- Vector types
    - `v2`, `v3`, `v4`
- `string`
- `typeid`
- `any`

### Vector Types

`v2`, `v3`, and `v4` have `.x`, `.y`, `.z`, and `.w` float fields as expected.

Example:
```
position: v2 = {10, 20};  // x=10, y=20
color: v4 = {1, 0, 0, 1}; // Red with full alpha
offset := v3{1, 4, 9}; // With type inference
```

## Structs

Structs are value types, just like `int` or `float`. When passed to a procedure or assigned to another variable a shallow copy is made.

```csl
Food_Definition :: struct {
    name: string;
    food_value: int;
    health: int;
    required_mouth_size: int;
}

food: Food_Definition;
food.name = "Apple";
```

## Classes

Classes are reference types, a fancy term for "pointer," and as such need to be initialized using `new`.

```csl
Foo :: class {
    value: int;
    position: v2;
}

foo: Foo = new(Foo); // or you can use type inference by doing:
                     //     foo := new(Foo);
                     // or:
                     //     foo: Foo = new();
foo.value = 123;
foo.position = {12, 34};
```

### Inheritance

Structs/classes can inherit from other structs/classes:

```csl
Animal :: class {
    name: string;
    age: int;
}

Dog :: class : Animal {
    breed: string;
}

dog := new(Dog);
dog.name = "Buddy";     // Inherited from Animal
dog.age = 5;            // Inherited from Animal
dog.breed = "Labrador"; // Dog's own field
```

## Procedures

### Basic Procedure

```csl
proc() {
    log_info("Hello!", {});
}
```

### With Parameters and Return Value

```csl
proc(a: int, b: int) -> int {
    return a + b;
}
```

### Procedures as Values

Procedures themselves are just normal values that can be bound to a name in a normal declaration like so:

```csl
add : proc(a: int, b: int) -> int : proc(a: int, b: int) -> int {
    return a + b;
}
```

Or, using type inference:

```csl
add :: proc(a: int, b: int) -> int {
    return a + b;
}
```

Generally we like to use type inference for procedures :)

You can also use `:=` if you want it to be a variable that you can reassign it later.

```csl
add := proc(a: int, b: int) -> int {
    return a + b;
}

add(2, 4); // 6, of course!

add = proc(a: int, b: int) -> int {
    return a * b;
}

add(2, 4); // 8, I guess.
```

### Methods

Use `method()` instead of `proc()` to define methods inside a struct or class. Methods have an implicit `this` reference parameter of the enclosing type.

```csl
Dog :: class {
    name: string;

    bark :: method() {
        log_info("% says bark!", {name});  // Can access fields directly without `this.`
    }

    speak :: method(message: string) {
        log_info("% says: %", {name, message});
    }
}

dog := new(Dog);
dog.name = "Buddy";
dog->bark();              // "Buddy says bark!"
dog->speak("hello");      // "Buddy says: hello"
```

Inside a method, you can:
- Access fields directly without `this.` (e.g., `name` instead of `this.name`)
- Call other methods on the same object without `this->` (e.g., `woof()` instead of `this->woof()`)

```csl
Dog :: class {
    name: string;

    bark :: method() {
        log_info("% says bark!", {name});
        woof();  // Calls this->woof() implicitly
    }

    woof :: method() {
        log_info("% says woof!", {name});
    }
}
```

You can still explicitly call methods on other objects:

```csl
Dog :: class {
    friend: Dog;

    greet :: method() {
        if friend != null {
            friend->bark();  // Call method on a different object
        }
    }
}
```

### Dynamic Arrays

Dynamic arrays use `[..]T` syntax and provide a resizable array with automatic capacity management. They have three fields: `data` (pointer to elements), `count` (current number of elements), and `capacity` (allocated space).

> Dynamic array methods use the `->` method call syntax (e.g., `arr->append(x)`), not `.` field access.

```csl
// Declare a dynamic array (starts empty)
numbers: [..]int;

// Add elements using append
numbers->append(10);
numbers->append(20);
numbers->append(30);

log_info("count: %", {numbers.count});       // 3
log_info("capacity: %", {numbers.capacity}); // 8 (auto-grows)

// Access elements with subscript
first := numbers[0];  // 10
numbers[1] = 999;     // Modify element

// Remove elements
numbers->pop();                           // Remove and return last element
numbers->unordered_remove_by_value(10);   // Fast removal, removes first match (swaps with last)
numbers->ordered_remove_by_value(999);    // Preserves order, removes first match (shifts elements)
numbers->clear();                         // Remove all elements (O(1), just sets count to 0)

// Remove by value has an optional mode: .ONE (default) or .ALL
numbers->unordered_remove_by_value(5, .ONE);  // Removes only first 5 found
numbers->unordered_remove_by_value(5, .ALL);  // Removes all 5s
numbers->ordered_remove_by_value(5, .ALL);    // Removes all 5s, preserves order
```

Dynamic arrays can be implicitly converted to managed arrays `[]T` when passed to procedures:

```csl
sum :: proc(arr: []int) -> int {
    total := 0;
    for val: arr {
        total += val;
    }
    return total;
}

numbers: [..]int;
numbers->append(1);
numbers->append(2);
numbers->append(3);
result := sum(numbers);  // Implicit conversion [..]int -> []int
```

Available methods (from `core:ao`):
- `append(element)` - Add element to end
- `reserve(capacity)` - Pre-allocate space
- `pop() -> T` - Remove and return last element
- `clear()` - Remove all elements (O(1), just sets count to 0)
- `unordered_remove_by_value(value, mode = .ONE)` - Remove by value (fast, doesn't preserve order). Use `.ALL` to remove all matches.
- `unordered_remove_by_index(index)` - Remove by index (fast, doesn't preserve order)
- `ordered_remove_by_value(value, mode = .ONE)` - Remove by value (preserves order). Use `.ALL` to remove all matches.
- `ordered_remove_by_index(index)` - Remove by index (preserves order)

## Control Flow

### If Statements

```csl
if condition {
    // code
}
else if other_condition {
    // code
}
else {
    // code
}
```

### Switch Statements
```csl
Item_Tier :: enum {
    COMMON;
    UNCOMMON;
    RARE;
    EPIC;
    LEGENDARY;
}

get_tier_color :: proc(tier: Item_Tier) -> v4 {
    switch tier {
        case .COMMON:    return {0.7, 0.7, 0.7, 1.0};   // Gray
        case .UNCOMMON:  return {0.3, 0.8, 0.3, 1.0};   // Green
        case .RARE:      return {0.3, 0.5, 1.0, 1.0};   // Blue
        case .EPIC:      return {0.7, 0.3, 0.9, 1.0};   // Purple
        case .LEGENDARY: return {1.0, 0.8, 0.2, 1.0};   // Gold
        // there is no default or else statement
    }
    return {1, 1, 1, 1};  // Default fallback
}
```


```csl
while condition {
    // code
}
```

### For Loops

Use `..` for inclusive ranges:

```csl
for i: 0..9 {
    // Iterates from 0 to 9 (inclusive)
    log_info("i = %", {i});
}

for i: 1..count {
    // Iterates from 1 to count (inclusive)
}

// Iterate over array/slice elements
for item: my_array {
    // item is each element in the array
}
```

### Continue and Break

```csl
while true {
    if should_skip continue;
    if should_stop break;
}
```

### Foreach Loops

For iterating over custom iterators:

```csl
foreach player: component_iterator(My_Player) {
    player->update(dt);
}
```

`foreach` is syntactic sugar that calls `->next()` and reads `.current` on an iterator.

## Type Casting

Use `expr.(T)` to cast from one type to another.

```csl
a := 123.4;       // type_of(a) == float, a == 123.4
b := a.(int);     // type_of(b) == int,   b == 123
c := b.(float);   // type_of(c) == float, c == 123.0
```

## Method-calls

Use `.` for field access. Use `->` for calling methods.

```csl
value := foo.my_field;           // Field access
entity->set_local_position({0, 0}); // Method call
```

Any procedure can be called as a method if it type of the first parameter matches.

```csl
Foo :: struct {
    a: int;
}

increment :: proc(f: *Foo) {
    f.a += 1;
}

f: Foo;
f.a = 100;
f->increment();
// f.a == 101 here
```

## Parameter Passing: ref vs Pointers

When you need to pass a parameter by reference to allow modification, **prefer `ref` over pointers (`*`)**.

### Using ref (Preferred)

```csl
// CORRECT: Use ref for mutable parameters
update_position :: proc(pos: ref v2, velocity: v2, dt: float) {
    pos.x += velocity.x * dt;
    pos.y += velocity.y * dt;
}

// At callsite, use ref keyword
my_pos := v2{0, 0};
update_position(ref my_pos, {10, 5}, 0.16);
// my_pos is now modified

// CORRECT: ref for modifying structs in UI layout
draw_panel :: proc(rect: ref Rect) {
    header := rect->cut_top(50);  // Modifies caller's rect
    draw_header(header);
    // rect is now smaller, ready for content
}

// Use ref for mutable primitive parameters
update_health :: proc(health: ref int, damage: int) {
    health -= damage;
}

// ref types are always auto-deref'd, so if you are passing a ref to a ref, you need to ref it again
foo :: proc(health: ref int) {
    bar :: proc(a: ref int) {
        // ...
    }

    bar(ref health); // ref again
}
```

## Polymorphism

### Polymorphic Procedures

#### Type Polymorphism

`$` used on a type means "deduce the type from the callsite and bake a new version of this procedure using that type."

```csl
min :: proc(a: $T, b: T) -> T {
    if a < b {
        return a;
    }
    return b;
}

a := min(123,   456);   // `T :: int` here.
b := min(123.0, 456.0); // `T :: float` here.
c := min(123.0, 456);   // `T :: float` here because the `a` parameter has the
                        // `$`, meaning it is authoritative over deciding what
                        // `T` is. Additionally, the 456 coerces to a float. See
                        // the section on type inference above.
```

## Function Pointers and Callbacks

CSL does not have virtual functions or closures. To achieve polymorphic behavior or event callbacks, use function pointer fields set at runtime.

**Important:** CSL does not have closures. Inline `proc() { ... }` definitions cannot capture surrounding variables—they behave like global functions.

### Callback Pattern with Userdata

Since callbacks can't capture context, pair them with a `userdata: Object` field:

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

> **Tip:** CSL allows derived types in callback signatures (e.g., `proc(p: Player, t: Death_Tracker)` assigned to `proc(p: Player, u: Object)`), which avoids manual casting. Use carefully—passing the wrong type will cause bugs.

## Using Keyword

The `using` keyword lets you access fields without a selector:

```csl
using position: v3;

x = 123;  // Instead of position.x
y = 321;
```

## Type Information

### Types as Values

```csl
default_of :: proc($T: typeid) -> T {
    t: T;
    return t;
}

a := default_of(int);       // 0
b := default_of(string);    // ""
c := default_of([4]int);    // {0, 0, 0, 0}
```

### Runtime Type Checking

Use `.#type` to get the runtime type of a class instance:

```csl
if effect.#type == Slow_Effect {
    slow := effect.(Slow_Effect);
    speed *= slow.speed_multiplier;
}
```

### Multiple Return Types

Procedures can return multiple values:

```csl
get_thing :: proc() -> Thing, bool {
    rng := rng_seed_time();
    if rng_range_float(ref rng, 0, 1) < 0.99 {
        return g_thing, true;
    }
    return {}, false;
}

main :: proc() {
    {
        // Simple usage
        thing, ok := get_thing();
        if ok {
            print("%", {thing});
        }
    }

    {
        // Inline declaration in if-statement
        if thing, ok := get_thing(); ok {
            print("%", {thing});
        }
    }

    {
        // Use `_` when you don't care about a value
        thing, _ := get_thing();
    }
}
```