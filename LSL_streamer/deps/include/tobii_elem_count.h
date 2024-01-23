#pragma once
#include <tuple>
#include <tobii_research.h>


namespace {
    template <typename T>
    constexpr size_t getNumElements()
    {
        if      constexpr (std::is_same_v<T, TobiiResearchPoint3D>) // also matches TobiiResearchNormalizedPoint3D, as that's typedeffed to TobiiResearchPoint3D
            return 3;
        else if constexpr (std::is_same_v<T, TobiiResearchNormalizedPoint2D>)
            return 2;
        else
            return 1;
    }
}