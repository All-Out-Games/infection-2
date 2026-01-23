---
name: format-strings
description: "Only read if you're struggling with debugging weird string formatting"
---
# String Formatting

CSL uses `format_string()` for string interpolation. The first argument is a format string, and arguments are passed in an array.

## Basic Usage

Use `%` as a placeholder for arguments:

```csl
name := "John";
str := format_string("hello: %", {name}); // "hello: John"

x := 10;
y := 20;
str := format_string("position: %, %", {x, y}); // "position: 10, 20"
```

## Literal Percent Signs

Use `%%` to output a literal `%`:

```csl
format_string("health: 100%%"); // "health: 100%"
```

## Arguments Next to Literal Percent

```csl
// THIS IS WRONG
hp := 67;
format_string("health: %%%", {hp}); // "health: %67"
```

The first two `%%` will insert a literal '%', and then the third `%` will perform an argument insertion. When you need an argument immediately followed by a literal `%`, use `%0` for the argument. `%0` is an alias for `%` but serves to disambiguate.

```csl
hp := 67;
format_string("health: %0%%", {hp}); // "health: 67%"
```

Here `%0` gets replaced by the next argument, and then the `%%` inserts a literal '%'.

`%0` is functionally equivalent to `%` in that it inserts the next argument, but just disambiguates when you need it as above where we want a literal percent after an argument insertion.

```csl
format_string("%0, %, %0, %,", 1, 2, 3, 4); // "1, 2, 3, 4"
```

## Formatting Integers with Leading Zeroes

Use `Format_Int` to pad integers with leading zeroes:

```csl
score := 42;
format_string("Score: %", {format_int(score, leading_zeroes=5)}); // "Score: 00042"

timer_minutes := 3;
timer_seconds := 7;
format_string("%:%", {format_int(timer_minutes, leading_zeroes=2), format_int(timer_seconds, leading_zeroes=2)}); // "03:07"
```

The `Format_Int` struct has two fields:
- `v: s64` - the integer value to format
- `leading_zeroes: s64` - minimum width, padded with zeros

## Formatting Floats with Decimal Precision

Use `Format_Float` to control decimal places and optional leading zeroes:

```csl
value := 3.14159;
format_string("pi: %", {format_float(value, decimals=2)}); // "pi: 3.14"

// Zero decimals for whole numbers
percent := 0.875;
format_string("%0%%", {format_float(percent * 100, decimals=0)}); // "88%"

// With leading zeroes (total width includes decimal point and decimal places)
time := 5.3;
format_string("%", {format_float(time, leading_zeroes=2, decimals=1)}); // "05.3"
```

The `Format_Float` struct has three fields:
- `v: f32` - the float value to format
- `leading_zeroes: s64` - minimum digits before decimal point (0 to disable)
- `decimals: s64` - number of decimal places to display

## Indexed Arguments

Use `%1`, `%2`, `%3`, etc. as one-based indices into the parameters array to reference arguments out of order or multiple times:

```csl
format_string("%3, %2, %1", {"a", "b", "c"}); // "c, b, a"

name := "Alice";
format_string("% said hello. % is friendly.", {name, name}); // works but repetitive
format_string("%1 said hello. %1 is friendly.", {name});     // cleaner with indices
```

## Error Handling

### Too Many Arguments

If you pass more arguments than placeholders, extra arguments are appended with a warning:

```csl
format_string("%", {123, 456}); // "123 %{ADDITIONAL ARG(S): (456)}"
```

### Too Few Arguments

If you don't pass enough arguments, unused `%` placeholders remain as literal `%` characters:

```csl
format_string("foo: %"); // "foo: %"
```

This behavior is intentional—it allows passing pre-formatted strings that happen to contain `%`:

```csl
health := "100%";
print(health); // "100%" (not an error)
```