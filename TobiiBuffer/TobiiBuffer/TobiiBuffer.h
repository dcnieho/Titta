#pragma once
#include <vector>
#include <array>
#include <string>
#include <limits>
#include <tuple>
#include <optional>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <tobii_research.h>
#include <tobii_research_eyetracker.h>
#include <tobii_research_streams.h>
#include <tobii_research_calibration.h>
#pragma comment(lib, "tobii_research.lib")
#ifndef _DEBUG
#   pragma comment(lib, "TobiiBuffer.lib")
#else
#   pragma comment(lib, "TobiiBuffer_d.lib")
#endif

#include "types.h"


class TobiiBuffer
{
public:
    // short names for very long Tobii data types
    using gaze       = TobiiResearchGazeData;
    using eyeImage   = TobiiTypes::eyeImage;
    using extSignal  = TobiiResearchExternalSignalData;
    using timeSync   = TobiiResearchTimeSynchronizationData;
    using logMessage = TobiiTypes::logMessage;

    // data stream type (NB: not log, as that isn't a class member)
    enum class DataStream
    {
        Unknown,
        Gaze,
        EyeImage,
        ExtSignal,
        TimeSync
    };
    // "gaze", "eyeImage", "externalSignal", or "timeSync"
    static TobiiBuffer::DataStream stringToDataStream(std::string stream_);
    static std::string dataStreamToString(TobiiBuffer::DataStream stream_);

public:
    TobiiBuffer(std::string address_);
    TobiiBuffer(TobiiResearchEyeTracker* et_);
    ~TobiiBuffer();

    // calibration
    void enterCalibrationMode(bool doMonocular_);
    void leaveCalibrationMode(bool force_);
    void calibrationCollectData(std::array<double, 2> coordinates_, std::optional<std::string> eye_);
    TobiiTypes::CalibrationState calibrationCheckStatus();
    std::string calibrationCollectionStatus();
    void calibrationDiscardData(std::array<double, 2> coordinates_, std::optional<std::string> eye_);
    void calibrationComputeAndApply();
    std::optional<TobiiResearchCalibrationResult> calibrationRetrieveComputeAndApplyResult();


    // query if stream is supported
    bool hasStream(std::string stream_) const;
    bool hasStream(DataStream  stream_) const;

    // start stream
    bool start(std::string stream_, std::optional<size_t> initialBufferSize_ = std::nullopt, std::optional<bool> asGif_ = std::nullopt);
    bool start(DataStream  stream_, std::optional<size_t> initialBufferSize_ = std::nullopt, std::optional<bool> asGif_ = std::nullopt);

    // request stream state
    bool isBuffering(std::string stream_) const;
    bool isBuffering(DataStream  stream_) const;


    // consume samples (by default all)
    template <typename T>
    std::vector<T> consumeN(std::optional<size_t> firstN_ = std::nullopt);
    // consume samples within given timestamps (inclusive, by default whole buffer)
    template <typename T>
    std::vector<T> consumeTimeRange(std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // peek samples (by default only last one, can specify how many to peek from end of buffer)
    template <typename T>
    std::vector<T> peekN(std::optional<size_t> lastN_ = std::nullopt);
    // peek samples within given timestamps (inclusive, by default whole buffer)
    template <typename T>
    std::vector<T> peekTimeRange(std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // clear all buffer contents
    void clear(std::string stream_);
    void clear(DataStream  stream_);
    // clear contents buffer within given timestamps (inclusive, by default whole buffer)
    void clearTimeRange(std::string stream_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);
    void clearTimeRange(DataStream  stream_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // stop optionally deletes the buffer
    bool stop(std::string stream_, std::optional<bool> emptyBuffer_ = std::nullopt);
    bool stop(DataStream  stream_, std::optional<bool> emptyBuffer_ = std::nullopt);

    // logging
    static bool startLogging(std::optional<size_t> initialBufferSize_ = std::nullopt);
    static std::vector<TobiiBuffer::logMessage> getLog(std::optional<bool> clearLog_ = std::nullopt);
    static bool stopLogging();	// always clears buffer

private:
    // Tobii callbacks needs to be friends
    friend void TobiiGazeCallback       (TobiiResearchGazeData*                     gaze_data_, void* user_data);
    friend void TobiiEyeImageCallback   (TobiiResearchEyeImage*                     eye_image_, void* user_data);
    friend void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif*                  eye_image_, void* user_data);
    friend void TobiiExtSignalCallback  (TobiiResearchExternalSignalData*          ext_signal_, void* user_data);
    friend void TobiiTimeSyncCallback   (TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data);
    friend void TobiiLogCallback        (int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_);
    // calibration
    void calibrationThread();
    //// generic functions for internal use
    // helpers
    template <typename T>  std::vector<T>&  getBuffer();
    template <typename T>
                           std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator, bool>
                                            getIteratorsFromTimeRange(int64_t timeStart_, int64_t timeEnd_);
    // generic implementations
    template <typename T>  void             clearImpl(int64_t timeStart_, int64_t timeEnd_);

private:
    TobiiResearchEyeTracker*    _eyetracker             = nullptr;

    bool                        _recordingGaze          = false;
    std::vector<gaze>           _gaze;
    // TODO: make mutexes class members instead of globals so that we can have multiple instances of this class

    bool                        _recordingEyeImages     = false;
    std::vector<eyeImage>       _eyeImages;
    bool                        _eyeImIsGif             = false;

    bool                        _recordingExtSignal     = false;
    std::vector<extSignal>      _extSignal;

    bool                        _recordingTimeSync      = false;
    std::vector<timeSync>       _timeSync;

    static std::unique_ptr<
        std::vector<logMessage>>_logMessages;

    // calibration
    bool                                        _calibrationIsMonocular;
    std::thread                                 _calibrationThread;
    std::mutex									_calMutex;
    std::condition_variable_any                 _calibrationThreadNotify;
    std::atomic<TobiiTypes::CalibrationState>   _calibrationState;
    std::atomic<TobiiTypes::CalibrationAction>  _calibrationAction;
    std::array<double, 2>                       _calibrationCoordinates;
    std::string                                 _calibrationEye;
    std::atomic<TobiiResearchStatus>            _calibrationCollectionResult;
    std::atomic<TobiiResearchStatus>            _calibrationComputeResultStatus = TOBII_RESEARCH_STATUS_OK;
    TobiiResearchCalibrationResult*             _calibrationComputeResult = nullptr;
};