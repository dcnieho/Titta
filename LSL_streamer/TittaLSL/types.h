#pragma once
#include "Titta/types.h"

namespace LSLTypes
{
    // NB: almost the same as TobiiTypes::gazeData, but has remote and local time
    struct gaze
    {
        Titta::gaze gazeData;
        int64_t remoteSystemTimeStamp;   // copy of gazeData.system_time_stamp, for easy and uniform access
        int64_t localSystemTimeStamp;
    };

    struct eyeImage
    {
        Titta::eyeImage eyeImageData;
        int64_t remoteSystemTimeStamp;   // copy of eyeImageData.system_time_stamp, for easy and uniform access
        int64_t localSystemTimeStamp;
    };

    struct extSignal
    {
        Titta::extSignal extSignalData;
        int64_t remoteSystemTimeStamp;   // copy of extSignalData.system_time_stamp, for easy and uniform access
        int64_t localSystemTimeStamp;
    };

    struct timeSync
    {
        Titta::timeSync timeSyncData;
        int64_t remoteSystemTimeStamp;   // copy of timeSyncData.system_request_time_stamp, for easy and uniform access
        int64_t localSystemTimeStamp;
    };

    struct positioning
    {
        Titta::positioning positioningData;
        int64_t remoteSystemTimeStamp;   // positioning doesn't have a timestamp, so this is timestamp at which sample was sent
        int64_t localSystemTimeStamp;
    };
}
