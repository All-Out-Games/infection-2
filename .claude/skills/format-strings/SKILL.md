---
name: format-strings
description: "Only read if you're struggling with debugging weird string formatting"
---
# String Formatting

`format_string()` uses `%` as a placeholder. Arguments are passed in an array.

```csl
str := format_string("position: %, %", {x, y}); // "position: 10, 20"
```

## Literal Percent Signs

`%%` outputs a literal `%`:

```csl
format_string("health: 100%%"); // "health: 100%"
```

## `%0` Disambiguation

When an argument must appear immediately before a literal `%`, use `%0` (alias for `%`) to disambiguate:

```csl
hp := 67;
format_string("%0%%", {hp}); // "67%"
```

Without `%0`, writing `%%%` would parse as `%%` (literal %) then `%` (argument), producing `%67`.

## Format_Int and Format_Float

```csl
format_string("%", {format_int(42, leading_zeroes=5)});        // "00042"
format_string("%", {format_float(3.14159, decimals=2)});       // "3.14"
format_string("%", {format_float(5.3, leading_zeroes=2, decimals=1)}); // "05.3"
```

- `Format_Int`: fields `v: s64`, `leading_zeroes: s64`
- `Format_Float`: fields `v: f32`, `leading_zeroes: s64`, `decimals: s64`

## Indexed Arguments

`%1`, `%2`, `%3` etc. are one-based indices into the parameters array:

```csl
format_string("%3, %2, %1", {"a", "b", "c"}); // "c, b, a"
format_string("%1 said hello. %1 is friendly.", {name}); // reuse without repeating arg
```

## Error Handling

Extra arguments are appended with a warning:

```csl
format_string("%", {123, 456}); // "123 %{ADDITIONAL ARG(S): (456)}"
```

Too few arguments leave `%` as literal text (not an error). This allows strings containing `%` to pass through safely.
