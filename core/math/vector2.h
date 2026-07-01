/**************************************************************************/
/*  vector2.h                                                             */
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

#include "core/error/error_macros.h"
#include "core/math/math_defs.h"
#include "core/math/math_funcs.h"
#include "core/math/vector2i.h"
#include "core/string/ustring.h"
#include "core/templates/hashfuncs.h"

class String;
struct Vector2i;

struct [[nodiscard]] Vector2 {
	static const Vector2 LEFT;
	static const Vector2 RIGHT;
	static const Vector2 UP;
	static const Vector2 DOWN;
	static const Vector2 ZERO;
	static const Vector2 ONE;
	static const Vector2 INF;

	static constexpr int AXIS_COUNT = 2;

	enum Axis {
		AXIS_X,
		AXIS_Y,
	};

	// NOLINTBEGIN(modernize-use-default-member-init)
	struct {
		real_t x;
		real_t y;
	};
	// NOLINTEND(modernize-use-default-member-init)

	// Constructors

	// NOLINTBEGIN(cppcoreguidelines-pro-type-member-init)
	constexpr Vector2() : x(0), y(0) {}
	constexpr Vector2(real_t p_x, real_t p_y) : x(p_x), y(p_y) {}
	// NOLINTEND(cppcoreguidelines-pro-type-member-init)

	_FORCE_INLINE_ constexpr const real_t &operator[](int p_axis) const { return p_axis <= 0 ? x : y; }
	_FORCE_INLINE_ constexpr real_t &operator[](int p_axis) { return p_axis <= 0 ? x : y; }

	// Operators
	constexpr Vector2 operator+(const Vector2 &p_v) const { return Vector2(x + p_v.x, y + p_v.y); }
	constexpr void operator+=(const Vector2 &p_v) {
		x += p_v.x;
		y += p_v.y;
	}
	constexpr Vector2 operator-(const Vector2 &p_v) const { return Vector2(x - p_v.x, y - p_v.y); }
	constexpr void operator-=(const Vector2 &p_v) {
		x -= p_v.x;
		y -= p_v.y;
	}
	constexpr Vector2 operator*(const Vector2 &p_v) const { return Vector2(x * p_v.x, y * p_v.y); }
	constexpr Vector2 operator*(real_t p_rvalue) const { return Vector2(x * p_rvalue, y * p_rvalue); }
	constexpr void operator*=(real_t p_rvalue) {
		x *= p_rvalue;
		y *= p_rvalue;
	}
	constexpr void operator*=(const Vector2 &p_v) {
		x *= p_v.x;
		y *= p_v.y;
	}

	constexpr Vector2 operator/(const Vector2 &p_v1) const { return Vector2(p_v1.x == 0 ? Math::INF : x / p_v1.x, p_v1.y == 0 ? Math::INF : y / p_v1.y); }
	constexpr Vector2 operator/(real_t p_rvalue) const { return p_rvalue == 0 ? Vector2::INF : Vector2(x / p_rvalue, y / p_rvalue); }
	constexpr void operator/=(real_t p_rvalue) {
		if (p_rvalue == 0) {
			x = Math::INF;
			y = Math::INF;
		} else {
			x /= p_rvalue;
			y /= p_rvalue;
		}
	}
	constexpr void operator/=(const Vector2 &p_rvalue) {
		if (p_rvalue.x == 0) {
			x = Math::INF;
		} else {
			x /= p_rvalue.x;
		}
		if (p_rvalue.y == 0) {
			y = Math::INF;
		} else {
			y /= p_rvalue.y;
		}
	}

	constexpr Vector2 operator-() const { return Vector2(-x, -y); }

	constexpr void operator=(const Vector2 &p_vec2) { set(p_vec2); }

	constexpr bool operator==(const Vector2 &p_vec2) const { return x == p_vec2.x && y == p_vec2.y; }
	constexpr bool operator!=(const Vector2 &p_vec2) const { return x != p_vec2.x || y != p_vec2.y; }

	constexpr bool operator<(const Vector2 &p_vec2) const { return x == p_vec2.x ? (y < p_vec2.y) : (x < p_vec2.x); }
	constexpr bool operator>(const Vector2 &p_vec2) const { return x == p_vec2.x ? (y > p_vec2.y) : (x > p_vec2.x); }
	constexpr bool operator<=(const Vector2 &p_vec2) const { return x == p_vec2.x ? (y <= p_vec2.y) : (x < p_vec2.x); }
	constexpr bool operator>=(const Vector2 &p_vec2) const { return x == p_vec2.x ? (y >= p_vec2.y) : (x > p_vec2.x); }

	explicit operator String() const {
		return "(" + String::num_real(x, true) + ", " + String::num_real(y, true) + ")";
	}
	constexpr operator Vector2i() const { return Vector2i(x, y); }

	// Getsets
	constexpr void set(const real_t p_x, const real_t p_y) {
		x = p_x;
		y = p_y;
	}
	constexpr void set(const Vector2 p_v) {
		x = p_v.x;
		y = p_v.y;
	}

	_FORCE_INLINE_ constexpr bool is_equal_approx(const Vector2 &p_v) const { return Math::is_equal_approx(x, p_v.x) && Math::is_equal_approx(y, p_v.y); }
	_FORCE_INLINE_ constexpr bool is_same(const Vector2 &p_v) const { return Math::is_same(x, p_v.x) && Math::is_same(y, p_v.y); }
	_FORCE_INLINE_ constexpr bool is_zero_approx() const { return Math::is_zero_approx(x) && Math::is_zero_approx(y); }
	_FORCE_INLINE_ constexpr bool is_finite() const { return Math::is_finite(x) && Math::is_finite(y); }

	_FORCE_INLINE_ constexpr Vector2::Axis min_axis_index() const { return x < y ? Vector2::AXIS_X : Vector2::AXIS_Y; }
	_FORCE_INLINE_ constexpr Vector2::Axis max_axis_index() const { return x < y ? Vector2::AXIS_Y : Vector2::AXIS_X; }

	_FORCE_INLINE_ constexpr real_t length_squared() const { return x * x + y * y; }
	_FORCE_INLINE_ constexpr real_t length() const { return Math::sqrt(length_squared()); }

	_FORCE_INLINE_ constexpr void normalize() { !is_finite() ? set(Vector2::ZERO) : (length_squared() == 0 ? set(Vector2::ZERO) : set(x / length(), y / length())); }
	_FORCE_INLINE_ constexpr Vector2 normalized() const { return !is_finite() ? Vector2::ZERO : (length_squared() == 0 ? Vector2::ZERO : Vector2(x / length(), y / length())); }
	_FORCE_INLINE_ constexpr bool is_normalized() const { return Math::is_equal_approx(length_squared(), 1, (real_t)UNIT_EPSILON); }

	_FORCE_INLINE_ constexpr Vector2 limit_length(const real_t p_len = 1.0) const { return (length() > 0 && p_len < length()) ? Vector2(x / length(), y * p_len) : *this; }

	_FORCE_INLINE_ constexpr Vector2 min(const Vector2 &p_vector2) const { return Vector2(MIN(x, p_vector2.x), MIN(y, p_vector2.y)); }
	_FORCE_INLINE_ constexpr Vector2 minf(const real_t p_scalar) const { return Vector2(MIN(x, p_scalar), MIN(y, p_scalar)); }
	_FORCE_INLINE_ constexpr Vector2 max(const Vector2 &p_vector2) const { return Vector2(MAX(x, p_vector2.x), MAX(y, p_vector2.y)); }
	_FORCE_INLINE_ constexpr Vector2 maxf(const real_t p_scalar) const { return Vector2(MAX(x, p_scalar), MAX(y, p_scalar)); }

	_FORCE_INLINE_ constexpr real_t dot(const Vector2 &p_other) const { return x * p_other.x + y * p_other.y; }
	_FORCE_INLINE_ constexpr real_t cross(const Vector2 &p_other) const { return x * p_other.y - y * p_other.x; }

	_FORCE_INLINE_ constexpr real_t distance_squared_to(const Vector2 &p_vector2) const { return (x - p_vector2.x) * (x - p_vector2.x) + (y - p_vector2.y) * (y - p_vector2.y); }
	_FORCE_INLINE_ constexpr real_t distance_to(const Vector2 &p_vector2) const { return Math::sqrt(distance_squared_to(p_vector2)); }
	_FORCE_INLINE_ constexpr real_t angle_to(const Vector2 &p_vector2) const { return Math::atan2(cross(p_vector2), dot(p_vector2)); }
	_FORCE_INLINE_ constexpr real_t angle_to_point(const Vector2 &p_vector2) const { return (p_vector2 - *this).angle(); }
	_FORCE_INLINE_ constexpr Vector2 direction_to(const Vector2 &p_to) const { return (p_to - *this).normalized(); }

	_FORCE_INLINE_ constexpr Vector2 posmod(real_t p_mod) const { return Vector2(Math::fposmod(x, p_mod), Math::fposmod(y, p_mod)); }
	_FORCE_INLINE_ constexpr Vector2 posmodv(const Vector2 &p_modv) const { return Vector2(Math::fposmod(x, p_modv.x), Math::fposmod(y, p_modv.y)); }
	_FORCE_INLINE_ constexpr Vector2 project(const Vector2 &p_to) const { return p_to * (dot(p_to) / p_to.length_squared()); }

	_FORCE_INLINE_ constexpr Vector2 plane_project(real_t p_d, const Vector2 &p_vec) const { return p_vec - *this * (dot(p_vec) - p_d); }

	_FORCE_INLINE_ constexpr Vector2 lerp(const Vector2 &p_to, real_t p_weight) const { return Vector2(Math::lerp(x, p_to.x, p_weight), Math::lerp(y, p_to.y, p_weight)); }
	_FORCE_INLINE_ constexpr Vector2 slerp(const Vector2 &p_to, real_t p_weight) const {
		if (length_squared() == 0.0f || p_to.length_squared() == 0.0f) {
			// Zero length vectors have no angle, so the best we can do is either lerp or throw an error.
			return lerp(p_to, p_weight);
		}
		const real_t result_length = Math::lerp(length(), p_to.length(), p_weight);
		return rotated(angle_to(p_to) * p_weight) * (result_length / length());
	}
	_FORCE_INLINE_ constexpr Vector2 cubic_interpolate(const Vector2 &p_b, const Vector2 &p_pre_a, const Vector2 &p_post_b, real_t p_weight) const {
		return Vector2(Math::cubic_interpolate(x, p_b.x, p_pre_a.x, p_post_b.x, p_weight), Math::cubic_interpolate(y, p_b.y, p_pre_a.y, p_post_b.y, p_weight));
	}
	_FORCE_INLINE_ constexpr Vector2 cubic_interpolate_in_time(const Vector2 &p_b, const Vector2 &p_pre_a, const Vector2 &p_post_b, real_t p_weight, real_t p_b_t, real_t p_pre_a_t, real_t p_post_b_t) const {
		return Vector2(Math::cubic_interpolate_in_time(x, p_b.x, p_pre_a.x, p_post_b.x, p_weight, p_b_t, p_pre_a_t, p_post_b_t), Math::cubic_interpolate_in_time(y, p_b.y, p_pre_a.y, p_post_b.y, p_weight, p_b_t, p_pre_a_t, p_post_b_t));
	}
	_FORCE_INLINE_ constexpr Vector2 bezier_interpolate(const Vector2 &p_control_1, const Vector2 &p_control_2, const Vector2 &p_end, real_t p_t) const {
		return Vector2(Math::bezier_interpolate(x, p_control_1.x, p_control_2.x, p_end.x, p_t), Math::bezier_interpolate(y, p_control_1.y, p_control_2.y, p_end.y, p_t));
	}
	_FORCE_INLINE_ constexpr Vector2 bezier_derivative(const Vector2 &p_control_1, const Vector2 &p_control_2, const Vector2 &p_end, real_t p_t) const {
		return Vector2(Math::bezier_derivative(x, p_control_1.x, p_control_2.x, p_end.x, p_t), Math::bezier_derivative(y, p_control_1.y, p_control_2.y, p_end.y, p_t));
	}

	_FORCE_INLINE_ constexpr Vector2 move_toward(const Vector2 &p_to, real_t p_delta) const {
		return (p_to - *this).length() <= p_delta || (p_to - *this).length() < (real_t)CMP_EPSILON ? p_to : *this + (p_to - *this) / (p_to - *this).length() * p_delta;
	}

	_FORCE_INLINE_ constexpr Vector2 slide(const Vector2 &p_normal) const { return *this - p_normal.normalized() * dot(p_normal.normalized()); }
	_FORCE_INLINE_ constexpr Vector2 reflect(const Vector2 &p_normal) const { return p_normal.normalized() * 2.0f * dot(p_normal.normalized()) - *this; }
	_FORCE_INLINE_ constexpr Vector2 bounce(const Vector2 &p_normal) const { return -reflect(p_normal); }

	_FORCE_INLINE_ constexpr real_t angle() const { return Math::atan2(y, x); }
	_FORCE_INLINE_ static constexpr Vector2 from_angle(real_t p_angle) { return Vector2(Math::cos(p_angle), Math::sin(p_angle)); }

	_FORCE_INLINE_ constexpr Vector2 abs() const { return Vector2(Math::abs(x), Math::abs(y)); }

	_FORCE_INLINE_ constexpr Vector2 rotated(real_t p_by) const {
		return Vector2(x * Math::cos(p_by) - y * Math::sin(p_by), x * Math::sin(p_by) + y * Math::cos(p_by));
	}
	_FORCE_INLINE_ constexpr Vector2 orthogonal() const { return Vector2(y, -x); }

	_FORCE_INLINE_ constexpr Vector2 sign() const { return Vector2(SIGN(x), SIGN(y)); }
	_FORCE_INLINE_ constexpr Vector2 floor() const { return Vector2(Math::floor(x), Math::floor(y)); }
	_FORCE_INLINE_ constexpr Vector2 ceil() const { return Vector2(Math::ceil(x), Math::ceil(y)); }
	_FORCE_INLINE_ constexpr Vector2 round() const { return Vector2(Math::round(x), Math::round(y)); }
	_FORCE_INLINE_ constexpr Vector2 snapped(const Vector2 &p_step) const { return Vector2(Math::snapped(x, p_step.x), Math::snapped(y, p_step.y)); }
	_FORCE_INLINE_ constexpr Vector2 snappedf(real_t p_step) const { return Vector2(Math::snapped(x, p_step), Math::snapped(y, p_step)); }
	_FORCE_INLINE_ constexpr Vector2 clamp(const Vector2 &p_min, const Vector2 &p_max) const { return Vector2(CLAMP(x, p_min.x, p_max.x), CLAMP(y, p_min.y, p_max.y)); }
	_FORCE_INLINE_ constexpr Vector2 clampf(real_t p_min, real_t p_max) const { return Vector2(CLAMP(x, p_min, p_max), CLAMP(y, p_min, p_max)); }
	_FORCE_INLINE_ constexpr real_t aspect() const { return x / y; }

	uint32_t hash() const { return hash_fmix32(hash_murmur3_one_real(y, hash_murmur3_one_real(x))); }
};

inline constexpr Vector2 Vector2::LEFT = { -1, 0 };
inline constexpr Vector2 Vector2::RIGHT = { 1, 0 };
inline constexpr Vector2 Vector2::UP = { 0, -1 };
inline constexpr Vector2 Vector2::DOWN = { 0, 1 };
inline constexpr Vector2 Vector2::ZERO = { 0, 0 };
inline constexpr Vector2 Vector2::ONE = { 1, 1 };
inline constexpr Vector2 Vector2::INF = { Math::FLOAT_MAX, Math::FLOAT_MAX };

// Multiplication operators required to workaround issues with LLVM using implicit conversion
// to Vector2i instead for integers where it should not.

constexpr Vector2 operator*(float p_scalar, const Vector2 &p_vec) {
	return p_vec * p_scalar;
}
constexpr Vector2 operator*(double p_scalar, const Vector2 &p_vec) {
	return p_vec * p_scalar;
}
constexpr Vector2 operator*(int32_t p_scalar, const Vector2 &p_vec) {
	return p_vec * p_scalar;
}
constexpr Vector2 operator*(int64_t p_scalar, const Vector2 &p_vec) {
	return p_vec * p_scalar;
}

typedef Vector2 Size2;
typedef Vector2 Point2;

template <>
struct is_zero_constructible<Vector2> : std::true_type {};
