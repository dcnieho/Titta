#pragma once
#include <type_traits>
#include <string>
#include <vector>
#include <array>

template <typename T, typename = void>
struct is_container : std::false_type {};

template <typename T>
struct is_container<T, std::void_t<
    typename T::value_type,
    typename T::size_type,
    typename T::iterator,
    typename T::const_iterator,
    decltype(std::declval<T>().size()),
    decltype(std::declval<T>().begin()),
    decltype(std::declval<T>().end()),
    decltype(std::declval<T>().cbegin()),
    decltype(std::declval<T>().cend())
    >>
    : std::true_type{};

template<class T>
static constexpr bool const is_container_v = is_container<std::decay_t<T>>::value;

template <typename T>
struct is_guaranteed_contiguous : std::false_type {};

template<class T, std::size_t N>
struct is_guaranteed_contiguous<std::array<T, N>>
    : std::true_type
{};

template<typename... Args>
struct is_guaranteed_contiguous<std::vector<Args...>>
    : std::true_type
{};

template<>
struct is_guaranteed_contiguous<std::string>
    : std::true_type
{};

template<class T>
static constexpr bool const is_guaranteed_contiguous_v = is_guaranteed_contiguous<std::decay_t<T>>::value;