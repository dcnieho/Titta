#pragma once
#include <type_traits>

#include "mex_type_utils_fwd.h"
#include "pack_utils.h"

namespace mxTypes
{
    // needed helper to be able to do static_assert(false,...) in some constexpr if branches below, e.g. to mark them as todo TODO
    template <class...> constexpr std::false_type always_false{};

    // functionality to convert C++ types to MATLAB ClassIDs and back
    template <typename T> struct typeToMxClass { static_assert(always_false<T>, "mxClassID not implemented for this type"); static constexpr mxClassID value = mxUNKNOWN_CLASS; };
    template <>           struct typeToMxClass<double  > { static constexpr mxClassID value = mxDOUBLE_CLASS; };
    template <>           struct typeToMxClass<float   > { static constexpr mxClassID value = mxSINGLE_CLASS; };
    template <>           struct typeToMxClass<bool    > { static constexpr mxClassID value = mxLOGICAL_CLASS; };
    template <>           struct typeToMxClass<uint64_t> { static constexpr mxClassID value = mxUINT64_CLASS; };
    template <>           struct typeToMxClass<int64_t > { static constexpr mxClassID value = mxINT64_CLASS; };
    template <>           struct typeToMxClass<uint32_t> { static constexpr mxClassID value = mxUINT32_CLASS; };
    template <>           struct typeToMxClass<int32_t > { static constexpr mxClassID value = mxINT32_CLASS; };
    template <>           struct typeToMxClass<uint16_t> { static constexpr mxClassID value = mxUINT16_CLASS; };
    template <>           struct typeToMxClass<int16_t > { static constexpr mxClassID value = mxINT16_CLASS; };
    template <>           struct typeToMxClass<uint8_t > { static constexpr mxClassID value = mxUINT8_CLASS; };
    template <>           struct typeToMxClass<int8_t  > { static constexpr mxClassID value = mxINT8_CLASS; };
    template <typename T>
    constexpr mxClassID typeToMxClass_v = typeToMxClass<T>::value;

    template <typename T>
    struct typeNeedsMxCellStorage
    {
        static constexpr bool value = !std::is_arithmetic_v<T>; // true for integrals and floating point, and bool is included in integral
    };
    template <typename T>
    constexpr bool typeNeedsMxCellStorage_v = typeNeedsMxCellStorage<T>::value;

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

    //// converters of generic data types to MATLAB variables
    //// to simple variables
    // forward declarations
    mxArray* ToMatlab(std::string str_);

    template<class T>
    typename std::enable_if_t<!is_container_v<T>, mxArray*>
        ToMatlab(T val_);

    template<class Cont>
    typename std::enable_if_t<is_container_v<Cont>, mxArray*>
        ToMatlab(Cont data_);
    template <class... Types>  mxArray* ToMatlab(std::variant<Types...> val_);
    template <class T>         mxArray* ToMatlab(std::optional<T> val_);
    template <class T>         mxArray* ToMatlab(std::shared_ptr<T> val_);

    // implementations
    mxArray* ToMatlab(std::string str_)
    {
        return mxCreateString(str_.c_str());
    }

    template<class T>
    typename std::enable_if_t<!is_container_v<T>, mxArray*>
        ToMatlab(T val_)
    {
        static_assert(!typeNeedsMxCellStorage_v<T>, "T must be arithmetic. Implement a specialization of ToMxArray for your type");
        mxArray* temp;
        auto storage = static_cast<T*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, 1, typeToMxClass_v<T>, mxREAL)));
        *storage = val_;
        return temp;
    }

    template<class Cont>
    typename std::enable_if_t<is_container_v<Cont>, mxArray*>
        ToMatlab(Cont data_)
    {
        mxArray* temp = nullptr;
        using V = typename Cont::value_type;
        if constexpr (typeNeedsMxCellStorage_v<V>)
        {
            temp = mxCreateCellMatrix(static_cast<mwSize>(data_.size()), 1);
            mwIndex i = 0;
            for (auto& item : data_)
                mxSetCell(temp, i++, ToMatlab(item));
        }
        else if constexpr (is_guaranteed_contiguous_v<Cont>&& typeToMxClass_v<V> != mxSTRUCT_CLASS)
        {
            auto storage = static_cast<V*>(mxGetData(temp = mxCreateUninitNumericMatrix(static_cast<mwSize>(data_.size()), 1, typeToMxClass_v<V>, mxREAL)));
            // contiguous storage, can memcopy
            if (data_.size())
                memcpy(storage, &data_[0], data_.size()*sizeof(data_[0]));
        }
        else if constexpr (typeToMxClass_v<V> == mxSTRUCT_CLASS)
        {
            mwIndex i = 0;
            if (!data_.size())
                temp = mxCreateDoubleMatrix(0, 0, mxREAL);
            else
                for (auto& item : data_)
                    temp = ToMatlab(item, i++, static_cast<mwSize>(data_.size()), temp);
        }
        else
        {
            static_assert(always_false<Cont>, "TODO: implement");
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
        if constexpr (std::is_invocable_v<OutOrFun, last<0, Obj, Ts...>>)
            return o(getField(obj, fields...));
        else
            return static_cast<OutOrFun>(getField(obj, fields...));
    }

    template <typename Obj, typename... Fs>
    constexpr auto getFieldWrapper(const Obj& obj, Fs... fields)
    {
        // if last is pointer-to-member-variable, but previous is not (this would be a type tag then), swap the last two to put the type tag last
        if      constexpr (sizeof...(Fs) > 1 && std::is_member_object_pointer_v<last<0, Obj, Fs...>> && !std::is_member_object_pointer_v<last<1, Obj, Fs...>>)
            return rotate_right_except_last(
            [&](auto... elems) constexpr
            {
                return getField(obj, elems...);
            }, fields...);
        // if last is pointer-to-member-variable, no casting of return value requested through type tag, call getField
        else if constexpr (std::is_member_object_pointer_v<last<0, Obj, Fs...>>)
            return getField(obj, fields...);
        // if last is an enum, compare the value of the field to it
        // this turns enum fields into a boolean given reference enum value for which true should be returned
        else if constexpr (std::is_enum_v<last<0, Obj, Fs...>>)
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