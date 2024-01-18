#pragma once
#include "Titta/types.h"

namespace LSLTypes
{
    // NB: almost the same as TobiiTypes::gazeData, but has remote and local time
    struct gaze
    {
        Titta::gaze gazeData;
        int64_t local_system_time_stamp;
        int64_t remote_system_time_stamp;   // copy of gazeData.system_time_stamp, for easy and uniform access
    };

    struct eyeImage
    {
        Titta::eyeImage eyeImageData;
        int64_t local_system_time_stamp;
        int64_t remote_system_time_stamp;   // copy of eyeImageData.system_time_stamp, for easy and uniform access
    };

    struct extSignal
    {
        Titta::extSignal extSignalData;
        int64_t local_system_time_stamp;
        int64_t remote_system_time_stamp;   // copy of extSignalData.system_time_stamp, for easy and uniform access
    };

    struct timeSync
    {
        Titta::timeSync timeSyncData;
        int64_t local_system_time_stamp;
        int64_t remote_system_time_stamp;   // copy of timeSyncData.system_request_time_stamp, for easy and uniform access
    };
}
