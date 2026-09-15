---
name: syntax
description: When writing new CSL code reference these docs to understand the syntax of .csl files.
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
Define const with `::` Must be compile-time constant.

Global variable initializers must be compile-time constants. Zero-initialized file-scope vars are allowed for game-wide handles/registries, then assign them in `ao_start` or `ao_before_scene_load` for runtime init. Do not use globals for per-player state; store that on the player/component.

`PI` is already defined as a global.

## Types
### Primitive Types
- Signed integers: `s8`, `s16`, `s32`, `s64`
- Unsigned integers: `u8`, `u16`, `u32`, `u64`
- Booleans: `bool`
- Floats: `f32`, `f64`
- Aliases: `int` = `s64`, `uint` = `u64`, `float` = `f32` (use `f64` explicitly for doubles)
- Explicit numeric conversions use `expr.(T)`, not `T(expr)`: `value_f32 := value_f64.(f32);`
- Vector types: `v2`, `v3`, `v4` (float fields `.x`, `.y`, `.z`, `.w`; constructed with `v2{10, 20}`)
- `string`, `typeid`, `any`

### Numeric Literals
Integers: decimal or `0x` hex, with optional `_` separators (`1_000_000`). Floats need a decimal point; the leading zero is optional (`1.0`, `.25`, `-.5`). There is **no exponent form** — write `0.001`, not `1e-3`.

### Strings and Template Strings
`"..."` strings support backslash escapes (`\n`, `\t`, `\\`, ...). Backtick strings are raw (no backslash escapes, newlines allowed) and support `{expr}` interpolation:

```csl
name := "Ada";
count := 0;
msg := `Hi {name}, you have {count + 1} new messages`; // any expression works inside {}
```

String helpers (from `scripts/.ao_core/basic.csl`): `format_string(fmt, args)`, `string_trim(str)`, `string_substring(str, start, length)`, `string_split(str, delimiter) -> []string`, `copy_string(str)`, `format_int`/`format_float`. There is no `string_contains`/`index_of` yet; split or compare instead.

Strings concatenate with `+` and `+=`.

Strings compare only with `==`/`!=`. There is no `<`/`>` ordering and no compare builtin (`a < b` on strings fails with `Need a numeric type here`), so order players or ids on a numeric field instead.

- Interpolating templates compile to a `format_string` call, so they need `import "core:basic"` and are not compile-time constants.
- A backtick string with no `{expr}` stays a plain raw string constant.
- Literal braces: `{{` and `}}`. A single `}` in text is a compile error.
- Backtick strings cannot nest inside `{}` (use `"..."` strings there).

## Structs
Structs are value types (shallow-copied on assignment/pass).

```csl
Food_Definition :: struct {
    name: string;
    food_value: int;
}
```

## Classes: reference types allocated with `new`
```csl
Foo :: class {
    value: int;
    position: v2;
}

foo := new(Foo);
foo: Foo = new();
foo: Foo = new(Foo);
```

### Inheritance
```csl
Dog :: class : Animal {
    breed: string;
}
```

Derived methods with the same name shadow inherited methods; they do not override virtual procedures. Calls use the receiver's static type, so a base-typed value never selects a same-named method from its derived runtime type. Derived classes have a read-only `base` field that views the same object as its immediate parent type; use `base.method()` inside a shadowing derived method or `value.base.method()` to select the parent method explicitly. `base` is not reserved, so a local declaration can shadow it.

## Procedures
Use named `:: proc` declarations or distinct inline link names (`proc "intro_has_wood" (...)`) for callbacks. Multiple unnamed callbacks with the same signature in one scope have colliding hotload identities; assigning them to differently named `:=` variables does not name the procedures.

```csl
add :: proc(a: int, b: int) -> int {
    return a + b;
}
```

### Methods
```csl
Dog :: class {
    name: string;

    bark :: method() {
        log_info(`{name} says bark!`); // implicit this.name
    }
}

dog := new(Dog);
dog.bark();
```

### Arrays
- **Fixed**: `[N]T` initialized with `{...}`
- **Slice**: `[]T` a view into array data (common for parameters)
- **Dynamic**: `[..]T` resizable list (`.count`, `.capacity`); implicitly converts to `[]T`

```csl
fixed: [4]int = {1, 2, 3, 4};
spawn_points: [3]v2 = {{0, 0}, {5, 0}, {0, 5}};
dyn: [..]int = {1, 2, 3};
view: []int = dyn;

hit := Damage_Desc{amount=10, knockback={2, 1}}; // named fields use = not :
```

Allocate an array whose size is known at runtime with `new(Element_Type, count)`. The result is a `[]Element_Type` with the requested count:

```csl
scores := new(int, 3); // yields []int
scores[0] = 10;
scores[1] = 20;
scores[2] = 30;
```

### Dynamic Arrays
```csl
numbers: [..]int = {1, 2};
numbers.append(10);
numbers.pop();
numbers.clear();
numbers.reserve(64);

numbers.unordered_remove_by_value(10);
numbers.ordered_remove_by_value(999, .ALL); 
numbers.unordered_remove_by_index(0);
numbers.ordered_remove_by_index(0);
```

Dynamic-array literals accept runtime expressions and can be returned directly from a procedure whose result is `[..]T`. Class field defaults made from a dynamic-array literal are copied to independent mutable storage for each instance.

## Control Flow
Conditions normally omit parentheses. Enum values use `.` prefix in `switch`. `while cond { }` loops exist, and `break`/`continue` work in both `for` and `while`:

```csl
attempts := 0;
while attempts < 3 {
    attempts += 1;
    if attempts == 2 { continue; }
}
```

### Ternary Operator
Use `condition ? when_true : when_false` to select a value. The condition must be a `bool`, the branches must have compatible types, and only the selected branch is evaluated.

```csl
label := is_ready ? "Ready" : "Waiting";
```

### Compound literals in control-flow conditions
A compound literal immediately before a control-flow body is ambiguous. This is the exception to the normal no-parentheses style: disambiguate with `.{}`, `Type.{}`, or parentheses.

```csl
if value == .{} {}
if value == v2.{} {}
if (value == v2{}) {}
```

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
    case 4..10: tier = .INTERMEDIATE;
    case 11..20, 25, 30..50: tier = .ADVANCED;
    default: tier = .UNKNOWN;
}
```

Multi-statement bodies use braces
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

Do not write C-style fallthrough logic

`for` also handles custom iterators: `for player: component_iterator(My_Player) { }`
Numeric loops use `for i: 0..3 { }` (inclusive) or `for i: 0..<3 { }` (half-open), never `for i in ...` and never C-style `for i = 0; i < n; i += 1` (parse error `Expected ':'`). Add `#reverse` after the range to count down.

Custom iterator-based `for` loops require a `next :: method() -> bool` and a `current` field.

```csl
Item_Tier :: enum {
    COMMON;
    RARE;
}

if !#alive(target) return;

UI.push_screen_draw_context();
defer UI.pop_draw_context();
```

Class references are nullable. `obj == null` and `obj != null` only test whether the stored reference is null; use them when the object’s lifetime guarantees the reference cannot become stale. `#alive(obj)` tests whether the reference currently resolves and returns false for both null and destroyed objects. Use `#alive` before dereferencing engine-owned objects such as entities or components when they may have been destroyed independently.

`defer` runs a statement when the current scope exits.

## Type Casting
Use `expr.(T)` syntax: `b := 123.4.(int);`

Class casts must be between related types. Derived-to-base casts are free;
base-to-derived casts check the concrete runtime type and throw on mismatch.
Null class values remain null when downcast. Use `value.#type` when branching
among possible derived types.

## Parameter Passing: ref
Mark both the parameter and callsite with `ref`. When forwarding a ref param use `ref` again:

```csl
update_health :: proc(health: ref int, damage: int) {
    health -= damage;
}

hp := 100;
update_health(ref hp, 25);
```

Taking a raw address with `&` requires an `#unsafe` context; use `ref` for ordinary by-reference arguments. A single unbraced unsafe declaration remains in the surrounding scope.

## Polymorphic Procedures
`$T` on a parameter deduces the type from the callsite. `$T` is only used when **defining** polymorphic procs — callers always pass concrete types:

```csl
min :: proc(a: $T, b: T) -> T {
    if a < b return a;
    return b;
}

result := min(3, 5); // T is deduced as int
```

> `T` is a type only inside a polymorphic declaration that binds `$T`; it is not a generic placeholder elsewhere. In concrete code use the actual type name, such as `component_iterator(Enemy)` or `[..]Enemy`.

## Function Pointers and Callbacks

Proc literals can capture enclosing parameters and locals:

```csl
invoke_twice :: proc(callback: proc()) {
    callback();
    callback();
}

count_twice :: proc(initial: int) -> int {
    value := initial;
    invoke_twice(proc() {
        value += 1;
    });
    return value;
}
```

Capturing proc literals may only be invoked immediately or passed directly to a proc parameter that accepts captures. Such a parameter may only invoke the callback or forward it directly to another capture-accepting parameter. Capturing procedures cannot be assigned to variables, returned, or otherwise stored.

By default a proc parameter might contain captures. Mark it `#no_captures` when it must be stored, returned, or otherwise manipulated. Only non-capturing procedures may be passed to it; use explicit userdata for persistent state:

```csl
Callback_State :: class { value: int; }
Callback :: proc(userdata: Object);

saved: Callback;
saved_userdata: Object;

install :: proc(userdata: Object, #no_captures callback: Callback) {
    saved_userdata = userdata;
    saved = callback;
}

increment :: proc(userdata: Object) {
    userdata.(Callback_State).value += 1;
}
```

`#no_captures` is part of the receiving procedure's contract and can appear in procedure type aliases. Capturing and non-capturing values use the same two-word procedure/environment representation; plain procedures have a zero environment. Procedure values cannot be cast directly; deliberate low-level signature reinterpretation uses `#unsafe retyped := (&callback).(*Other_Callback).*`. Calls fail if that mechanism is used to pass captures to a `#no_captures` parameter.

## Using Keyword - access fields without a selector:
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

`#type_info(T)` returns reflection data. Use the returned value's `.id` field when logging or formatting the type name; `Type_Info` has no `printable_name` field.

## Multiple Return Values
Wrap multiple return types in parentheses, as in `proc() -> (Thing, bool)`.

```csl
get_thing :: proc() -> (Thing, bool) {
    return g_thing, true;
}

thing, ok := get_thing();
thing, ok = get_thing(); // Assign to existing destinations.
a, b = b, a;             // Or assign one expression per destination.
_, ok = get_thing();     // Ignore a result.
if thing, ok := get_thing(); ok { }
```

For `=`, the right side may be one multi-return expression or one expression per destination. The value count must match the destination count. Every right-hand expression is evaluated left to right before destinations are resolved or written, so `a, b = b, a` safely swaps the values. This comma-separated expression form is specific to assignment statements and does not create a general tuple value.
