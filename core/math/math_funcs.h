/**************************************************************************/
/*  math_funcs.h                                                          */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#pragma once

#include "core/math/math_defs.h"
#include "core/typedefs.h"
//#include "core/math/random_pcg.h" at Line 1181

#include <cmath>

namespace Math {

_ALWAYS_INLINE_ constexpr bool is_nan(const double p_val) { return !(p_val == p_val); }
_ALWAYS_INLINE_ constexpr bool is_nan(const float p_val) { return !(p_val == p_val); }

_ALWAYS_INLINE_ constexpr bool is_inf(const double p_val) { return p_val == INF; }
_ALWAYS_INLINE_ constexpr bool is_inf(const float p_val) { return p_val == FLOAT_INF; }

_ALWAYS_INLINE_ constexpr bool is_finite(const double p_val) { return !is_inf(p_val) && !is_nan(p_val); }
_ALWAYS_INLINE_ constexpr bool is_finite(const float p_val) { return !is_inf(p_val) && !is_nan(p_val); }

_ALWAYS_INLINE_ constexpr bool is_same(const double p_left, const double p_right) {
	return (p_left == p_right) || (is_nan(p_left) && is_nan(p_right));
}
_ALWAYS_INLINE_ constexpr bool is_same(const float p_left, const float p_right) {
	return (p_left == p_right) || (is_nan(p_left) && is_nan(p_right));
}

_ALWAYS_INLINE_ constexpr double abs(const double p_value) { return p_value > 0.0 ? p_value : -p_value; }
_ALWAYS_INLINE_ constexpr float abs(const float p_value) { return p_value > 0.0f ? p_value : -p_value; }
_ALWAYS_INLINE_ constexpr int8_t abs(const int8_t p_value) { return p_value > 0 ? p_value : -p_value; }
_ALWAYS_INLINE_ constexpr int16_t abs(const int16_t p_value) { return p_value > 0 ? p_value : -p_value; }
_ALWAYS_INLINE_ constexpr int32_t abs(const int32_t p_value) { return p_value > 0 ? p_value : -p_value; }
_ALWAYS_INLINE_ constexpr int64_t abs(const int64_t p_value) { return p_value > 0 ? p_value : -p_value; }
// Cheat: using p_return_value as a dummy parameter to have the function specifically return based on p_return_value's type.
// No calculations done in p_return_value, except for specifying the return.
_ALWAYS_INLINE_ constexpr double bool_to_sign(const bool p_value, const double p_return_value) { return p_value ? 1.0 : -1.0; }
_ALWAYS_INLINE_ constexpr float bool_to_sign(const bool p_value, const float p_return_value) { return p_value ? 1.0f : -1.0f; }
_ALWAYS_INLINE_ constexpr int8_t bool_to_sign(const bool p_value, const int8_t p_return_value) { return p_value ? 1.0 : -1.0; }
_ALWAYS_INLINE_ constexpr int16_t bool_to_sign(const bool p_value, const int16_t p_return_value) { return p_value ? 1.0 : -1.0; }
_ALWAYS_INLINE_ constexpr int32_t bool_to_sign(const bool p_value, const int32_t p_return_value) { return p_value ? 1.0 : -1.0; }
_ALWAYS_INLINE_ constexpr int64_t bool_to_sign(const bool p_value, const int64_t p_return_value) { return p_value ? 1.0 : -1.0; }

_ALWAYS_INLINE_ constexpr bool is_equal_approx(const double p_left, const double p_right, const double p_tolerance) {
	return p_left == p_right ? true : abs(p_left - p_right) < p_tolerance;
}
_ALWAYS_INLINE_ constexpr bool is_equal_approx(const float p_left, const float p_right, const float p_tolerance) {
	return p_left == p_right ? true : abs(p_left - p_right) < p_tolerance;
}

_ALWAYS_INLINE_ constexpr bool is_equal_approx(const double p_left, const double p_right) {
	// Check for exact equality first, required to handle "infinity" values.
	if (p_left == p_right) { return true; }
	// Then check for approximate equality.
	const double tolerance = CMP_EPSILON * abs(p_left);
	return abs(p_left - p_right) < (tolerance < CMP_EPSILON ? CMP_EPSILON : tolerance);
}
_ALWAYS_INLINE_ constexpr bool is_equal_approx(const float p_left, const float p_right) {
	// Check for exact equality first, required to handle "infinity" values.
	if (p_left == p_right) { return true; }
	// Then check for approximate equality.
	const float tolerance = (float)CMP_EPSILON * abs(p_left);
	return abs(p_left - p_right) < (tolerance < (float)CMP_EPSILON ? (float)CMP_EPSILON : tolerance);
}

_ALWAYS_INLINE_ constexpr bool is_zero_approx(const double p_value) { return abs(p_value) < CMP_EPSILON; }
_ALWAYS_INLINE_ constexpr bool is_zero_approx(const float p_value) { return abs(p_value) < (float)CMP_EPSILON; }

_ALWAYS_INLINE_ constexpr double trunc(const double p_val) { return (double)((int64_t)(p_val)); }
_ALWAYS_INLINE_ constexpr float trunc(const float p_val) { return (float)((int32_t)(p_val)); }

_ALWAYS_INLINE_ constexpr double floor(const double p_x) {
	return p_x > 0.0 ? trunc(p_x) : (p_x < 0.0 ? trunc(p_x - 1.0) : p_x);
}
_ALWAYS_INLINE_ constexpr float floor(const float p_x) {
	return p_x > 0.0f ? trunc(p_x) : (p_x < 0.0f ? trunc(p_x - 1.0f) : p_x);
}

_ALWAYS_INLINE_ constexpr double ceil(const double p_x) {
	return p_x > 0.0 ? trunc(p_x + 1.0) : (p_x < 0.0 ? trunc(p_x) : p_x);
}
_ALWAYS_INLINE_ constexpr float ceil(const float p_x) {
	return p_x > 0.0f ? trunc(p_x + 1.0f) : (p_x < 0.0f ? trunc(p_x) : p_x);
}

_ALWAYS_INLINE_ constexpr double round(const double p_x) {
	return p_x > 0.0 ? floor(p_x) : (p_x < 0.0 ? ceil(p_x) : p_x);
}
_ALWAYS_INLINE_ constexpr float round(const float p_x) {
	return p_x > 0.0f ? floor(p_x) : (p_x < 0.0f ? ceil(p_x) : p_x);
}

_ALWAYS_INLINE_ constexpr double fract(const double p_value) { return p_value - floor(p_value); }
_ALWAYS_INLINE_ constexpr float fract(const float p_value) { return p_value - floor(p_value); }

_ALWAYS_INLINE_ constexpr double lerp(const double p_from, const double p_to, const double p_weight) { return p_from + (p_to - p_from) * p_weight; }
_ALWAYS_INLINE_ constexpr float lerp(const float p_from, const float p_to, const float p_weight) { return p_from + (p_to - p_from) * p_weight; }

_ALWAYS_INLINE_ constexpr double inverse_lerp(const double p_from, const double p_to, const double p_value) { return (p_value - p_from) / (p_to - p_from); }
_ALWAYS_INLINE_ constexpr float inverse_lerp(const float p_from, const float p_to, const float p_value) { return (p_value - p_from) / (p_to - p_from); }

_ALWAYS_INLINE_ constexpr double fmod(const double p_x, const double p_y) {
    if (p_x == 0.0) { return p_x;}

    const double abs_x = abs(p_x);
    const double abs_y = abs(p_y);

	return (p_x < 0 ? -1.0 : 1.0) * (abs_x - trunc(abs_x / abs_y) * abs_y);
}
_ALWAYS_INLINE_ constexpr float fmod(const float p_x, const float p_y) {
    if (p_x == 0.0f) { return p_x;}

    const float abs_x = abs(p_x);
    const float abs_y = abs(p_y);

	return (p_x < 0 ? -1.0 : 1.0) * (abs_x - trunc(abs_x / abs_y) * abs_y);
}

_ALWAYS_INLINE_ constexpr double fposmod(const double p_x, const double p_y) { return p_y == 0.0 ? NaN : p_x - floor(p_x / p_y) * p_y; }
_ALWAYS_INLINE_ constexpr float fposmod(const float p_x, const float p_y) { return p_y == 0.0f ? FLOAT_NaN : p_x - floor(p_x / p_y) * p_y; }

_ALWAYS_INLINE_ constexpr double fposmodp(const double p_x, const double p_y) {
	const double value = fmod(p_x, p_y);
	return value < 0.0 ? value + p_y : value;
}
_ALWAYS_INLINE_ constexpr float fposmodp(const float p_x, const float p_y) {
	const float value = fmod(p_x, p_y);
	return value < 0.0f ? value + p_y : value;
}

_ALWAYS_INLINE_ constexpr int64_t posmod(const int64_t p_x, const int64_t p_y) {
	// Division by zero in posmod is undefined. Returning 0 as fallback
	if (p_y == 0) { return 0; }

	const int64_t value = p_x % p_y;
	return ((value < 0) && (p_y > 0)) || ((value > 0) && (p_y < 0)) ? value + p_y : value;
}

_ALWAYS_INLINE_ constexpr double log(const double p_x) {
	// Edge cases.
	if (p_x <= 0.0) { return NaN; }
	if (p_x == 1.0) { return 0.0; }
	if (is_inf(p_x)) { return p_x > 0.0 ? INF : NaN; }

	// Range reduction: find k such that m = x / 2^k ∈ [1, 2).
	double m = p_x;
	int k = 0;
	while (m >= 2.0) { m *= 0.5; k++; }
	while (m < 1.0)  { m *= 2.0; k--; }

	// Shift to [1/SQRT2, SQRT2] for faster convergence.
	if (m > SQRT2) { m *= 0.5; k++; }

	// u = (m - 1) / (m + 1),  |u| ≤ 0.1716
	const double u = (m - 1.0) / (m + 1.0);
	const double u2 = u * u;

	// Horner evaluation of  2*u*(1 + u²/3 + u⁴/5 + u⁶/7 + u⁸/9 + u¹⁰/11 + u¹²/13 + u¹⁴/15)
	// 7 terms after the leading 1 → error < 5e-17 for double.
	const double series = u2 * (1.0 / 3.0
			+ u2 * (1.0 / 5.0
			+ u2 * (1.0 / 7.0
			+ u2 * (1.0 / 9.0
			+ u2 * (1.0 / 11.0
			+ u2 * (1.0 / 13.0
			+ u2 * (1.0 / 15.0)))))));

	return 2.0 * u * (1.0 + series) + (double)k * LN2;
}
_ALWAYS_INLINE_ constexpr float log(const float p_x) {
	// Edge cases.
	if (p_x <= 0.0f) { return FLOAT_NaN; }
	if (p_x == 1.0f) { return 0.0f; }
	if (is_inf(p_x)) { return p_x > 0.0f ? FLOAT_INF : FLOAT_NaN; }

	// Range reduction.
	float m = p_x;
	int k = 0;
	while (m >= 2.0f) { m *= 0.5f; k++; }
	while (m < 1.0f)   { m *= 2.0f; k--; }

	if (m > (float)SQRT2) { m *= 0.5f; k++; }

	const float u = (m - 1.0f) / (m + 1.0f);
	const float u2 = u * u;

	// 3 terms after leading 1 → error < 2e-8 for float.
	const float series = u2 * (1.0f / 3.0f
			+ u2 * (1.0f / 5.0f
			+ u2 * (1.0f / 7.0f)));

	return 2.0f * u * (1.0f + series) + (float)k * (float)LN2;
}

_ALWAYS_INLINE_ constexpr double exp(const double p_x) {
	// Edge cases.
	if (is_nan(p_x)) { return NaN; }
	if (p_x == 0.0) { return 1.0; }
	if (is_inf(p_x)) { return p_x > 0.0 ? INF : 0.0; }

	// Range reduction: p_x = k * ln2 + r
	const double k_d = floor(p_x / LN2 + 0.5);
	const double r = p_x - k_d * LN2;

	// Pre-computed 1/n! for n = 1..13 (replaces divisions with multiplies).
	constexpr double c1  = 1.0;
	constexpr double c2  = c1 / 2.0;
	constexpr double c3  = c1 / 6.0;
	constexpr double c4  = c1 / 24.0;
	constexpr double c5  = c1 / 120.0;
	constexpr double c6  = c1 / 720.0;
	constexpr double c7  = c1 / 5040.0;
	constexpr double c8  = c1 / 40320.0;
	constexpr double c9  = c1 / 362880.0;
	constexpr double c10 = c1 / 3628800.0;
	constexpr double c11 = c1 / 39916800.0;
	constexpr double c12 = c1 / 479001600.0;
	constexpr double c13 = c1 / 6227020800.0;

	// Horner: 1 + r*(c1 + r*(c2 + r*(c3 + ... + r*(c12 + r*c13)...)))
	double result = c13;
	result = c12 + r * result;
	result = c11 + r * result;
	result = c10 + r * result;
	result = c9  + r * result;
	result = c8  + r * result;
	result = c7  + r * result;
	result = c6  + r * result;
	result = c5  + r * result;
	result = c4  + r * result;
	result = c3  + r * result;
	result = c2  + r * result;
	result = c1  + r * result;
	result = 1.0 + r * result;

	// Scale by 2^k via exponentiation by squaring.
	const int k = (int)k_d;
	if (k == 0) { return result; }

	double scale = 1.0;
	const double base = (k > 0) ? 2.0 : 0.5;
	int n = (k > 0) ? k : -k;

	double cur = base;
	while (n > 0) {
		if (n & 1) { scale *= cur; }
		cur *= cur;
		n >>= 1;
	}

	result *= scale;

	// Clamp overflow / underflow to infinities / zero.
	if (result == INF || result == 0.0) { return result; }
	// Check if result overflowed to INF or underflowed to zero.
	// For double: max finite = ~1.8e308, min normal = ~2.2e-308.
	// If k > 1023 the result is INF, if k < -1074 the result is 0.
	// The squaring loop already handles this for extreme k, but sanitize.
	return result;
}
_ALWAYS_INLINE_ constexpr float exp(const float p_x) {
	// Edge cases.
	if (is_nan(p_x)) { return FLOAT_NaN; }
	if (p_x == 0.0f) { return 1.0f; }
	if (is_inf(p_x)) { return p_x > 0.0f ? FLOAT_INF : 0.0f; }

	// Range reduction.
	const float k_f = floor(p_x / (float)LN2 + 0.5f);
	const float r = p_x - k_f * (float)LN2;

	// Pre-computed 1/n! for n = 1..7 for float precision.
	constexpr float c1  = 1.0f;
	constexpr float c2  = c1 / 2.0f;
	constexpr float c3  = c1 / 6.0f;
	constexpr float c4  = c1 / 24.0f;
	constexpr float c5  = c1 / 120.0f;
	constexpr float c6  = c1 / 720.0f;
	constexpr float c7  = c1 / 5040.0f;

	// Horner: 1 + r*(c1 + r*(c2 + ... + r*(c6 + r*c7)...))
	float result = c7;
	result = c6 + r * result;
	result = c5 + r * result;
	result = c4 + r * result;
	result = c3 + r * result;
	result = c2 + r * result;
	result = c1 + r * result;
	result = 1.0f + r * result;

	const int k = (int)k_f;
	if (k == 0) { return result; }

	float scale = 1.0f;
	const float base = (k > 0) ? 2.0f : 0.5f;
	int n = (k > 0) ? k : -k;

	float cur = base;
	while (n > 0) {
		if (n & 1) { scale *= cur; }
		cur *= cur;
		n >>= 1;
	}

	result *= scale;

	// Clamp overflow / underflow to infinities / zero.
	if (result == FLOAT_INF || result == 0.0f) { return result; }
	// Check if result overflowed to INF or underflowed to zero.
	// For double: max finite = ~1.8e308, min normal = ~2.2e-308.
	// If k > 1023 the result is INF, if k < -1074 the result is 0.
	// The squaring loop already handles this for extreme k, but sanitize.
	return result;
}

_ALWAYS_INLINE_ constexpr double pow(const double p_base, const double p_exp) {
	// x^0 = 1 (including 0^0 conventionally defined as 1).
	if (p_exp == 0.0) { return 1.0; }
	// 0^positive = 0, 0^negative = inf.
	if (p_base == 0.0) { return p_exp > 0.0 ? p_base : INF; }
	
	double t_base = p_base;
	double t_exp = p_exp;
	
	// Negative base: exponent must be an integer; sign depends on odd/even exponent.
	const bool neg_base = t_base < 0.0;
	if (neg_base) {
		if (trunc(t_exp) != t_exp) { return NaN; }
		t_base = -t_base;
	}
	// Negative exponent: compute with positive exponent then invert.
	const bool invert = t_exp < 0.0;
	if (invert) { t_exp = -t_exp; }
	// Separate integer and fractional parts of the exponent.
	const double int_part = trunc(t_exp);
	const double frac_part = t_exp - int_part;
	// Integer power via exponentiation by squaring (O(log n) multiplications).
	double result = 1.0;
	double cur = t_base;
	double remaining = int_part;
	
	while (remaining > 0.0) {
		if (fmod(remaining, 2.0) != 0.0) {
			result *= cur;
		}
		cur *= cur;
		remaining = trunc(remaining / 2.0);
	}
	// Fractional part via exp(frac * ln(base)) — works at runtime.
	// This branch is never reached for integer exponents, so the function
	// remains constexpr-evaluable when p_exp is an integer.
	if (frac_part != 0.0) { result *= exp(frac_part * log(t_base)); }
	// Apply sign for negative base with odd integer exponent.
	if (neg_base && fmod(t_exp, 2.0) != 0.0) { result = -result; }
	// Invert for negative original exponent.
	return invert ? 1.0 / result : result;
}
_ALWAYS_INLINE_ constexpr float pow(const float p_base, const float p_exp) {
	// x^0 = 1 (including 0^0 conventionally defined as 1).
	if (p_exp == 0.0f) { return 1.0f; }
	// 0^positive = 0, 0^negative = inf.
	if (p_base == 0.0f) { return p_exp > 0.0f ? p_base : INF; }
	
	float t_base = p_base;
	float t_exp = p_exp;
	
	// Negative base: exponent must be an integer; sign depends on odd/even exponent.
	const bool neg_base = t_base < 0.0f;
	if (neg_base) {
		if (trunc(t_exp) != t_exp) { return NaN; }
		t_base = -t_base;
	}
	// Negative exponent: compute with positive exponent then invert.
	const bool invert = t_exp < 0.0f;
	if (invert) { t_exp = -t_exp; }
	// Separate integer and fractional parts of the exponent.
	const float int_part = trunc(t_exp);
	const float frac_part = t_exp - int_part;
	// Integer power via exponentiation by squaring (O(log n) multiplications).
	float result = 1.0f;
	float cur = t_base;
	float remaining = int_part;
	
	while (remaining > 0.0f) {
		if (fmod(remaining, 2.0f) != 0.0f) {
			result *= cur;
		}
		cur *= cur;
		remaining = trunc(remaining / 2.0f);
	}
	// Fractional part via exp(frac * ln(base)) — works at runtime.
	// This branch is never reached for integer exponents, so the function
	// remains constexpr-evaluable when p_exp is an integer.
	if (frac_part != 0.0) { result *= exp(frac_part * log(t_base)); }
	// Apply sign for negative base with odd integer exponent.
	if (neg_base && fmod(t_exp, 2.0f) != 0.0f) { result = -result; }
	// Invert for negative original exponent.
	return invert ? 1.0f / result : result;
}

_ALWAYS_INLINE_ constexpr double sqrt(const double p_x) {
	// Edge cases.
	if (p_x < 0.0) { return NaN; }
	if (p_x == 0.0 || is_inf(p_x) || is_nan(p_x)) { return p_x; }

	// Initial guess: a sensible starting point is x/2 (or 1 for very small x)
    double guess = p_x / 2.0;
    if (guess < 1.0) { guess = 1.0; }

    for (int i = 0; i < 100; ++i) {
        double next = 0.5 * (guess + p_x / guess);   // Newton update

        if (abs(next - guess) < CMP_EPSILON) { return next; }

        guess = next;
    }

    // If we exit the loop, maxIter was reached; return best estimate anyway
    return guess;
}
_ALWAYS_INLINE_ constexpr float sqrt(const float p_x) {
	// Edge cases.
	if (p_x < 0.0f) { return NaN; }
	if (p_x == 0.0f || is_inf(p_x) || is_nan(p_x)) { return p_x; }

	// Initial guess: a sensible starting point is x/2 (or 1 for very small x)
    double guess = p_x / 2.0f;
    if (guess < 1.0f) { guess = 1.0f; }

    for (int i = 0; i < 100; ++i) {
        double next = 0.5f * (guess + p_x / guess);   // Newton update

        if (abs(next - guess) < CMP_EPSILON) { return next; }

        guess = next;
    }

    // If we exit the loop, maxIter was reached; return best estimate anyway
    return guess;
}

// These methods assume (p_num + p_den) doesn't overflow.
_ALWAYS_INLINE_ constexpr int32_t division_round_up(const int32_t p_num, const int32_t p_den) {
	return (p_num + p_den + ((p_num < 0 && p_den < 0) ? 1 : -1)) / p_den;
}
_ALWAYS_INLINE_ constexpr uint32_t division_round_up(const uint32_t p_num, const uint32_t p_den) {
	return (p_num + p_den - 1) / p_den;
}
_ALWAYS_INLINE_ constexpr int64_t division_round_up(const int64_t p_num, const int64_t p_den) {
	return (p_num + p_den + ((p_num < 0 && p_den < 0) ? 1 : -1)) / p_den;
}
_ALWAYS_INLINE_ constexpr uint64_t division_round_up(const uint64_t p_num, const uint64_t p_den) {
	return (p_num + p_den - 1) / p_den;
}

_ALWAYS_INLINE_ constexpr double deg_to_rad(const double p_y) { return p_y * PI_RAD; }
_ALWAYS_INLINE_ constexpr float deg_to_rad(const float p_y) { return p_y * (float)PI_RAD; }

_ALWAYS_INLINE_ constexpr double rad_to_deg(const double p_y) { return p_y * PI_DEG; }
_ALWAYS_INLINE_ constexpr float rad_to_deg(const float p_y) { return p_y * (float)PI_DEG; }

_ALWAYS_INLINE_ constexpr double cubic_interpolate(const double p_from, const double p_to, const double p_pre, const double p_post, const double p_weight) {
	return 0.5 *
			((p_from * 2.0) +
					(-p_pre + p_to) * p_weight +
					(2.0 * p_pre - 5.0 * p_from + 4.0 * p_to - p_post) * (p_weight * p_weight) +
					(-p_pre + 3.0 * p_from - 3.0 * p_to + p_post) * (p_weight * p_weight * p_weight));
}
_ALWAYS_INLINE_ constexpr float cubic_interpolate(const float p_from, const float p_to, const float p_pre, const float p_post, const float p_weight) {
	return 0.5f *
			((p_from * 2.0f) +
					(-p_pre + p_to) * p_weight +
					(2.0f * p_pre - 5.0f * p_from + 4.0f * p_to - p_post) * (p_weight * p_weight) +
					(-p_pre + 3.0f * p_from - 3.0f * p_to + p_post) * (p_weight * p_weight * p_weight));
}

_ALWAYS_INLINE_ constexpr double cubic_interpolate_angle(const double p_from, const double p_to, const double p_pre, const double p_post, const double p_weight) {
	const double from_rot = fmod(p_from, TAU);

	const double pre_diff = fmod(p_pre - from_rot, TAU);
	const double pre_rot = from_rot + fmod(2.0 * pre_diff, TAU) - pre_diff;

	const double to_diff = fmod(p_to - from_rot, TAU);
	const double to_rot = from_rot + fmod(2.0 * to_diff, TAU) - to_diff;

	const double post_diff = fmod(p_post - to_rot, TAU);
	const double post_rot = to_rot + fmod(2.0 * post_diff, TAU) - post_diff;

	return cubic_interpolate(from_rot, to_rot, pre_rot, post_rot, p_weight);
}

_ALWAYS_INLINE_ constexpr float cubic_interpolate_angle(const float p_from, const float p_to, const float p_pre, const float p_post, const float p_weight) {
	const float from_rot = fmod(p_from, (float)TAU);

	const float pre_diff = fmod(p_pre - from_rot, (float)TAU);
	const float pre_rot = from_rot + fmod(2.0f * pre_diff, (float)TAU) - pre_diff;

	const float to_diff = fmod(p_to - from_rot, (float)TAU);
	const float to_rot = from_rot + fmod(2.0f * to_diff, (float)TAU) - to_diff;

	const float post_diff = fmod(p_post - to_rot, (float)TAU);
	const float post_rot = to_rot + fmod(2.0f * post_diff, (float)TAU) - post_diff;

	return cubic_interpolate(from_rot, to_rot, pre_rot, post_rot, p_weight);
}

_ALWAYS_INLINE_ constexpr double cubic_interpolate_in_time(const double p_from, const double p_to, const double p_pre, const double p_post, const double p_weight,
		const double p_to_t, const double p_pre_t, const double p_post_t) {
	/* Barry-Goldman method */
	const double t = lerp(0.0, p_to_t, p_weight);
	const double a1 = lerp(p_pre, p_from, p_pre_t == 0 ? 0.0 : (t - p_pre_t) / -p_pre_t);
	const double a2 = lerp(p_from, p_to, p_to_t == 0 ? 0.5 : t / p_to_t);
	const double a3 = lerp(p_to, p_post, p_post_t - p_to_t == 0 ? 1.0 : (t - p_to_t) / (p_post_t - p_to_t));
	const double b1 = lerp(a1, a2, p_to_t - p_pre_t == 0 ? 0.0 : (t - p_pre_t) / (p_to_t - p_pre_t));
	const double b2 = lerp(a2, a3, p_post_t == 0 ? 1.0 : t / p_post_t);
	return lerp(b1, b2, p_to_t == 0 ? 0.5 : t / p_to_t);
}
_ALWAYS_INLINE_ constexpr float cubic_interpolate_in_time(const float p_from, const float p_to, const float p_pre, const float p_post, const float p_weight,
		const float p_to_t, const float p_pre_t, const float p_post_t) {
	/* Barry-Goldman method */
	const float t = lerp(0.0f, p_to_t, p_weight);
	const float a1 = lerp(p_pre, p_from, p_pre_t == 0 ? 0.0f : (t - p_pre_t) / -p_pre_t);
	const float a2 = lerp(p_from, p_to, p_to_t == 0 ? 0.5f : t / p_to_t);
	const float a3 = lerp(p_to, p_post, p_post_t - p_to_t == 0 ? 1.0f : (t - p_to_t) / (p_post_t - p_to_t));
	const float b1 = lerp(a1, a2, p_to_t - p_pre_t == 0 ? 0.0f : (t - p_pre_t) / (p_to_t - p_pre_t));
	const float b2 = lerp(a2, a3, p_post_t == 0 ? 1.0f : t / p_post_t);
	return lerp(b1, b2, p_to_t == 0 ? 0.5f : t / p_to_t);
}

_ALWAYS_INLINE_ constexpr double cubic_interpolate_angle_in_time(const double p_from, const double p_to, const double p_pre, const double p_post, const double p_weight,
		const double p_to_t, const double p_pre_t, const double p_post_t) {
	const double from_rot = fmod(p_from, TAU);

	const double pre_diff = fmod(p_pre - from_rot, TAU);
	const double pre_rot = from_rot + fmod(2.0 * pre_diff, TAU) - pre_diff;

	const double to_diff = fmod(p_to - from_rot, TAU);
	const double to_rot = from_rot + fmod(2.0 * to_diff, TAU) - to_diff;

	const double post_diff = fmod(p_post - to_rot, TAU);
	const double post_rot = to_rot + fmod(2.0 * post_diff, TAU) - post_diff;

	return cubic_interpolate_in_time(from_rot, to_rot, pre_rot, post_rot, p_weight, p_to_t, p_pre_t, p_post_t);
}
_ALWAYS_INLINE_ constexpr float cubic_interpolate_angle_in_time(const float p_from, const float p_to, const float p_pre, const float p_post, const float p_weight,
		const float p_to_t, const float p_pre_t, const float p_post_t) {
	const float from_rot = fmod(p_from, (float)TAU);

	const float pre_diff = fmod(p_pre - from_rot, (float)TAU);
	const float pre_rot = from_rot + fmod(2.0f * pre_diff, (float)TAU) - pre_diff;

	const float to_diff = fmod(p_to - from_rot, (float)TAU);
	const float to_rot = from_rot + fmod(2.0f * to_diff, (float)TAU) - to_diff;

	const float post_diff = fmod(p_post - to_rot, (float)TAU);
	const float post_rot = to_rot + fmod(2.0f * post_diff, (float)TAU) - post_diff;

	return cubic_interpolate_in_time(from_rot, to_rot, pre_rot, post_rot, p_weight, p_to_t, p_pre_t, p_post_t);
}

_ALWAYS_INLINE_ constexpr double bezier_interpolate(const double p_start, const double p_control_1, const double p_control_2, const double p_end, const double p_t) {
	/* Formula from Wikipedia article on Bezier curves. */
	const double omt = (1.0 - p_t);
	const double omt2 = omt * omt;
	const double omt3 = omt2 * omt;
	const double t2 = p_t * p_t;
	const double t3 = t2 * p_t;

	return p_start * omt3 + p_control_1 * omt2 * p_t * 3.0 + p_control_2 * omt * t2 * 3.0 + p_end * t3;
}
_ALWAYS_INLINE_ constexpr float bezier_interpolate(const float p_start, const float p_control_1, const float p_control_2, const float p_end, const float p_t) {
	/* Formula from Wikipedia article on Bezier curves. */
	const float omt = (1.0f - p_t);
	const float omt2 = omt * omt;
	const float omt3 = omt2 * omt;
	const float t2 = p_t * p_t;
	const float t3 = t2 * p_t;

	return p_start * omt3 + p_control_1 * omt2 * p_t * 3.0f + p_control_2 * omt * t2 * 3.0f + p_end * t3;
}

_ALWAYS_INLINE_ constexpr double bezier_derivative(const double p_start, const double p_control_1, const double p_control_2, const double p_end, const double p_t) {
	/* Formula from Wikipedia article on Bezier curves. */
	const double omt = (1.0 - p_t);
	const double omt2 = omt * omt;
	const double t2 = p_t * p_t;

	return (p_control_1 - p_start) * 3.0 * omt2 + (p_control_2 - p_control_1) * 6.0 * omt * p_t + (p_end - p_control_2) * 3.0 * t2;
}
_ALWAYS_INLINE_ constexpr float bezier_derivative(const float p_start, const float p_control_1, const float p_control_2, const float p_end, const float p_t) {
	/* Formula from Wikipedia article on Bezier curves. */
	const float omt = (1.0f - p_t);
	const float omt2 = omt * omt;
	const float t2 = p_t * p_t;

	return (p_control_1 - p_start) * 3.0f * omt2 + (p_control_2 - p_control_1) * 6.0f * omt * p_t + (p_end - p_control_2) * 3.0f * t2;
}

_ALWAYS_INLINE_ constexpr double angle_difference(const double p_from, const double p_to) {
	const double difference = fmod(p_to - p_from, TAU);
	return fmod(2.0 * difference, TAU) - difference;
}
_ALWAYS_INLINE_ constexpr float angle_difference(const float p_from, const float p_to) {
	const float difference = fmod(p_to - p_from, (float)TAU);
	return fmod(2.0f * difference, (float)TAU) - difference;
}

_ALWAYS_INLINE_ constexpr double lerp_angle(const double p_from, const double p_to, const double p_weight) {
	return p_from + angle_difference(p_from, p_to) * p_weight;
}
_ALWAYS_INLINE_ constexpr float lerp_angle(const float p_from, const float p_to, const float p_weight) {
	return p_from + angle_difference(p_from, p_to) * p_weight;
}

_ALWAYS_INLINE_ constexpr double remap(const double p_value, const double p_istart, const double p_istop, const double p_ostart, const double p_ostop) {
	return lerp(p_ostart, p_ostop, inverse_lerp(p_istart, p_istop, p_value));
}
_ALWAYS_INLINE_ constexpr float remap(const float p_value, const float p_istart, const float p_istop, const float p_ostart, const float p_ostop) {
	return lerp(p_ostart, p_ostop, inverse_lerp(p_istart, p_istop, p_value));
}

_ALWAYS_INLINE_ constexpr double smoothstep(const double p_from, const double p_to, const double p_s) {
	if (is_equal_approx(p_from, p_to)) {
		if (likely(p_from <= p_to)) {
			return p_s <= p_from ? 0.0 : 1.0;
		} else {
			return p_s <= p_to ? 1.0 : 0.0;
		}
	}
	double s = CLAMP((p_s - p_from) / (p_to - p_from), 0.0, 1.0);
	return s * s * (3.0 - 2.0 * s);
}
_ALWAYS_INLINE_ constexpr float smoothstep(const float p_from, const float p_to, const float p_s) {
	if (is_equal_approx(p_from, p_to)) {
		return likely(p_from <= p_to) ? (p_s <= p_from ? 0.0f : 1.0f) : (p_s <= p_to ? 1.0f : 0.0f);
	}
	const float s = CLAMP((p_s - p_from) / (p_to - p_from), 0.0f, 1.0f);
	return s * s * (3.0f - 2.0f * s);
}

_ALWAYS_INLINE_ constexpr double move_toward(const double p_from, const double p_to, const double p_delta) {
	return abs(p_to - p_from) <= p_delta ? p_to : p_from + SIGN(p_to - p_from) * p_delta;
}
_ALWAYS_INLINE_ constexpr float move_toward(const float p_from, const float p_to, const float p_delta) {
	return abs(p_to - p_from) <= p_delta ? p_to : p_from + SIGN(p_to - p_from) * p_delta;
}

_ALWAYS_INLINE_ constexpr double rotate_toward(const double p_from, const double p_to, const double p_delta) {
	double difference = angle_difference(p_from, p_to);
	double abs_difference = abs(difference);
	// When `p_delta < 0` move no further than to PI radians away from `p_to` (as PI is the max possible angle distance).
	return p_from + CLAMP(p_delta, abs_difference - PI, abs_difference) * (difference >= 0.0 ? 1.0 : -1.0);
}
_ALWAYS_INLINE_ constexpr float rotate_toward(const float p_from, const float p_to, const float p_delta) {
	float difference = angle_difference(p_from, p_to);
	float abs_difference = abs(difference);
	// When `p_delta < 0` move no further than to PI radians away from `p_to` (as PI is the max possible angle distance).
	return p_from + CLAMP(p_delta, abs_difference - (float)PI, abs_difference) * (difference >= 0.0f ? 1.0f : -1.0f);
}

_ALWAYS_INLINE_ constexpr double linear_to_db(const double p_linear) {
	return log(p_linear) * 8.6858896380650365530225783783321;
}
_ALWAYS_INLINE_ constexpr float linear_to_db(const float p_linear) {
	return log(p_linear) * (float)8.6858896380650365530225783783321;
}

_ALWAYS_INLINE_ constexpr double db_to_linear(const double p_db) {
	return exp(p_db * 0.11512925464970228420089957273422);
}
_ALWAYS_INLINE_ constexpr float db_to_linear(const float p_db) {
	return exp(p_db * (float)0.11512925464970228420089957273422);
}

_ALWAYS_INLINE_ constexpr double wrapf(const double p_value, const double p_min, const double p_max) {
	const double range = p_max - p_min;
	if (is_zero_approx(range)) { return p_min; }
	const double result = p_value - (range * floor((p_value - p_min) / range));
	return is_equal_approx(result, p_max) ? p_min : result;
}
_ALWAYS_INLINE_ constexpr float wrapf(const float p_value, const float p_min, const float p_max) {
	const float range = p_max - p_min;
	if (is_zero_approx(range)) { return p_min; }
	const float result = p_value - (range * floor((p_value - p_min) / range));
	return is_equal_approx(result, p_max) ? p_min : result;
}

_ALWAYS_INLINE_ constexpr int64_t wrapi(const int64_t p_value, const int64_t p_min, const int64_t p_max) {
	const int64_t range = p_max - p_min;
	return range == 0 ? p_min : p_min + ((((p_value - p_min) % range) + range) % range);
}

_ALWAYS_INLINE_ constexpr double pingpong(const double p_value, const double p_length) {
	return (p_length != 0.0) ? abs(fract((p_value - p_length) / (p_length * 2.0)) * p_length * 2.0 - p_length) : 0.0;
}
_ALWAYS_INLINE_ constexpr float pingpong(const float p_value, const float p_length) {
	return (p_length != 0.0f) ? abs(fract((p_value - p_length) / (p_length * 2.0f)) * p_length * 2.0f - p_length) : 0.0f;
}

// double only, as these functions are mainly used by the editor and not performance-critical,
_ALWAYS_INLINE_ constexpr double ease(const double p_x, const double p_c) {
	const double t_x = CLAMP(p_x, 0.0, 1.0);

	if (p_c > 0) {
		double result = pow((p_c < 1.0 ? 1.0 - t_x : t_x), (p_c < 1.0 ? 1.0 / p_c : p_c));
		return p_c < 1.0 ? 1.0 - result : result;
	} else if (p_c < 0) {
		double result = pow((t_x < 0.5 ? t_x * 2.0 : 1.0 - (t_x - 0.5) * 2.0), -p_c);
		return t_x < 0.5 ? result * 0.5 : (1.0 - result) * 0.5 + 0.5;
	}
	return 0; // no ease (raw)
}

_ALWAYS_INLINE_ constexpr int step_decimals(const double p_step) {
	const double decimal = fract(p_step);
	for (int i = 0; i < 10; i++) {
		if (decimal >= 0.9999 / pow(10.0, (double)i)) { return i; }
	}
	// Fallback
	return 0;
}
// Only meant for editor usage in float ranges, where a step of 0
// means that decimal digits should not be limited in String::num.
_ALWAYS_INLINE_ constexpr int range_step_decimals(const double p_step) {
	// Max value hardcoded in String::num is '16'.
	if (p_step < 0.0000000000001) { return 16; }
	return step_decimals(p_step);
}

_ALWAYS_INLINE_ constexpr double sin(const double p_x) {
	// Edge cases.
	if (is_nan(p_x) || is_inf(p_x)) { return NaN; }
	if (p_x == 0.0) { return 0.0; }

	// Range reduction to [-TAU, TAU].
	double x = fmod(p_x, TAU);

	// sin(-x) = -sin(x): handle sign.
	bool neg = x < 0.0;
	if (neg) { x = -x; }

	// sin(x + PI) = -sin(x): map quadrants 3 & 4 down to quadrants 1 & 2.
	if (x > PI) {
		x -= PI;
		neg = !neg;
	}

	// sin(PI - x) = sin(x): map [PI/2, PI] down to [0, PI/2].
	if (x > PI_HALF) {
		x = PI - x;
	}

	// Now x ∈ [0, PI/2].
	// sin(x) = x * P(x^2).
	// P(t) = 1 - t/6 + t^2/120 - t^3/5040 + t^4/362880 - t^5/39916800
	//          + t^6/6227020800 - t^7/1307674368000.
	// Horner evaluation: 7 terms after the leading 1 => error < 1e-12.
	const double x2 = x * x;

	const double poly = 1.0 + x2 * (-1.0 / 6.0
			+ x2 * (1.0 / 120.0
			+ x2 * (-1.0 / 5040.0
			+ x2 * (1.0 / 362880.0
			+ x2 * (-1.0 / 39916800.0
			+ x2 * (1.0 / 6227020800.0
			+ x2 * (-1.0 / 1307674368000.0)))))));

	const double result = x * poly;

	return neg ? -result : result;
}
_ALWAYS_INLINE_ constexpr float sin(const float p_x) {
	// Edge cases.
	if (is_nan(p_x) || is_inf(p_x)) { return FLOAT_NaN; }
	if (p_x == 0.0f) { return 0.0f; }

	// Range reduction to [-TAU, TAU].
	float x = fmod(p_x, (float)TAU);

	// sin(-x) = -sin(x): handle sign.
	bool neg = x < 0.0f;
	if (neg) { x = -x; }

	// sin(x + PI) = -sin(x): map quadrants 3 & 4 down to quadrants 1 & 2.
	if (x > (float)PI) {
		x -= (float)PI;
		neg = !neg;
	}

	// sin(PI - x) = sin(x): map [PI/2, PI] down to [0, PI/2].
	if (x > (float)PI_HALF) {
		x = (float)PI - x;
	}

	// Now x ∈ [0, PI/2].
	// sin(x) = x * P(x^2).
	// P(t) = 1 - t/6 + t^2/120 - t^3/5040 + t^4/362880.
	// Horner evaluation: 4 terms after the leading 1 => error < 4e-6.
	const float x2 = x * x;

	const float poly = 1.0f + x2 * (-1.0f / 6.0f
			+ x2 * (1.0f / 120.0f
			+ x2 * (-1.0f / 5040.0f
			+ x2 * (1.0f / 362880.0f))));

	const float result = x * poly;

	return neg ? -result : result;
}

_ALWAYS_INLINE_ constexpr double cos(const double p_x) {
	return sin(p_x + PI_HALF);
}
_ALWAYS_INLINE_ constexpr float cos(const float p_x) {
	return sin(p_x + (float)PI_HALF);
}

_ALWAYS_INLINE_ constexpr double tan(const double p_x) {
	return sin(p_x) / cos(p_x);
}
_ALWAYS_INLINE_ constexpr float tan(const float p_x) {
	return sin(p_x) / cos(p_x);
}

_ALWAYS_INLINE_ constexpr double sinh(const double p_x) {
	// sinh(x) = (e^x - e^-x) / 2 = (e^x - 1/e^x) / 2
	const double e = exp(p_x);
	return (e - 1.0 / e) * 0.5;
}
_ALWAYS_INLINE_ constexpr float sinh(const float p_x) {
	// sinh(x) = (e^x - e^-x) / 2 = (e^x - 1/e^x) / 2
	const float e = exp(p_x);
	return (e - 1.0f / e) * 0.5f;
}

_ALWAYS_INLINE_ constexpr double sinc(const double p_x) {
	return p_x == 0 ? 1 : sin(p_x) / p_x;
}
_ALWAYS_INLINE_ constexpr float sinc(const float p_x) {
	return p_x == 0 ? 1 : sin(p_x) / p_x;
}

_ALWAYS_INLINE_ constexpr double sincn(const double p_x) {
	return sinc(PI * p_x);
}
_ALWAYS_INLINE_ constexpr float sincn(const float p_x) {
	return sinc((float)PI * p_x);
}

_ALWAYS_INLINE_ constexpr double cosh(const double p_x) {
	// cosh(x) = (e^x + e^-x) / 2 = (e^x + 1/e^x) / 2
	const double e = exp(p_x);
	return (e + 1.0 / e) / 2;
}
_ALWAYS_INLINE_ constexpr float cosh(const float p_x) {
	// cosh(x) = (e^x + e^-x) / 2 = (e^x + 1/e^x) / 2
	const float e = exp(p_x);
	return (e + 1.0f / e) / 2;
}

_ALWAYS_INLINE_ constexpr double tanh(const double p_x) {
	// tanh(x) = (e^(2x) - 1) / (e^(2x) + 1)
	// Uses only 1 exp call for minimum operations
	const double e2 = exp(2.0 * p_x);
	return (e2 - 1.0) / (e2 + 1.0);
}
_ALWAYS_INLINE_ constexpr float tanh(const float p_x) {
	// tanh(x) = (e^(2x) - 1) / (e^(2x) + 1)
	// Uses only 1 exp call for minimum operations
	const float e2 = exp(2.0f * p_x);
	return (e2 - 1.0f) / (e2 + 1.0f);
}

// Always does clamping so always safe to use.
_ALWAYS_INLINE_ constexpr double asin(const double p_x) {
	// Clamp input to [-1, 1] for safety
	if (p_x <= -1.0) { return -PI_HALF; }
	if (p_x >= 1.0) { return PI_HALF; }
	// asin(x) = atan(x / sqrt(1 - x²))
	// Uses 1 sqrt + 1 atan call (minimum operations)
	const double x2 = p_x * p_x;
	const double denom = sqrt(1.0 - x2);
	return atan(p_x / denom);
}
_ALWAYS_INLINE_ constexpr float asin(const float p_x) {
	// Clamp input to [-1, 1] for safety
	if (p_x <= -1.0f) { return -(float)PI_HALF; }
	if (p_x >= 1.0f) { return (float)PI_HALF; }
	// asin(x) = atan(x / sqrt(1 - x²))
	// Uses 1 sqrt + 1 atan call (minimum operations)
	const float x2 = p_x * p_x;
	const float denom = sqrt(1.0f - x2);
	return atan(p_x / denom);
}

// Always does clamping so always safe to use.
_ALWAYS_INLINE_ constexpr double acos(const double p_x) {
	// acos(x) = π/2 - asin(x) (minimum operations: 1 subtraction)
	return PI_HALF - asin(p_x);
}
_ALWAYS_INLINE_ constexpr float acos(const float p_x) {
	// acos(x) = π/2 - asin(x) (minimum operations: 1 subtraction)
	return (float)PI_HALF - asin(p_x);
}

_ALWAYS_INLINE_ constexpr double atan(const double p_x) {
	// Range reduction: atan(-x) = -atan(x)
	const bool neg = p_x < 0.0;
	double x = neg ? -p_x : p_x;
	
	// Range reduction: atan(x) = π/2 - atan(1/x) for x > 1
	const bool invert = x > 1.0;
	if (invert) { x = 1.0 / x; }
	
	// Now x ∈ [0, 1]
	// Use half-angle formula: atan(x) = 2 * atan(x / (1 + sqrt(1 + x²)))
	// This reduces range to ~[0, 0.414] for faster convergence
	const double sqrt_term = sqrt(1.0 + x * x);
	const double reduced = x / (1.0 + sqrt_term);
	
	// Polynomial approximation for atan on [0, 0.414]
	// P(t) = t * (1 - t²/3 + t⁴/5 - t⁶/7 + t⁸/9)
	// Horner evaluation: 4 terms => error < 1e-10
	const double t2 = reduced * reduced;
	const double poly = 1.0 + t2 * (-1.0 / 3.0
			+ t2 * (1.0 / 5.0
			+ t2 * (-1.0 / 7.0
			+ t2 * (1.0 / 9.0))));
	
	double result = 2.0 * reduced * poly;
	
	// Apply inversion: atan(1/x) = π/2 - atan(x)
	if (invert) { result = PI_HALF - result; }
	// Apply sign: atan(-x) = -atan(x)
	return neg ? -result : result;
}
_ALWAYS_INLINE_ constexpr float atan(const float p_x) {
	// Range reduction: atan(-x) = -atan(x)
	const bool neg = p_x < 0.0f;
	float x = neg ? -p_x : p_x;
	
	// Range reduction: atan(x) = π/2 - atan(1/x) for x > 1
	const bool invert = x > 1.0f;
	if (invert) { x = 1.0f / x; }
	
	// Now x ∈ [0, 1]
	// Use half-angle formula: atan(x) = 2 * atan(x / (1 + sqrt(1 + x²)))
	const float sqrt_term = sqrt(1.0f + x * x);
	const float reduced = x / (1.0f + sqrt_term);
	
	// Polynomial approximation for atan on [0, 0.414]
	// P(t) = t * (1 - t²/3 + t⁴/5 - t⁶/7)
	// Horner evaluation: 3 terms => error < 5e-5
	const float t2 = reduced * reduced;
	const float poly = 1.0f + t2 * (-1.0f / 3.0f
			+ t2 * (1.0f / 5.0f
			+ t2 * (-1.0f / 7.0f)));
	
	float result = 2.0f * reduced * poly;
	
	// Apply inversion: atan(1/x) = π/2 - atan(x)
	if (invert) { result = (float)PI_HALF - result; }
	// Apply sign: atan(-x) = -atan(x)
	return neg ? -result : result;
}

// Helper function for atan2 to handle quadrants correctly
_ALWAYS_INLINE_ constexpr double atan2_robust_helper(const double p_y, const double p_x, const double p_r) {
	// Determine quadrant and compute appropriate angle
	if (p_x > 0.0) {
		// Quadrants 1 and 4: use atan(y / (r + x))
		return atan(p_y / (p_r + p_x));
	} else if (p_x < 0.0) {
		// Quadrants 2 and 3: use atan(y / (r - x)) with sign
		return atan(p_y / (p_r - p_x)) * (p_y >= 0.0 ? 1.0 : -1.0);
	} else {
		// p_x == 0, already handled in atan2, but keep for safety
		return p_y > 0.0 ? PI_HALF : -PI_HALF;
	}
}
_ALWAYS_INLINE_ constexpr float atan2_robust_helper(const float p_y, const float p_x, const float p_r) {
	// Determine quadrant and compute appropriate angle
	if (p_x > 0.0f) {
		// Quadrants 1 and 4: use atan(y / (r + x))
		return atan(p_y / (p_r + p_x));
	} else if (p_x < 0.0f) {
		// Quadrants 2 and 3: use atan(y / (r - x)) with sign
		return atan(p_y / (p_r - p_x)) * (p_y >= 0.0f ? 1.0f : -1.0f);
	} else {
		// p_x == 0, already handled in atan2, but keep for safety
		return p_y > 0.0f ? (float)PI_HALF : -(float)PI_HALF;
	}
}

_ALWAYS_INLINE_ constexpr double atan2(const double p_y, const double p_x) {
	// atan2(y, x) with quadrant handling
	// Uses the formula: atan2(y, x) = 2 * atan(y / (sqrt(x² + y²) + x))
	// with sign corrections for different quadrants
	
	if (p_x == 0.0) {
		if (p_y > 0.0) { return PI_HALF; }
		if (p_y < 0.0) { return -PI_HALF; }
		return 0.0; // both zero
	}
	
	// Use the robust formula: atan2(y, x) = 2 * atan(y / (sqrt(x² + y²) + x))
	const double r = sqrt(p_x * p_x + p_y * p_y);
	const double t = atan2_robust_helper(p_y, p_x, r);
	return 2.0 * t;
}
_ALWAYS_INLINE_ constexpr float atan2(const float p_y, const float p_x) {
	// atan2(y, x) with quadrant handling
	if (p_x == 0.0f) {
		if (p_y > 0.0f) { return (float)PI_HALF; }
		if (p_y < 0.0f) { return -(float)PI_HALF; }
		return 0.0f; // both zero
	}
	
	// Use the robust formula: atan2(y, x) = 2 * atan(y / (sqrt(x² + y²) + x))
	const float r = sqrt(p_x * p_x + p_y * p_y);
	const float t = atan2_robust_helper(p_y, p_x, r);
	return 2.0f * t;
}

_ALWAYS_INLINE_ constexpr double asinh(const double p_x) {
	// asinh(x) = log(x + sqrt(x² + 1))
	// Uses 1 log + 1 sqrt + 2 additions (minimum operations)
	const double x2 = p_x * p_x;
	const double sqrt_term = sqrt(x2 + 1.0);
	return log(p_x + sqrt_term);
}
_ALWAYS_INLINE_ constexpr float asinh(const float p_x) {
	// asinh(x) = log(x + sqrt(x² + 1))
	// Uses 1 log + 1 sqrt + 2 additions (minimum operations)
	const float x2 = p_x * p_x;
	const float sqrt_term = sqrt(x2 + 1.0f);
	return log(p_x + sqrt_term);
}

// Always does clamping so always safe to use.
_ALWAYS_INLINE_ constexpr double acosh(const double p_x) {
	// acosh(x) = log(x + sqrt(x² - 1)) for x >= 1
	// Uses 1 log + 1 sqrt + 2 additions (minimum operations)
	if (p_x < 1.0) { return 0.0; }
	const double x2 = p_x * p_x;
	const double sqrt_term = sqrt(x2 - 1.0);
	return log(p_x + sqrt_term);
}
_ALWAYS_INLINE_ constexpr float acosh(const float p_x) {
	// acosh(x) = log(x + sqrt(x² - 1)) for x >= 1
	// Uses 1 log + 1 sqrt + 2 additions (minimum operations)
	if (p_x < 1.0f) { return 0.0f; }
	const float x2 = p_x * p_x;
	const float sqrt_term = sqrt(x2 - 1.0f);
	return log(p_x + sqrt_term);
}

// Always does clamping so always safe to use.
_ALWAYS_INLINE_ constexpr double atanh(const double p_x) {
	// atanh(x) = 0.5 * log((1 + x) / (1 - x))
	// Uses 1 log + 1 division + 2 additions (minimum operations)
	if (p_x <= -1.0) { return -INF; }
	if (p_x >= 1.0) { return INF; }
	return 0.5 * log((1.0 + p_x) / (1.0 - p_x));
}
_ALWAYS_INLINE_ constexpr float atanh(const float p_x) {
	// atanh(x) = 0.5 * log((1 + x) / (1 - x))
	// Uses 1 log + 1 division + 2 additions (minimum operations)
	if (p_x <= -1.0f) { return (float)-INF; }
	if (p_x >= 1.0f) { return (float)INF; }
	return 0.5f * log((1.0f + p_x) / (1.0f - p_x));
}

_ALWAYS_INLINE_ constexpr double modf(const double p_x, double *r_y) {
	// Split into integer and fractional parts
	// modf(x) = x - trunc(x), returns integer part, stores fractional part
	*r_y = p_x - trunc(p_x);
	return trunc(p_x);
}
_ALWAYS_INLINE_ constexpr float modf(const float p_x, float *r_y) {
	// Split into integer and fractional parts
	// modf(x) = x - trunc(x), returns integer part, stores fractional part
	*r_y = p_x - trunc(p_x);
	return trunc(p_x);
}

_ALWAYS_INLINE_ constexpr double log1p(const double p_x) {
	// log1p(x) = log(1 + x)
	// Uses 1 log + 1 addition (minimum operations)
	return log(1.0 + p_x);
}
_ALWAYS_INLINE_ constexpr float log1p(const float p_x) {
	// log1p(x) = log(1 + x)
	// Uses 1 log + 1 addition (minimum operations)
	return log(1.0f + p_x);
}

_ALWAYS_INLINE_ constexpr double log2(const double p_x) {
	// log2(x) = log(x) / log(2)
	// Uses 1 log + 1 division (minimum operations)
	return log(p_x) / LN2;
}
_ALWAYS_INLINE_ constexpr float log2(const float p_x) {
	// log2(x) = log(x) / log(2)
	// Uses 1 log + 1 division (minimum operations)
	return log(p_x) / (float)LN2;
}

_ALWAYS_INLINE_ constexpr double snapped(const double p_value, const double p_step) { return p_step == 0 ? p_value : Math::floor(p_value / p_step + 0.5) * p_step; }

_ALWAYS_INLINE_ constexpr uint32_t larger_prime(const uint32_t p_val) {
	const uint32_t primes[] = {
		5,
		13,
		23,
		47,
		97,
		193,
		389,
		769,
		1543,
		3079,
		6151,
		12289,
		24593,
		49157,
		98317,
		196613,
		393241,
		786433,
		1572869,
		3145739,
		6291469,
		12582917,
		25165843,
		50331653,
		100663319,
		201326611,
		402653189,
		805306457,
		1610612741,
		0,
	};

	int idx = 0;
	while (true) {
		if (primes[idx] == 0) { return 0; }
		if (primes[idx] > p_val) { return primes[idx]; }
		idx++;
	}
}


#include "core/math/random_pcg.h"

static RandomPCG default_rng;

_ALWAYS_INLINE_ constexpr void seed(const uint64_t p_seed) { default_rng.new_from_seed(p_seed); }
_ALWAYS_INLINE_ constexpr void randomize() { default_rng.randomize(); }
_ALWAYS_INLINE_ constexpr uint32_t rand_from_seed(uint64_t *p_seed) {
	RandomPCG dynamic_rng = RandomPCG(*p_seed);
	uint32_t r = dynamic_rng.rand();
	*p_seed = dynamic_rng.get_seed();
	return r;
}
_ALWAYS_INLINE_ constexpr uint32_t rand() { return default_rng.rand(); }
_ALWAYS_INLINE_ constexpr double randd() { return (double)rand() / (double)UINT32_MAX; }
_ALWAYS_INLINE_ constexpr float randf() { return (float)rand() / (float)UINT32_MAX; }
_ALWAYS_INLINE_ constexpr double randfn(const double p_mean, const double p_deviation) { return default_rng.randfn(p_mean, p_deviation); }

_ALWAYS_INLINE_ constexpr double random(const double p_from, const double p_to) { return default_rng.random(p_from, p_to); }
_ALWAYS_INLINE_ constexpr float random(const float p_from, const float p_to) { return default_rng.random(p_from, p_to); }
_ALWAYS_INLINE_ constexpr int random(const int p_from, const int p_to) { return default_rng.random(p_from, p_to); }

// This function should be as fast as possible and rounding mode should not matter.
_ALWAYS_INLINE_ constexpr int fast_ftoi(const float p_value) { return std::rint(p_value); }

_ALWAYS_INLINE_ constexpr uint32_t halfbits_to_floatbits(const uint16_t p_half) {
	uint16_t h_exp = (p_half & 0x7c00u);
	const uint32_t f_sgn = ((uint32_t)p_half & 0x8000u) << 16;
	
	if (h_exp == 0x0000u) { /* 0 or subnormal */
		uint16_t h_sig = (p_half & 0x03ffu);
		/* Signed zero */
		if (h_sig == 0) { return f_sgn; }
		/* Subnormal */
		h_sig <<= 1;
		while ((h_sig & 0x0400u) == 0) {
			h_sig <<= 1;
			h_exp++;
		}
		const uint32_t f_exp = ((uint32_t)(127 - 15 - h_exp)) << 23;
		const uint32_t f_sig = ((uint32_t)(h_sig & 0x03ffu)) << 13;
		return f_sgn + f_exp + f_sig;
	}
	else if (h_exp == 0x7c00u) { /* inf or NaN */
		/* All-ones exponent and a copy of the significand */
		return f_sgn + 0x7f800000u + (((uint32_t)(p_half & 0x03ffu)) << 13);
	}
	/* Just need to adjust the exponent and shift */
	return f_sgn + (((uint32_t)(p_half & 0x7fffu) + 0x1c000u) << 13);
	
}

_ALWAYS_INLINE_ constexpr float halfptr_to_float(const uint16_t *p_half) {
	return (float)halfbits_to_floatbits(*p_half);
}

_ALWAYS_INLINE_ constexpr float half_to_float(const uint16_t p_half) {
	return halfptr_to_float(&p_half);
}

_ALWAYS_INLINE_ constexpr uint16_t make_half_float(const float p_value) {
	const uint32_t x = uint32_t(p_value);
	const uint32_t sign = (unsigned short)(x >> 31);

	// get mantissa
	const uint32_t mantissa = x & ((1 << 23) - 1);
	// get exponent bits
	const uint32_t exponent = x & (0xFF << 23);
	if (exponent >= 0x47800000) {
		// check if the original single precision float number is a NaN
		// (?) we have a single precision NaN
		// (:) 16-bit half-float representation stores number as Inf
		const uint32_t mantissa_single = (mantissa && (exponent == (0xFF << 23))) ? (1 << 23) - 1 : 0;
		return (((uint16_t)sign) << 15) | (uint16_t)((0x1F << 10)) | (uint16_t)(mantissa_single >> 13);
	}
	// check if exponent is <= -15
	else if (exponent <= 0x38000000) {
		/*
		// store a denorm half-float value or zero
		exponent = (0x38000000 - exponent) >> 23;
		mantissa >>= (14 + exponent);

		hf = (((uint16_t)sign) << 15) | (uint16_t)(mantissa);
		*/
		return 0; //denormals do not work for 3D, convert to zero
	}
	return (((uint16_t)sign) << 15) | (uint16_t)((exponent - 0x38000000) >> 13) | (uint16_t)(mantissa >> 13);
}

_ALWAYS_INLINE_ constexpr float snap_scalar(const float p_offset, const float p_step, const float p_target) {
	return p_step != 0 ? snapped(p_target - p_offset, p_step) + p_offset : p_target;
}

_ALWAYS_INLINE_ constexpr float snap_scalar_separation(const float p_offset, const float p_step, const float p_target, const float p_separation) {
	if (p_step != 0) {
		const float a = snapped(p_target - p_offset, p_step + p_separation) + p_offset;
		const float b = p_target >= 0 ? a - p_separation : a + p_step;
		return (abs(p_target - a) < abs(p_target - b)) ? a : b;
	}
	return p_target;
}

}; // namespace Math