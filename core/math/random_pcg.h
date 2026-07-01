/**************************************************************************/
/*  random_pcg.h                                                          */
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

#include "core/math/math_funcs.h"

#include <thirdparty/misc/pcg.h>

#include <cmath> // ldexp

#if defined(__GNUC__)
#define CLZ32(x) __builtin_clz(x)
#elif defined(_MSC_VER)
#include <intrin.h>
static int __bsr_clz32(uint32_t x) {
	unsigned long index;
	_BitScanReverse(&index, x);
	return 31 - index;
}
#define CLZ32(x) __bsr_clz32(x)
#endif

template <typename T>
class Vector;

class RandomPCG {
	pcg32_random_t pcg;
	uint64_t current_seed = 0; // The seed the current generator state started from.
	uint64_t current_inc = 0;

	public:
	static const uint64_t DEFAULT_SEED = 12047754176567800795U;
	static const uint64_t DEFAULT_INC = PCG_DEFAULT_INC_64;

	// Constructors
	constexpr RandomPCG() : pcg(), current_inc(0) { new_from_seed(0); }
	constexpr RandomPCG(uint64_t p_seed, uint64_t p_inc = 0) : pcg(), current_inc(p_inc) { new_from_seed(p_seed); }

	_FORCE_INLINE_ constexpr void new_from_seed(uint64_t p_seed) {
		current_seed = p_seed;
		pcg32_srandom_r(&pcg, current_seed, current_inc);
	}

	// Getsets
	_FORCE_INLINE_ constexpr uint64_t get_seed() const { return current_seed; }
	_FORCE_INLINE_ constexpr uint64_t get_state() const { return pcg.state; }
	_FORCE_INLINE_ constexpr void set_state(const uint64_t p_state) { pcg.state = p_state; }
	
	// Calculative Functions
	_FORCE_INLINE_ constexpr uint32_t rand() { return pcg32_random_r(&pcg); }
	_FORCE_INLINE_ constexpr uint32_t rand(const uint32_t bounds) { return pcg32_boundedrand_r(&pcg, bounds); }

	_FORCE_INLINE_ constexpr double randd() {
		#if defined(CLZ32)
		const uint32_t proto_exp_offset = rand();
		if (unlikely(proto_exp_offset == 0)) { return 0; }
		const uint64_t significand = (((uint64_t)rand()) << 32) | rand() | 0x8000000000000001U;
		return std::ldexp((double)significand, -64 - CLZ32(proto_exp_offset));
		#else
		// RandomPCG::randd - intrinsic clz is not available, falling back to bit truncation
		return (double)(((((uint64_t)rand()) << 32) | rand()) & 0x1FFFFFFFFFFFFFU) / (double)0x1FFFFFFFFFFFFFU;
		#endif
	}

	_FORCE_INLINE_ constexpr float randf() {
		#if defined(CLZ32)
		const uint32_t proto_exp_offset = rand();
		if (unlikely(proto_exp_offset == 0)) { return 0; }
		return std::ldexp((float)(rand() | 0x80000001), -32 - CLZ32(proto_exp_offset));
		#else
		// RandomPCG::randf - intrinsic clz is not available, falling back to bit truncation
		return (float)(rand() & 0xFFFFFF) / (float)0xFFFFFF;
		#endif
	}

	_FORCE_INLINE_ constexpr double random(const double p_from, const double p_to) { return randd() * (p_to - p_from) + p_from; }
	_FORCE_INLINE_ constexpr float random(const float p_from, const float p_to) { return randf() * (p_to - p_from) + p_from; }
	_FORCE_INLINE_ constexpr int random(const int p_from, const int p_to) {
		// No numbers inbetween basically means any number's return.
		if (p_from == p_to) { return p_from; }

		const int64_t min = MIN(p_from, p_to);
		const int64_t max = MAX(p_from, p_to);
		const uint32_t diff = static_cast<uint32_t>(max - min);

		if (diff == UINT32_MAX) {
			// Can't add 1 to max uint32_t value for inclusive range, so call rand without passing bounds.
			return static_cast<int64_t>(rand()) + min;
		}

		return static_cast<int64_t>(rand(diff + 1U)) + min;
	}

	_FORCE_INLINE_ constexpr double randfn(double p_mean, double p_deviation) {
		// Preventing INF value generation which causes a NaN value return.
		const double temp = random(CMP_EPSILON, Math::DOUBLE_MAX);
		return p_mean + p_deviation * (Math::cos(Math::TAU * randd()) * Math::sqrt(-2.0 * Math::log(temp))); // Box-Muller transform.
	}
	_FORCE_INLINE_ constexpr float randfn(float p_mean, float p_deviation) {
		// Preventing INF value generation which causes a NaN value return.
		const float temp = random((float)CMP_EPSILON, (float)Math::DOUBLE_MAX);
		return p_mean + p_deviation * (Math::cos((float)Math::TAU * randf()) * Math::sqrt(-2.0 * Math::log(temp))); // Box-Muller transform.
	}

	// Manipulative Functions
	_FORCE_INLINE_ constexpr void randomize() { new_from_seed(random(CMP_EPSILON, Math::DOUBLE_MAX)); }
};
