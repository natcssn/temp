// firebase_stl_compat.cpp
// Provides fallback implementations of MSVC STL vectorized algorithm functions
// that are referenced by the Firebase C++ SDK static libraries but may not be
// available in all MSVC runtime versions. These are simple loop-based fallbacks.

#include <cstdint>
#include <cstddef>
#include <cstring>

extern "C" {

const void* __stdcall __std_find_trivial_1(
    const void* _First, const void* _Last, uint8_t _Val) noexcept {
    auto p = static_cast<const uint8_t*>(_First);
    auto e = static_cast<const uint8_t*>(_Last);
    for (; p != e; ++p) {
        if (*p == _Val) return p;
    }
    return e;
}

const void* __stdcall __std_find_trivial_2(
    const void* _First, const void* _Last, uint16_t _Val) noexcept {
    auto p = static_cast<const uint16_t*>(_First);
    auto e = static_cast<const uint16_t*>(_Last);
    for (; p != e; ++p) {
        if (*p == _Val) return p;
    }
    return e;
}

const void* __stdcall __std_find_trivial_4(
    const void* _First, const void* _Last, uint32_t _Val) noexcept {
    auto p = static_cast<const uint32_t*>(_First);
    auto e = static_cast<const uint32_t*>(_Last);
    for (; p != e; ++p) {
        if (*p == _Val) return p;
    }
    return e;
}

const void* __stdcall __std_find_trivial_8(
    const void* _First, const void* _Last, uint64_t _Val) noexcept {
    auto p = static_cast<const uint64_t*>(_First);
    auto e = static_cast<const uint64_t*>(_Last);
    for (; p != e; ++p) {
        if (*p == _Val) return p;
    }
    return e;
}

const void* __stdcall __std_find_last_trivial_1(
    const void* _First, const void* _Last, uint8_t _Val) noexcept {
    auto p = static_cast<const uint8_t*>(_Last);
    auto f = static_cast<const uint8_t*>(_First);
    while (p != f) {
        --p;
        if (*p == _Val) return p;
    }
    return _Last;
}

const void* __stdcall __std_find_last_trivial_2(
    const void* _First, const void* _Last, uint16_t _Val) noexcept {
    auto p = static_cast<const uint16_t*>(_Last);
    auto f = static_cast<const uint16_t*>(_First);
    while (p != f) {
        --p;
        if (*p == _Val) return p;
    }
    return _Last;
}

const void* __stdcall __std_find_last_trivial_4(
    const void* _First, const void* _Last, uint32_t _Val) noexcept {
    auto p = static_cast<const uint32_t*>(_Last);
    auto f = static_cast<const uint32_t*>(_First);
    while (p != f) {
        --p;
        if (*p == _Val) return p;
    }
    return _Last;
}

const void* __stdcall __std_find_last_trivial_8(
    const void* _First, const void* _Last, uint64_t _Val) noexcept {
    auto p = static_cast<const uint64_t*>(_Last);
    auto f = static_cast<const uint64_t*>(_First);
    while (p != f) {
        --p;
        if (*p == _Val) return p;
    }
    return _Last;
}

const void* __stdcall __std_find_first_of_trivial_1(
    const void* _First1, const void* _Last1,
    const void* _First2, const void* _Last2) noexcept {
    auto h = static_cast<const uint8_t*>(_First1);
    auto he = static_cast<const uint8_t*>(_Last1);
    auto n = static_cast<const uint8_t*>(_First2);
    auto ne = static_cast<const uint8_t*>(_Last2);
    for (; h != he; ++h) {
        for (auto nn = n; nn != ne; ++nn) {
            if (*h == *nn) return h;
        }
    }
    return he;
}

const void* __stdcall __std_find_first_of_trivial_2(
    const void* _First1, const void* _Last1,
    const void* _First2, const void* _Last2) noexcept {
    auto h = static_cast<const uint16_t*>(_First1);
    auto he = static_cast<const uint16_t*>(_Last1);
    auto n = static_cast<const uint16_t*>(_First2);
    auto ne = static_cast<const uint16_t*>(_Last2);
    for (; h != he; ++h) {
        for (auto nn = n; nn != ne; ++nn) {
            if (*h == *nn) return h;
        }
    }
    return he;
}

void* __stdcall __std_remove_8(
    void* _First, void* _Last, uint64_t _Val) noexcept {
    auto p = static_cast<uint64_t*>(_First);
    auto e = static_cast<uint64_t*>(_Last);
    // Find first match
    for (; p != e; ++p) {
        if (*p == _Val) break;
    }
    if (p == e) return e;
    auto result = p;
    ++p;
    for (; p != e; ++p) {
        if (*p != _Val) {
            *result = *p;
            ++result;
        }
    }
    return result;
}

void* __stdcall __std_remove_4(
    void* _First, void* _Last, uint32_t _Val) noexcept {
    auto p = static_cast<uint32_t*>(_First);
    auto e = static_cast<uint32_t*>(_Last);
    for (; p != e; ++p) {
        if (*p == _Val) break;
    }
    if (p == e) return e;
    auto result = p;
    ++p;
    for (; p != e; ++p) {
        if (*p != _Val) {
            *result = *p;
            ++result;
        }
    }
    return result;
}

void* __stdcall __std_remove_1(
    void* _First, void* _Last, uint8_t _Val) noexcept {
    auto p = static_cast<uint8_t*>(_First);
    auto e = static_cast<uint8_t*>(_Last);
    for (; p != e; ++p) {
        if (*p == _Val) break;
    }
    if (p == e) return e;
    auto result = p;
    ++p;
    for (; p != e; ++p) {
        if (*p != _Val) {
            *result = *p;
            ++result;
        }
    }
    return result;
}

size_t __stdcall __std_find_last_of_trivial_pos_1(
    const void* _Haystack, size_t _Hay_length,
    const void* _Needle, size_t _Needle_length) noexcept {
    auto h = static_cast<const uint8_t*>(_Haystack);
    auto n = static_cast<const uint8_t*>(_Needle);
    size_t result = static_cast<size_t>(-1); // npos
    for (size_t i = 0; i < _Hay_length; ++i) {
        for (size_t j = 0; j < _Needle_length; ++j) {
            if (h[i] == n[j]) {
                result = i;
                break;
            }
        }
    }
    return result;
}

size_t __stdcall __std_find_last_of_trivial_pos_2(
    const void* _Haystack, size_t _Hay_length,
    const void* _Needle, size_t _Needle_length) noexcept {
    auto h = static_cast<const uint16_t*>(_Haystack);
    auto n = static_cast<const uint16_t*>(_Needle);
    size_t result = static_cast<size_t>(-1);
    for (size_t i = 0; i < _Hay_length; ++i) {
        for (size_t j = 0; j < _Needle_length; ++j) {
            if (h[i] == n[j]) {
                result = i;
                break;
            }
        }
    }
    return result;
}

const void* __stdcall __std_search_1(
    const void* _First1, const void* _Last1,
    const void* _First2, size_t _Count2) noexcept {
    auto h = static_cast<const uint8_t*>(_First1);
    auto he = static_cast<const uint8_t*>(_Last1);
    auto n = static_cast<const uint8_t*>(_First2);
    size_t hay_len = he - h;
    if (_Count2 == 0) return h;
    if (_Count2 > hay_len) return he;
    for (size_t i = 0; i <= hay_len - _Count2; ++i) {
        if (memcmp(h + i, n, _Count2) == 0) return h + i;
    }
    return he;
}

const void* __stdcall __std_search_2(
    const void* _First1, const void* _Last1,
    const void* _First2, size_t _Count2) noexcept {
    auto h = static_cast<const uint16_t*>(_First1);
    auto he = static_cast<const uint16_t*>(_Last1);
    auto n = static_cast<const uint16_t*>(_First2);
    size_t hay_len = he - h;
    if (_Count2 == 0) return h;
    if (_Count2 > hay_len) return he;
    for (size_t i = 0; i <= hay_len - _Count2; ++i) {
        if (memcmp(h + i, n, _Count2 * 2) == 0) return h + i;
    }
    return he;
}

} // extern "C"
