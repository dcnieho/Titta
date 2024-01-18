#pragma once
#include <vector>
#include <deque>
#include <map>
#include <string>
#include <optional>
#include <atomic>
#include <variant>
#include <tobii_research.h>
#include <tobii_research_streams.h>
#pragma comment(lib, "tobii_research.lib")
#ifndef BUILD_FROM_SCRIPT
#   ifdef _DEBUG
#       pragma comment(lib, "LSL_streamer_d.lib")
#   else
#       pragma comment(lib, "LSL_streamer.lib")
#   endif
#endif

#include "Titta/types.h"
#include "Titta/Titta.h"

#include "lsl_cpp.h"


class LSL_streamer
{
template <class DataType>
class Inlet
{
public:
    lsl::stream_inlet       _inlet;
    std::vector<DataType>   _buffer;
    mutex_type              _mutex;
};
public:
    using AllInlets = std::variant<
                        Inlet<Titta::gaze>,
                        Inlet<Titta::eyeImage>,
                        Inlet<Titta::extSignal>,
                        Inlet<Titta::timeSync>,
                        Inlet<Titta::positioning>
                    >;

public:
    LSL_streamer(std::string address_);
    LSL_streamer(TobiiResearchEyeTracker* et_);
    LSL_streamer(TobiiTypes::eyeTracker et_);
    ~LSL_streamer();

    //// global SDK functions
    static TobiiResearchSDKVersion getTobiiSDKVersion();
    static int32_t getLSLVersion();

    //// outlets
    bool startOutlet(std::string   stream_, std::optional<bool> asGif_ = std::nullopt, bool snake_case_on_stream_not_found = false);
    bool startOutlet(Titta::Stream stream_, std::optional<bool> asGif_ = std::nullopt);
    void setIncludeEyeOpennessInGaze(bool include_);    // can be set before or after opening stream
    bool isStreaming(std::string   stream_, bool snake_case_on_stream_not_found = false) const;
    bool isStreaming(Titta::Stream stream_) const;
    void stopOutlet(std::string   stream_, bool snake_case_on_stream_not_found = false);
    void stopOutlet(Titta::Stream stream_);

    //// inlets
    // query what streams are available (optionally filter by type)
    std::vector<lsl::stream_info> getRemoteStreams(std::optional<std::string> stream_ = {}, bool snake_case_on_stream_not_found = false);
    std::vector<lsl::stream_info> getRemoteStreams(std::optional<Titta::Stream> stream_ = {});
    // subscribe to stream
    [[nodiscard]] uint32_t startListening(lsl::stream_info streamInfo_);

    // consume samples (by default all)
    template <typename DataType>    // e.g. Titta::gaze
    std::vector<DataType> consumeN(uint32_t id_, std::optional<size_t> NSamp_ = std::nullopt, std::optional<Titta::BufferSide> side_ = std::nullopt);
    // consume samples within given timestamps (inclusive, by default whole buffer)
    template <typename DataType>
    std::vector<DataType> consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // peek samples (by default only last one, can specify how many to peek, and from which side of buffer)
    template <typename DataType>
    std::vector<DataType> peekN(uint32_t id_, std::optional<size_t> NSamp_ = std::nullopt, std::optional<Titta::BufferSide> side_ = std::nullopt);
    // peek samples within given timestamps (inclusive, by default whole buffer)
    template <typename DataType>
    std::vector<DataType> peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // clear all buffer contents
    void clear(uint32_t id_);
    // clear contents buffer within given timestamps (inclusive, by default whole buffer)
    void clearTimeRange(uint32_t id_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // stop, optionally deletes the buffer
    bool stopListening(uint32_t id_, std::optional<bool> clearBuffer_ = std::nullopt);

private:
    void Init();
    static uint32_t getID();
    // Tobii callbacks need to be friends
    friend void LSLGazeCallback       (TobiiResearchGazeData*                     gaze_data_, void* user_data);
    friend void LSLEyeOpennessCallback(TobiiResearchEyeOpennessData*          openness_data_, void* user_data);
    friend void LSLEyeImageCallback   (TobiiResearchEyeImage*                     eye_image_, void* user_data);
    friend void LSLEyeImageGifCallback(TobiiResearchEyeImageGif*                  eye_image_, void* user_data);
    friend void LSLExtSignalCallback  (TobiiResearchExternalSignalData*          ext_signal_, void* user_data);
    friend void LSLTimeSyncCallback   (TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data);
    friend void LSLPositioningCallback(TobiiResearchUserPositionGuide*        position_data_, void* user_data);
    // gaze + eye openness receiver
    void receiveSample(TobiiResearchGazeData* gaze_data_, TobiiResearchEyeOpennessData* openness_data_);
    // data pushers
    void pushSample(Titta::gaze sample_);
    void pushSample(Titta::eyeImage&& sample_);
    void pushSample(Titta::extSignal sample_);
    void pushSample(Titta::timeSync sample_);
    void pushSample(Titta::positioning sample_);

    // helper
    template <typename DataType>
    Inlet<DataType>& getInlet(uint32_t id_);

    // callback registration and deregistration
    bool start(Titta::Stream stream_, std::optional<bool> asGif_ = std::nullopt);
    bool stop(Titta::Stream stream_);

private:
    TobiiTypes::eyeTracker                      _localEyeTracker;

    std::map<Titta::Stream, lsl::stream_outlet> _outStreams;
    std::map<uint32_t, AllInlets>               _inStreams;


    bool                            _streamingGaze          = false;
    bool                            _streamingEyeOpenness   = false;
    bool                            _includeEyeOpennessInGaze = false;
    std::vector<Titta::gaze>        _gaze;
    mutex_type                      _gazeMutex;
    // staging area to merge gaze and eye openness
    std::deque<Titta::gaze>         _gazeStaging;
    std::atomic<bool>               _gazeStagingEmpty       = true;
    mutex_type                      _gazeStageMutex;

    bool                            _streamingEyeImages     = false;
    std::vector<Titta::eyeImage>    _eyeImages;
    bool                            _eyeImIsGif             = false;
    mutex_type                      _eyeImagesMutex;

    bool                            _streamingExtSignal     = false;
    std::vector<Titta::extSignal>   _extSignal;
    mutex_type                      _extSignalMutex;

    bool                            _streamingTimeSync      = false;
    std::vector<Titta::timeSync>    _timeSync;
    mutex_type                      _timeSyncMutex;

    bool                            _streamingPositioning   = false;
    std::vector<Titta::positioning> _positioning;
    mutex_type                      _positioningMutex;
};
