# Basic Example

A complete example showing basic ZigX usage.

## Project Structure

```
basic_example/
├── pyproject.toml
├── src/
│   └── lib.zig
└── basic_example/
    └── __init__.py
```

## pyproject.toml

```toml
[project]
name = "basic_example"
version = "0.1.0"
description = "A basic ZigX example"
requires-python = ">=3.8"

[build-system]
requires = ["zigx"]
build-backend = "zigx.build"
```

## src/lib.zig

```zig
const std = @import("std");

/// Add two integers together
pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Subtract b from a
pub export fn subtract(a: i32, b: i32) i32 {
    return a - b;
}

/// Multiply two floating point numbers
pub export fn multiply(a: f64, b: f64) f64 {
    return a * b;
}

/// Divide a by b (returns NaN if b is 0)
pub export fn divide(a: f64, b: f64) f64 {
    if (b == 0) return std.math.nan(f64);
    return a / b;
}

/// Calculate the nth Fibonacci number
pub export fn fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const c = a + b;
        a = b;
        b = c;
    }
    return b;
}

/// Calculate factorial of n
pub export fn factorial(n: u32) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

/// Check if a number is prime
pub export fn is_prime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    
    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

/// Calculate greatest common divisor
pub export fn gcd(a: u64, b: u64) u64 {
    var x = a;
    var y = b;
    while (y != 0) {
        const temp = y;
        y = x % y;
        x = temp;
    }
    return x;
}
```

## Usage in Python

```python
import basic_example
import math

# Basic arithmetic
print(f"5 + 3 = {basic_example.add(5, 3)}")
print(f"10 - 4 = {basic_example.subtract(10, 4)}")
print(f"3.14 * 2 = {basic_example.multiply(3.14, 2.0)}")
print(f"10 / 3 = {basic_example.divide(10.0, 3.0)}")

# Check division by zero handling
result = basic_example.divide(1.0, 0.0)
print(f"1 / 0 = {result} (is NaN: {math.isnan(result)})")

# Fibonacci sequence
print("\nFibonacci sequence:")
for i in range(15):
    print(f"  fib({i}) = {basic_example.fibonacci(i)}")

# Factorials
print("\nFactorials:")
for i in range(10):
    print(f"  {i}! = {basic_example.factorial(i)}")

# Prime checking
print("\nPrime numbers up to 50:")
primes = [n for n in range(51) if basic_example.is_prime(n)]
print(f"  {primes}")

# GCD
print(f"\nGCD(48, 18) = {basic_example.gcd(48, 18)}")
print(f"GCD(100, 35) = {basic_example.gcd(100, 35)}")
```

## Output

```
5 + 3 = 8
10 - 4 = 6
3.14 * 2 = 6.28
10 / 3 = 3.3333333333333335
1 / 0 = nan (is NaN: True)

Fibonacci sequence:
  fib(0) = 0
  fib(1) = 1
  fib(2) = 1
  fib(3) = 2
  fib(4) = 3
  fib(5) = 5
  fib(6) = 8
  fib(7) = 13
  fib(8) = 21
  fib(9) = 34
  fib(10) = 55
  fib(11) = 89
  fib(12) = 144
  fib(13) = 233
  fib(14) = 377

Factorials:
  0! = 1
  1! = 1
  2! = 2
  3! = 6
  4! = 24
  5! = 120
  6! = 720
  7! = 5040
  8! = 40320
  9! = 362880

Prime numbers up to 50:
  [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]

GCD(48, 18) = 6
GCD(100, 35) = 5
```

## Building and Running

```bash
# Create and enter project
zigx new basic_example
cd basic_example

# Copy the lib.zig content above to src/lib.zig

# Build
zigx develop

# Run Python
python -c "import basic_example; print(basic_example.add(1, 2))"
```
