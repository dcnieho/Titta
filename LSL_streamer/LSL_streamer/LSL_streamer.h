#pragma once
#include <vector>
#include <deque>
#include <map>
#include <string>
#include <optional>
#include <atomic>
#include <variant>
#include <memory>
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
#include "LSL_streamer/types.h"

#include "lsl_cpp.h"


class LSL_streamer
{
    template <class DataType>
    class Inlet
    {
    public:
        Inlet(const lsl::stream_info& streamInfo_) :
            _inlet(streamInfo_)
        {}

        lsl::stream_inlet       _inlet;
        std::vector<DataType>   _buffer;
        mutex_type              _mutex;
    };

public:
    // short names for very long Tobii data types
    using gaze          = LSLTypes::gaze;       // getInletType() -> Titta::Stream::Gaze
    using eyeImage      = LSLTypes::eyeImage;   // getInletType() -> Titta::Stream::EyeImage
    using extSignal     = LSLTypes::extSignal;  // getInletType() -> Titta::Stream::ExtSignal
    using timeSync      = LSLTypes::timeSync;   // getInletType() -> Titta::Stream::TimeSync
    using positioning   = Titta::positioning;   // getInletType() -> Titta::Stream::Positioning
    using AllInlets = std::variant<
                        Inlet<gaze>,
                        Inlet<eyeImage>,
                        Inlet<extSignal>,
                        Inlet<timeSync>,
                        Inlet<positioning>
                    >;

public:
    LSL_streamer() {};
    LSL_streamer(std::string address_);
    LSL_streamer(TobiiResearchEyeTracker* et_);
    LSL_streamer(const TobiiTypes::eyeTracker& et_);
    ~LSL_streamer();


    //// global SDK functions
    static TobiiResearchSDKVersion getTobiiSDKVersion();
    static int32_t getLSLVersion();


    //// outlets
    void connect(std::string address_);
    void connect(TobiiResearchEyeTracker* et_);
    bool startOutlet(std::string   stream_, std::optional<bool> asGif_ = std::nullopt, bool snake_case_on_stream_not_found = false);
    bool startOutlet(Titta::Stream stream_, std::optional<bool> asGif_ = std::nullopt);
    void setIncludeEyeOpennessInGaze(bool include_);    // can be set before or after opening stream
    bool isStreaming(std::string   stream_, bool snake_case_on_stream_not_found = false) const;
    bool isStreaming(Titta::Stream stream_) const;
    void stopOutlet(std::string    stream_, bool snake_case_on_stream_not_found = false);
    void stopOutlet(Titta::Stream  stream_);


    //// inlets
    // query what streams are available (optionally filter by type, empty string means no filter)
    static std::vector<lsl::stream_info> getRemoteStreams(std::string stream_ = "", bool snake_case_on_stream_not_found = false);
    static std::vector<lsl::stream_info> getRemoteStreams(std::optional<Titta::Stream> stream_ = {});
    // subscribe to stream
    [[nodiscard]] uint32_t startListening(lsl::stream_info streamInfo_);
    [[nodiscard]] uint32_t startListening(std::string streamSourceID_);

    // info about inlet (desc is set now)
    lsl::stream_info getInletInfo(uint32_t id_);
    Titta::Stream    getInletType(uint32_t id_);

    // consume samples (by default all)
    template <typename DataType>    // e.g. LSL_streamer::gaze
    std::vector<DataType> consumeN(uint32_t id_, std::optional<size_t> NSamp_ = std::nullopt, std::optional<Titta::BufferSide> side_ = std::nullopt);
    // consume samples within given timestamps (inclusive, by default whole buffer)
    template <typename DataType>
    std::vector<DataType> consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt, std::optional<bool> timeIsLocalTime_ = std::nullopt);

    // peek samples (by default only last one, can specify how many to peek, and from which side of buffer)
    template <typename DataType>
    std::vector<DataType> peekN(uint32_t id_, std::optional<size_t> NSamp_ = std::nullopt, std::optional<Titta::BufferSide> side_ = std::nullopt);
    // peek samples within given timestamps (inclusive, by default whole buffer)
    template <typename DataType>
    std::vector<DataType> peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt, std::optional<bool> timeIsLocalTime_ = std::nullopt);

    // clear all buffer contents
    void clear(uint32_t id_);
    // clear contents buffer within given timestamps (inclusive, by default whole buffer)
    void clearTimeRange(uint32_t id_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt, std::optional<bool> timeIsLocalTime_ = std::nullopt);

    // stop, optionally deletes the buffer
    bool stopListening(uint32_t id_, std::optional<bool> clearBuffer_ = std::nullopt);


private:
    // outlet stuff
    static void CheckClocks();
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
    // callback registration and deregistration
    bool start(Titta::Stream stream_, std::optional<bool> asGif_ = std::nullopt);
    bool stop(Titta::Stream stream_);


    // inlet stuff
    static uint32_t getID();
    // helper
    template <typename DataType>
    friend void checkInletType(LSL_streamer::AllInlets& inlet_, uint32_t id_);
    AllInlets& getAllInletsVariant(uint32_t id_);
    template <typename DataType>
    Inlet<DataType>& getInlet(uint32_t id_);


private:
    std::unique_ptr<TobiiTypes::eyeTracker>
                                    _localEyeTracker;

    // outgoing
    std::map<Titta::Stream,
             lsl::stream_outlet>    _outStreams;
    // staging area to merge gaze and eye openness
    std::deque<Titta::gaze>         _gazeStaging;
    std::atomic<bool>               _gazeStagingEmpty       = true;
    bool                            _includeEyeOpennessInGaze = false;
    mutex_type                      _gazeStageMutex;

    bool                            _streamingGaze          = false;
    bool                            _streamingEyeOpenness   = false;
    bool                            _streamingEyeImages     = false;
    bool                            _eyeImIsGif             = false;
    bool                            _streamingExtSignal     = false;
    bool                            _streamingTimeSync      = false;
    bool                            _streamingPositioning   = false;


    // incoming
    std::map<uint32_t, std::unique_ptr<AllInlets>>  _inStreams;
};
