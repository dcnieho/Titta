#pragma once
#include <tuple>
#include <type_traits>

namespace
{
    // get last type (or optionally 2nd last when N=2, 3rd last when N=3, etc) in variadic template
    template<class T> struct tag_t { using type = T; };
    template<class...Ts, size_t N = 1>
    using last = typename std::tuple_element_t< sizeof...(Ts) - N, std::tuple<tag_t<Ts>...> >::type;

    // higher order function to forward an index sequence
    template <typename F, size_t... Is>
    constexpr auto indices_impl(F f, std::index_sequence<Is...>)
    {
        return f(std::integral_constant<size_t, Is>()...);
    }
    template <size_t N, typename F>
    constexpr auto indices(F f)
    {
        return indices_impl(f, std::make_index_sequence<N>());
    }

    // Given f and some args t0, t1, ..., tn, calls f(tn, t0, t1, ..., tn-1)
    template <typename F, typename... Ts>
    constexpr auto rotate_right(F f, Ts... ts)
    {
        auto tuple = std::make_tuple(ts...);
        return indices<sizeof...(Ts) - 1>([&](auto... Is) constexpr	// pass elements 1 to N-1 as input to lambda
        {
            return f(												// call user's function with:
                     std::get<sizeof...(Ts) - 1>(tuple),			// last element of tuple
                     std::get<Is>(tuple)...);						// all inputs to lambda (elements 1 to N-1)
        });
    }
    // Given f and some args t0, t1, ..., tn, calls f(tn-1, t0, t1, ..., tn)
    template <typename F, typename... Ts>
    constexpr auto rotate_right_except_last(F f, Ts... ts)
    {
        auto tuple = std::make_tuple(ts...);
        return indices<sizeof...(Ts) - 2>([&](auto... Is) constexpr	// pass elements 1 to N-2 as input to lambda
        {
            return f(												// call user's function with:
                     std::get<sizeof...(Ts) - 2>(tuple),			// element N-1
                     std::get<Is>(tuple)...,						// all inputs to lambda (elements 1 to N-2)
                     std::get<sizeof...(Ts) - 1>(tuple)				// last element
            );
        });
    }
    // Given f and some args t0, t1, ..., tn, calls f(t0, t1, ..., tn-1)
    template <typename F, typename... Ts>
    auto drop_last(F f, Ts... ts)
    {
        return indices<sizeof...(Ts) - 1>([&](auto... Is)
        {
            auto tuple = std::make_tuple(ts...);
            return f(std::get<Is>(tuple)...);
        });
    }

    // type trait to extract member variable type from a pointer-to-member-variable
    template <typename C>
    struct memVarType;

    template <class C, typename T>
    struct memVarType<T C::*>
    {
        using type = T;
    };

    template <class C>
    using memVarType_t = typename memVarType<C>::type;
}