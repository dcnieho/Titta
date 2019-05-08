#pragma once
#include <type_traits>
#include <string>
#include <variant>
#include <vector>
#include <array>
#include <tuple>
#include <optional>
#include <memory>

#include "pack_utils.h"

#define TARGET_API_VERSION 700
#define MX_COMPAT_32
#define MW_NEEDS_VERSION_H	// looks like a bug in R2018b, don't know how to check if this is R2018b, define for now
#include <mex.h>

namespace
{
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
}

namespace mxTypes
{
    // functionality to convert C++ types to MATLAB ClassIDs and back
    template <typename T>
    constexpr mxClassID typeToMxClass()
    {
        if      constexpr (std::is_same_v<T, double>)
            return mxDOUBLE_CLASS;
        else if constexpr (std::is_same_v<T, float>)
            return mxSINGLE_CLASS;
        else if constexpr (std::is_same_v<T, bool>)
            return mxLOGICAL_CLASS;
        else if constexpr (std::is_same_v<T, uint64_t>)
            return mxUINT64_CLASS;
        else if constexpr (std::is_same_v<T, int64_t>)
            return mxINT64_CLASS;
        else if constexpr (std::is_same_v<T, uint32_t>)
            return mxUINT32_CLASS;
        else if constexpr (std::is_same_v<T, int32_t>)
            return mxINT32_CLASS;
        else if constexpr (std::is_same_v<T, uint16_t>)
            return mxUINT16_CLASS;
        else if constexpr (std::is_same_v<T, int16_t>)
            return mxINT16_CLASS;
        else if constexpr (std::is_same_v<T, uint8_t>)
            return mxUINT8_CLASS;
        else if constexpr (std::is_same_v<T, int8_t>)
            return mxINT8_CLASS;
    }

    template <typename T>
    constexpr bool typeNeedsMxCellStorage()
    {
        if constexpr (std::is_arithmetic_v<T>)  // true for integrals and floating point, and bool is included in integral
            return false;
        else
            return true;
    }

    template <mxClassID T>
    constexpr mxClassID MxClassToType()
    {
        if      constexpr (T == mxDOUBLE_CLASS)
            using type = double;
        else if constexpr (T == mxSINGLE_CLASS)
            using type = float;
        else if constexpr (T == mxLOGICAL_CLASS)
            using type = bool;
        else if constexpr (T == mxUINT64_CLASS)
            using type = uint64_t;
        else if constexpr (T == mxINT64_CLASS)
            using type = int64_t;
        else if constexpr (T == mxUINT32_CLASS)
            using type = uint32_t;
        else if constexpr (T == mxINT32_CLASS)
            using type = int32_t;
        else if constexpr (T == mxUINT16_CLASS)
            using type = uint16_t;
        else if constexpr (T == mxINT16_CLASS)
            using type = int16_t;
        else if constexpr (T == mxUINT8_CLASS)
            using type = uint8_t;
        else if constexpr (T == mxINT8_CLASS)
            using type = int8_t;
    }



    //// to simple variables
    mxArray* ToMatlab(std::string str_)
    {
        return mxCreateString(str_.c_str());
    }

    template<class T>
    typename std::enable_if_t<!is_container_v<T>, mxArray*>
        ToMatlab(T val_)
    {
        static_assert(!typeNeedsMxCellStorage<T>(), "T must be arithmetic. Implement a specialization of ToMxArray for your type");
        mxArray* temp;
        auto storage = static_cast<T*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, 1, typeToMxClass<T>(), mxREAL)));
        *storage = val_;
        return temp;
    }

    template<class Cont>
    typename std::enable_if_t<is_container_v<Cont>, mxArray*>
        ToMatlab(Cont data_)
    {
        mxArray* temp;
        using V = typename Cont::value_type;
        if constexpr (typeNeedsMxCellStorage<V>())
        {
            if (!data_.size())
                temp = mxCreateCellMatrix(0, 0);
            else
            {
                temp = mxCreateCellMatrix(static_cast<mwSize>(data_.size()), 1);
                mwIndex i = 0;
                for (auto &item : data_)
                    mxSetCell(temp, i++, ToMatlab(item));
            }
        }
        else if constexpr (is_guaranteed_contiguous_v<Cont>)
        {
            if (!data_.size())
                temp = mxCreateNumericMatrix(0, 0, typeToMxClass<V>(), mxREAL);
            else
            {
                auto storage = static_cast<V*>(mxGetData(temp = mxCreateUninitNumericMatrix(static_cast<mwSize>(data_.size()), 1, typeToMxClass<V>(), mxREAL)));
                // contiguous storage, can memcopy
                if (data_.size())
                    memcpy(storage, &data_[0], data_.size());
            }
        }
        else
        {
            static_assert(false, "TODO: implement");
            // some range based for-loop, copy elements one at a time
        }
        return temp;
    }

    template <class... Types>
    mxArray* ToMatlab(std::variant<Types...> val_)
    {
        return std::visit([](auto& a)->mxArray* {return ToMatlab(a); }, val_);
    }

    template <class T>
    mxArray* ToMatlab(std::optional<T> val_)
    {
        if (!val_)
            return mxCreateDoubleMatrix(0, 0, mxREAL);
        else
            return ToMatlab(*val_);
    }

    template <class T>
    mxArray* ToMatlab(std::shared_ptr<T> val_)
    {
        if (!val_)
            return mxCreateDoubleMatrix(0, 0, mxREAL);
        else
            return ToMatlab(*val_);
    }


    //// array of structs
    template<typename V, typename OutOrFun, typename... Fs, typename... Ts, typename... Fs2>
    void ToStructArrayImpl(mxArray* out_, const V& item_, const mwIndex& idx1_, int idx2_, std::tuple<OutOrFun, Ts Fs::*...> expr, Fs2... fields)
    {
        if constexpr (std::is_invocable_v<OutOrFun, Ts...>)
            if constexpr (sizeof...(Ts) == 2)
                mxSetFieldByNumber(out_, idx1_, idx2_, ToMatlab(std::get<0>(expr)(item_.*std::get<1>(expr), item_.*std::get<2>(expr))));
            else if constexpr (sizeof...(Ts) == 1)
                mxSetFieldByNumber(out_, idx1_, idx2_, ToMatlab(std::get<0>(expr)(item_.*std::get<1>(expr))));
            else
                static_assert(false);   // not implemented
        else
            mxSetFieldByNumber(out_, idx1_, idx2_, ToMatlab(static_cast<OutOrFun>(item_.*std::get<0>(expr))));
        if constexpr (!sizeof...(fields))
            return;
        else
            ToStructArrayImpl(out_, item_, idx1_, ++idx2_, fields...);
    }

    template<typename V, typename F, typename T, typename... Fs>
    void ToStructArrayImpl(mxArray* out_, const V& item_, const mwIndex& idx1_, int idx2_, T F::*field, Fs... fields)
    {
        mxSetFieldByNumber(out_, idx1_, idx2_, ToMatlab(item_.*field));
        if constexpr (!sizeof...(fields))
            return;
        else
            ToStructArrayImpl(out_, item_, idx1_, ++idx2_, fields...);
    }

    template<template<typename, typename> class Cont, typename V, typename... Rest, typename... Fs>
    void ToStructArray(mxArray* out_, const Cont<V, Rest...>& data_, Fs... fields)
    {
        mwIndex i = 0;
        for (const auto& item : data_)
        {
            ToStructArrayImpl(out_, item, i, 0, fields...);
            i++;
        }
    }


    //// struct of arrays
    // machinery to turn a container of objects into a single struct with an array per object field
    // get field indicated by list of pointers-to-member-variable in fields
    template <typename O, typename T, typename... Os, typename... Ts>
    constexpr auto getField(const O& obj, T O::*field1, Ts Os::*...fields)
    {
        if constexpr (!sizeof...(fields))
            return obj.*field1;
        else
            return getField(obj.*field1, fields...);
    }

    // get field indicated by list of pointers-to-member-variable in fields, process return value by either:
    // 1. transform by applying callable; or
    // 2. cast return value to user specified type
    template <typename Obj, typename OutOrFun, typename... Fs, typename... Ts>
    constexpr auto getField(const Obj& obj, OutOrFun o, Ts Fs::*...fields)
    {
        if constexpr (std::is_invocable_v<OutOrFun, last<Obj, Ts...>>)
            return o(getField(obj, fields...));
        else
            return static_cast<OutOrFun>(getField(obj, fields...));
    }

    template <typename Obj, typename... Fs>
    constexpr auto getFieldWrapper(const Obj& obj, Fs... fields)
    {
        // if last is pointer-to-member-variable, but previous is not (this would be a type tag then), swap the last two to put the type tag last
        if      constexpr (sizeof...(Fs) > 1 && std::is_member_object_pointer_v<last<Obj, Fs...>> && !std::is_member_object_pointer_v<last<Obj, Fs..., 1>>)
            return rotate_right_except_last(
            [&](auto... elems) constexpr
            {
                return getField(obj, elems...);
            }, fields...);
        // if last is pointer-to-member-variable, no casting of return value requested through type tag, call getField
        else if constexpr (std::is_member_object_pointer_v<last<Obj, Fs...>>)
            return getField(obj, fields...);
        // if last is an enum, compare the value of the field to it
        // this turns enum fields into a boolean given reference enum value for which true should be returned
        else if constexpr (std::is_enum_v<last<Obj, Fs...>>)
        {
            auto tuple = std::make_tuple(fields...);
            return drop_last(
            [&](auto... elems) constexpr
            {
                return getField(obj, elems...);
            }, fields...) == std::get<sizeof...(Fs) - 1>(tuple);
        }
        else
            // if last is not pointer-to-member-variable, call getField with correct order of arguments
            // last is type to cast return value to, or lambda to apply to return value
            return rotate_right(
            [&](auto... elems) constexpr
            {
                return getField(obj, elems...);
            }, fields...);
    }
}