#pragma once
#include <vector>
#include <string>
#include <limits>
#include <tuple>
#include <tobii_research.h>
#include <tobii_research_eyetracker.h>
#include <tobii_research_streams.h>
#pragma comment(lib, "tobii_research.lib")
#ifndef _DEBUG
#   pragma comment(lib, "TobiiBuffer.lib")
#else
#   pragma comment(lib, "TobiiBuffer_d.lib")
#endif

#include "types.h"


namespace TobiiBuff
{
    // default argument values
    constexpr size_t  g_sampleBufDefaultSize = 1 << 22;
    constexpr size_t  g_sampleTempBufDefaultSize = 1 << 16;

    constexpr size_t  g_eyeImageBufDefaultSize = 1 << 14;
    constexpr bool    g_eyeImageAsGIFDefault = false;
    constexpr size_t  g_eyeImageTempBufDefaultSize = 1 << 10;

    constexpr size_t  g_extSignalBufDefaultSize = 1 << 14;
    constexpr size_t  g_extSignalTempBufDefaultSize = 1 << 10;

    constexpr size_t  g_timeSyncBufDefaultSize = 1 << 14;
    constexpr size_t  g_timeSyncTempBufDefaultSize = 1 << 10;

    constexpr int64_t g_clearTimeRangeStart = 0;
    constexpr int64_t g_clearTimeRangeEnd = std::numeric_limits<int64_t>::max();

    constexpr bool    g_stopBufferEmptiesDefault = false;
    constexpr size_t  g_consumeDefaultAmount = -1;
    constexpr int64_t g_consumeTimeRangeStart = 0; 
    constexpr int64_t g_consumeTimeRangeEnd = std::numeric_limits<int64_t>::max();
    constexpr size_t  g_peekDefaultAmount = 1;
    constexpr int64_t g_peekTimeRangeStart = 0;
    constexpr int64_t g_peekTimeRangeEnd = std::numeric_limits<int64_t>::max();

    constexpr size_t  g_logBufDefaultSize = 1 << 9;
    constexpr bool    g_logBufClearDefault = true;
}


class TobiiBuffer
{
public:
    // short names for very long Tobii data types
    using sample     = TobiiResearchGazeData;
    using eyeImage   = TobiiBuff::eyeImage;
    using extSignal  = TobiiResearchExternalSignalData;
    using timeSync   = TobiiResearchTimeSynchronizationData;
    using logMessage = TobiiBuff::logMessage;

    // data stream type (NB: not log, that has a much simpler interface)
    enum class DataStream
    {
        Unknown,
        Sample,
        EyeImage,
        ExtSignal,
        TimeSync
    };

public:
    TobiiBuffer(std::string address_);
    TobiiBuffer(TobiiResearchEyeTracker* et_);
    ~TobiiBuffer();

    //// Functions taking buffer type as input ////
    // clear all buffer contents
    void clear(std::string dataStream_);
    void clearTimeRange(std::string dataStream_, int64_t timeStart_ = TobiiBuff::g_clearTimeRangeStart, int64_t timeEnd_ = TobiiBuff::g_clearTimeRangeEnd);
    // stop optionally deletes the buffer
    bool stop(std::string dataStream_, bool emptyBuffer_ = TobiiBuff::g_stopBufferEmptiesDefault);
    // can't have functions that only differ by return type, so must template these instead of take
    // 'stream' string input
    // consume samples (by default all)
    template <typename T> std::vector<T> consumeN(size_t firstN_ = TobiiBuff::g_consumeDefaultAmount);
    template <typename T> std::vector<T> consumeTimeRange(int64_t timeStart_ = TobiiBuff::g_consumeTimeRangeStart, int64_t timeEnd_ = TobiiBuff::g_consumeTimeRangeEnd);
    // peek samples (by default only last one, can specify how many from end to peek)
    template <typename T> std::vector<T> peekN(size_t lastN_ = TobiiBuff::g_peekDefaultAmount);
    template <typename T> std::vector<T> peekTimeRange(int64_t timeStart_ = TobiiBuff::g_peekTimeRangeStart, int64_t timeEnd_ = TobiiBuff::g_peekTimeRangeEnd);

    //// stream starters ////
    bool startSample(size_t initialBufferSize_ = TobiiBuff::g_sampleBufDefaultSize);
    bool startEyeImage(size_t initialBufferSize_ = TobiiBuff::g_eyeImageBufDefaultSize, bool asGif_ = TobiiBuff::g_eyeImageAsGIFDefault);
    bool startExtSignal(size_t initialBufferSize_ = TobiiBuff::g_extSignalBufDefaultSize);
    bool startTimeSync(size_t initialBufferSize_ = TobiiBuff::g_timeSyncBufDefaultSize);

private:
    // Tobii callbacks needs to be friends
    friend void TobiiSampleCallback     (TobiiResearchGazeData*                     gaze_data_, void* user_data);
    friend void TobiiEyeImageCallback   (TobiiResearchEyeImage*                     eye_image_, void* user_data);
    friend void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif*                  eye_image_, void* user_data);
    friend void TobiiExtSignalCallback  (TobiiResearchExternalSignalData*          ext_signal_, void* user_data);
    friend void TobiiTimeSyncCallback   (TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data);

    //// generic functions for internal use
    // helpers
    template <typename T>  std::vector<T>&  getBuffer();
    template <typename T>
                           std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator, bool>
                                            getIteratorsFromTimeRange(int64_t timeStart_, int64_t timeEnd_);
    // generic implementations
    template <typename T>  void             clearImpl(int64_t timeStart_, int64_t timeEnd_);
    template <typename T>  bool             stopImpl(bool emptyBuffer_);
private:

    TobiiResearchEyeTracker*	_eyetracker				= nullptr;

    std::vector<sample>		    _samples;

    bool					    _recordingEyeImages		= false;
    std::vector<eyeImage>	    _eyeImages;
    bool					    _eyeImIsGif				= false;

    std::vector<extSignal>	    _extSignal;

    std::vector<timeSync>       _timeSync;
};


namespace TobiiBuff
{
    TobiiBuffer::DataStream stringToDataStream(std::string dataStream_);

    //// logging ////
    bool startLogging(size_t initialBufferSize_ = TobiiBuff::g_logBufDefaultSize);
    std::vector<TobiiBuff::logMessage> getLog(bool clearLog_ = g_logBufClearDefault);
    bool stopLogging();	// always clears buffer
}