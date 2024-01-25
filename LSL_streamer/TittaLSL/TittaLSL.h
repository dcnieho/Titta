#pragma once
#include <vector>
#include <deque>
#include <map>
#include <string>
#include <optional>
#include <atomic>
#include <variant>
#include <memory>
#include <thread>
#include <tobii_research.h>
#include <tobii_research_streams.h>
#pragma comment(lib, "lsl.lib")
#ifndef BUILD_FROM_SCRIPT
#   ifdef _DEBUG
#       pragma comment(lib, "TittaLSL_d.lib")
#   else
#       pragma comment(lib, "TittaLSL.lib")
#   endif
#endif

#include "Titta/types.h"
#include "Titta/Titta.h"
#include "TittaLSL/types.h"

#include "lsl_cpp.h"


namespace TittaLSL
{
    //// global SDK functions
    TobiiResearchSDKVersion getTobiiSDKVersion();
    int32_t getLSLVersion();

    class Streamer
    {
    public:
        Streamer(std::string address_);
        Streamer(TobiiResearchEyeTracker* et_);
        Streamer(const TobiiTypes::eyeTracker& et_);
        ~Streamer();

        void connect(std::string address_);
        void connect(TobiiResearchEyeTracker* et_);
        bool startOutlet(std::string   stream_, std::optional<bool> asGif_ = std::nullopt, bool snake_case_on_stream_not_found = false);
        bool startOutlet(Titta::Stream stream_, std::optional<bool> asGif_ = std::nullopt);
        void setIncludeEyeOpennessInGaze(bool include_);    // can be set before or after opening stream
        bool isStreaming(std::string   stream_, bool snake_case_on_stream_not_found = false) const;
        bool isStreaming(Titta::Stream stream_) const;
        void stopOutlet(std::string    stream_, bool snake_case_on_stream_not_found = false);
        void stopOutlet(Titta::Stream  stream_);

    private:
        static void CheckClocks();
        // Tobii callbacks need to be friends
        friend void GazeCallback(TobiiResearchGazeData* gaze_data_, void* user_data);
        friend void EyeOpennessCallback(TobiiResearchEyeOpennessData* openness_data_, void* user_data);
        friend void EyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data);
        friend void EyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data);
        friend void ExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data);
        friend void TimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data);
        friend void PositioningCallback(TobiiResearchUserPositionGuide* position_data_, void* user_data);
        // gaze + eye openness receiver
        void receiveSample(const TobiiResearchGazeData* gaze_data_, const TobiiResearchEyeOpennessData* openness_data_);
        // data pushers
        void pushSample(const Titta::gaze& sample_);
        void pushSample(Titta::eyeImage&& sample_);
        void pushSample(const Titta::extSignal& sample_);
        void pushSample(const Titta::timeSync& sample_);
        void pushSample(const Titta::positioning& sample_);
        // callback registration and deregistration
        bool start(Titta::Stream stream_, std::optional<bool> asGif_ = std::nullopt);
        bool stop(Titta::Stream stream_);

    private:
        std::unique_ptr<TobiiTypes::eyeTracker>
            _localEyeTracker;

        std::map<Titta::Stream,
                 lsl::stream_outlet>    _outStreams;

        // staging area to merge gaze and eye openness
        std::deque<Titta::gaze>         _gazeStaging;
        std::atomic<bool>               _gazeStagingEmpty = true;
        bool                            _includeEyeOpennessInGaze = false;
        mutex_type                      _gazeStageMutex;

        bool                            _streamingGaze = false;
        bool                            _streamingEyeOpenness = false;
        bool                            _streamingEyeImages = false;
        bool                            _eyeImIsGif = false;
        bool                            _streamingExtSignal = false;
        bool                            _streamingTimeSync = false;
        bool                            _streamingPositioning = false;
    };

    class Receiver
    {
    public:
        template <class DataType>
        class Inlet
        {
        public:
            Inlet(const lsl::stream_info& streamInfo_) :
                _lsl_inlet(streamInfo_)
            {}

            lsl::stream_inlet               _lsl_inlet;
            std::vector<DataType>           _buffer;
            mutex_type                      _mutex;
            std::unique_ptr<std::thread>    _recorder;
            std::atomic<bool>               _recorder_should_stop;
        };

        // short names for very long Tobii data types
        using gaze = LSLTypes::gaze;       // getInletType() -> Titta::Stream::Gaze
        using eyeImage = LSLTypes::eyeImage;   // getInletType() -> Titta::Stream::EyeImage
        using extSignal = LSLTypes::extSignal;  // getInletType() -> Titta::Stream::ExtSignal
        using timeSync = LSLTypes::timeSync;   // getInletType() -> Titta::Stream::TimeSync
        using positioning = LSLTypes::positioning;// getInletType() -> Titta::Stream::Positioning
        using AllInlets = std::variant<
            Inlet<gaze>,
            Inlet<eyeImage>,
            Inlet<extSignal>,
            Inlet<timeSync>,
            Inlet<positioning>
        >;

        Receiver() = default;
        ~Receiver();

        // query what streams are available (optionally filter by type, empty string means no filter)
        static std::vector<lsl::stream_info> getRemoteStreams(std::string stream_ = "", bool snake_case_on_stream_not_found = false);
        static std::vector<lsl::stream_info> getRemoteStreams(std::optional<Titta::Stream> stream_ = {});
        // subscribe to stream, allocate buffer resources
        [[nodiscard]] uint32_t createListener(lsl::stream_info streamInfo_, std::optional<size_t> initialBufferSize_ = std::nullopt, std::optional<bool> doStartListening_ = std::nullopt);
        [[nodiscard]] uint32_t createListener(std::string streamSourceID_, std::optional<size_t> initialBufferSize_ = std::nullopt, std::optional<bool> doStartListening_ = std::nullopt);

        // info about inlet (desc is set now)
        lsl::stream_info getInletInfo(uint32_t id_) const;
        Titta::Stream    getInletType(uint32_t id_) const;

        // actually start pulling samples from it
        void startListening(uint32_t id_);
        bool isListening(uint32_t id_) const;

        // consume samples (by default all)
        template <typename DataType>    // e.g. TittaLSL::gaze
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

        // stop, optionally deletes the buffer. Can be continued with startListening()
        void stopListening(uint32_t id_, std::optional<bool> clearBuffer_ = std::nullopt);

        // delete the listener and associated resources
        void deleteListener(uint32_t);

    private:
        static uint32_t getID();
        // helper
        template <typename DataType>
        friend void checkInletType(AllInlets& inlet_, uint32_t id_);
        AllInlets& getAllInletsVariant(uint32_t id_) const;
        static std::unique_ptr<std::thread>& getWorkerThread(AllInlets& inlet_);
        static bool getWorkerThreadStopFlag(AllInlets& inlet_);
        static void setWorkerThreadStopFlag(AllInlets& inlet_);
        template <typename DataType>
        Inlet<DataType>& getInlet(uint32_t id_) const;
        // worker function
        template <typename DataType>
        void recorderThreadFunc(uint32_t id_);

    private:
        std::map<uint32_t, std::unique_ptr<AllInlets>>  _inStreams;
    };
}
