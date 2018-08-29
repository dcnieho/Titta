#pragma once

#define DLL_EXPORT_SYM __declspec(dllexport)
#include "mex.h"

namespace {
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
}