double ieeeRemainder(double x, double y) {
  // Handle special cases
  if (x.isNaN || y.isNaN || y == 0.0 || x.isInfinite) {
    return double.nan;
  }
  if (y.isInfinite) {
    return x.isFinite ? x : double.nan;
  }
  if (x == 0.0) {
    return x; // Preserves sign of x (0.0 or -0.0)
  }

  // Compute quotient and round to nearest integer
  double quotient = x / y;
  double n = quotient.roundToDouble(); // Rounds to nearest, ties to even

  // Adjust n if quotient is exactly halfway between integers
  if ((quotient - n).abs() == 0.5) {
    // If tied, choose even integer
    if (n % 2 != 0) {
      n += quotient > n ? 1.0 : -1.0;
    }
  }

  // Compute remainder: x - y * n
  double remainder = x - y * n;

  // Ensure remainder is in [-y/2, y/2]
  double halfY = y.abs() / 2.0;
  if (remainder.abs() > halfY) {
    remainder -= y * (remainder > 0 ? 1.0 : -1.0);
  } else if (remainder.abs() == halfY && remainder != halfY) {
    // If remainder is exactly -y/2, adjust to y/2 for consistency
    remainder = halfY;
  }
  return remainder;
}
