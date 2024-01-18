#include "LSL_streamer/LSL_streamer.h"
#include <vector>
#include <algorithm>
#include <string_view>
#include <sstream>
#include <map>
#include <cstring>

#include "Titta/utils.h"

namespace
{
    // default argument values
    namespace defaults
    {
        constexpr size_t                sampleBufSize             = 2<<19;        // about half an hour at 600Hz

        constexpr size_t                eyeImageBufSize           = 2<<11;        // about seven minutes at 2*5Hz
        constexpr bool                  eyeImageAsGIF             = false;

        constexpr size_t                extSignalBufSize          = 2<<9;

        constexpr size_t                timeSyncBufSize           = 2<<9;

        constexpr size_t                positioningBufSize        = 2<<11;

        constexpr int64_t               clearTimeRangeStart       = 0;
        constexpr int64_t               clearTimeRangeEnd         = std::numeric_limits<int64_t>::max();

        constexpr bool                  stopBufferEmpties         = false;
        constexpr Titta::BufferSide     consumeSide               = Titta::BufferSide::Start;
        constexpr size_t                consumeNSamp              = -1;           // this overflows on purpose, consume all samples is default
        constexpr int64_t               consumeTimeRangeStart     = 0;
        constexpr int64_t               consumeTimeRangeEnd       = std::numeric_limits<int64_t>::max();
        constexpr Titta::BufferSide     peekSide                  = Titta::BufferSide::End;
        constexpr size_t                peekNSamp                 = 1;
        constexpr int64_t               peekTimeRangeStart        = 0;
        constexpr int64_t               peekTimeRangeEnd          = std::numeric_limits<int64_t>::max();
        constexpr bool                  timeIsLocalTime           = true;
    }
}

// callbacks
void LSLGazeCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        instance->receiveSample(gaze_data_, nullptr);
    }
}
void LSLEyeOpennessCallback(TobiiResearchEyeOpennessData* openness_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        instance->receiveSample(nullptr, openness_data_);
    }
}
void LSLEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        if (instance->isStreaming(Titta::Stream::EyeImage))
            instance->pushSample(eye_image_);
    }
}
void LSLEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        if (instance->isStreaming(Titta::Stream::EyeImage))
            instance->pushSample(eye_image_);
    }
}
void LSLExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        if (instance->isStreaming(Titta::Stream::ExtSignal))
            instance->pushSample(*ext_signal_);
    }
}
void LSLTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        if (instance->isStreaming(Titta::Stream::TimeSync))
            instance->pushSample(*time_sync_data_);
    }
}
void LSLPositioningCallback(TobiiResearchUserPositionGuide* position_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<LSL_streamer*>(user_data);
        if (instance->isStreaming(Titta::Stream::Positioning))
            instance->pushSample(*position_data_);
    }
}

// info getter static functions
TobiiResearchSDKVersion LSL_streamer::getTobiiSDKVersion()
{
    TobiiResearchSDKVersion sdk_version;
    TobiiResearchStatus status = tobii_research_get_sdk_version(&sdk_version);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get Tobii SDK version", status);
    return sdk_version;
}
int32_t LSL_streamer::getLSLVersion()
{
    return lsl::library_version();
}

namespace
{
    // eye image helpers
    TobiiResearchStatus doSubscribeEyeImage(TobiiResearchEyeTracker* eyeTracker_, LSL_streamer* instance_, const bool asGif_)
    {
        if (asGif_)
            return tobii_research_subscribe_to_eye_image_as_gif(eyeTracker_, LSLEyeImageGifCallback, instance_);
        else
            return tobii_research_subscribe_to_eye_image       (eyeTracker_,    LSLEyeImageCallback, instance_);
    }
    TobiiResearchStatus doUnsubscribeEyeImage(TobiiResearchEyeTracker* eyeTracker_, const bool isGif_)
    {
        if (isGif_)
            return tobii_research_unsubscribe_from_eye_image_as_gif(eyeTracker_, LSLEyeImageGifCallback);
        else
            return tobii_research_unsubscribe_from_eye_image       (eyeTracker_,    LSLEyeImageCallback);
    }
}




LSL_streamer::LSL_streamer(std::string address_)
{
    TobiiResearchEyeTracker* et;
    TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(),&et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker \"" + address_ + "\"", status);
    _localEyeTracker = TobiiTypes::eyeTracker(et);
    Init();
}
LSL_streamer::LSL_streamer(TobiiResearchEyeTracker* et_)
{
    _localEyeTracker = TobiiTypes::eyeTracker(et_);
    Init();
}
LSL_streamer::LSL_streamer(TobiiTypes::eyeTracker et_)
    : _localEyeTracker(et_)
{
    Init();
}
LSL_streamer::~LSL_streamer()
{
    stopOutlet(Titta::Stream::Gaze);
    stopOutlet(Titta::Stream::EyeOpenness);
    stopOutlet(Titta::Stream::EyeImage);
    stopOutlet(Titta::Stream::ExtSignal);
    stopOutlet(Titta::Stream::TimeSync);
    stopOutlet(Titta::Stream::Positioning);
}
uint32_t LSL_streamer::getID()
{
    static std::atomic<uint32_t> lastID = 0;
    return lastID++;
}
void LSL_streamer::Init()
{

}


// helpers to make the below generic
namespace {
template <typename DataType>
read_lock  lockForReading(LSL_streamer::Inlet<DataType>& inlet_) { return  read_lock(inlet_._mutex); }
template <typename DataType>
write_lock lockForWriting(LSL_streamer::Inlet<DataType>& inlet_) { return write_lock(inlet_._mutex); }
template <typename DataType>
std::vector<DataType>& getBuffer(LSL_streamer::Inlet<DataType>& inlet_)
{
    return inlet_._buffer;
}
template <typename DataType>
std::tuple<typename std::vector<DataType>::iterator, typename std::vector<DataType>::iterator>
getIteratorsFromSampleAndSide(std::vector<DataType>& buf_, size_t NSamp_, Titta::BufferSide side_)
{
    auto startIt = std::begin(buf_);
    auto   endIt = std::end(buf_);
    auto nSamp   = std::min(NSamp_, std::size(buf_));

    switch (side_)
    {
    case Titta::BufferSide::Start:
        endIt   = std::next(startIt, nSamp);
        break;
    case Titta::BufferSide::End:
        startIt = std::prev(endIt  , nSamp);
        break;
    default:
        DoExitWithMsg("LSL_streamer::::cpp::getIteratorsFromSampleAndSide: unknown Titta::BufferSide provided.");
        break;
    }
    return { startIt, endIt };
}

template <typename DataType>
std::tuple<typename std::vector<DataType>::iterator, typename std::vector<DataType>::iterator, bool>
getIteratorsFromTimeRange(std::vector<DataType>& buf_, int64_t timeStart_, int64_t timeEnd_, bool timeIsLocalTime_)
{
    // !NB: appropriate locking is responsibility of caller!
    // find elements within given range of time stamps, both sides inclusive.
    // Since returns are iterators, what is returned is first matching element until one past last matching element
    // 1. get buffer to traverse, if empty, return
    auto startIt = std::begin(buf_);
    auto   endIt = std::end(buf_);
    if (std::empty(buf_))
        return {startIt,endIt, true};

    // 2. see which member variable to access
    int64_t DataType::* field;
    if (timeIsLocalTime_)
        field = &DataType::local_system_time_stamp;
    else
        field = &DataType::remote_system_time_stamp;

    // 3. check if requested times are before or after vector start and end
    bool inclFirst = timeStart_ <= buf_.front().*field;
    bool inclLast  = timeEnd_   >= buf_.back().*field;

    // 4. if start time later than beginning of samples, or end time earlier, find correct iterators
    if (!inclFirst)
        startIt = std::lower_bound(startIt, endIt, timeStart_, [&field](const DataType& a_, const int64_t& b_) {return a_.*field < b_;});
    if (!inclLast)
        endIt   = std::upper_bound(startIt, endIt, timeEnd_  , [&field](const int64_t& a_, const DataType& b_) {return a_ < b_.*field;});

    // 5. done, return
    return {startIt, endIt, inclFirst&&inclLast};
}
}


bool LSL_streamer::startOutlet(std::string stream_, std::optional<bool> asGif_, bool snake_case_on_stream_not_found /*= false*/)
{
    return startOutlet(Titta::stringToStream(stream_, snake_case_on_stream_not_found), asGif_);
}
bool LSL_streamer::startOutlet(Titta::Stream stream_, std::optional<bool> asGif_)
{
    // if already streaming, don't start again
    if (isStreaming(stream_))
        return false;

    // for gaze signal, get info about the eye tracker's gaze stream
    auto hasFreq = stream_ == Titta::Stream::Gaze || stream_ == Titta::Stream::EyeOpenness;
    if (hasFreq)
        _localEyeTracker.refreshInfo();

    std::string type;
    int nChannel = 0;
    auto format = lsl::cf_float32;
    switch (stream_)
    {
    case Titta::Stream::Gaze:
    case Titta::Stream::EyeOpenness:
        type = "Gaze";
        nChannel = 42;
        break;
    case Titta::Stream::EyeImage:
        if (asGif_)
            type = "VideoCompressed";
        else
            type = "VideoRaw";
        break;
    case Titta::Stream::ExtSignal:
        type = "TTL";
        nChannel = 2;
        format = lsl::cf_int64;
        break;
    case Titta::Stream::TimeSync:
        type = "TimeSync";
        nChannel = 3;
        format = lsl::cf_int64;
        break;
    case Titta::Stream::Positioning:
        type = "Positioning";
        nChannel = 8;
        break;
    default:
        DoExitWithMsg(std::format("LSL_streamer::cpp::startOutlet: opening an outlet for {} stream is not supported.", Titta::streamToString(stream_)));
        break;
    }

    // set up the outlet
    auto streamName = Titta::streamToString(stream_);
    auto lslStreamName = std::format("Tobii_{}", streamName);
    lsl::stream_info info(lslStreamName,
        type,
        nChannel,
        hasFreq ? _localEyeTracker.frequency : lsl::IRREGULAR_RATE,
        format,
        std::format("{}@{}", lslStreamName, _localEyeTracker.serialNumber));

    // create meta-data
    info.desc()
        .append_child("acquisition")
        .append_child_value("manufacturer", "Tobii")
        .append_child_value("model", _localEyeTracker.model)
        .append_child_value("serial_number", _localEyeTracker.serialNumber)
        .append_child_value("firmware_version", _localEyeTracker.firmwareVersion)
        .append_child_value("tracking_mode", _localEyeTracker.trackingMode);
    auto channels = info.desc().append_child("channels");

    // describe the streams
    switch (stream_)
    {
    case Titta::Stream::Gaze:
        [[fallthrough]];
    case Titta::Stream::EyeOpenness:
        channels.append_child("channel")
            .append_child_value("label", "x.position_on_display_area.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ScreenX")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "y.position_on_display_area.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ScreenY")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "x.position_in_user_coordinates.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "IntersectionX")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "y.position_in_user_coordinates.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "IntersectionY")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "z.position_in_user_coordinates.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "IntersectionZ")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "valid.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.gaze_point.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "diameter.pupil.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "Diameter")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "valid.pupil.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.pupil.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "x.position_in_user_coordinates.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PupilX")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "y.position_in_user_coordinates.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PupilY")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "z.position_in_user_coordinates.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PupilZ")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "x.position_in_track_box_coordinates.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PupilX")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "y.position_in_track_box_coordinates.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PupilY")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "z.position_in_track_box_coordinates.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PupilZ")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "valid.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.gaze_origin.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "diameter.eye_openness.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "EyeLidDistance")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "valid.eye_openness.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.eye_openness.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");


        channels.append_child("channel")
            .append_child_value("label", "x.position_on_display_area.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ScreenX")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "y.position_on_display_area.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ScreenY")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "x.position_in_user_coordinates.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "IntersectionX")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "y.position_in_user_coordinates.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "IntersectionY")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "z.position_in_user_coordinates.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "IntersectionZ")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "valid.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.gaze_point.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "diameter.pupil.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "Diameter")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "valid.pupil.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.pupil.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "x.position_in_user_coordinates.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PupilX")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "y.position_in_user_coordinates.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PupilY")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "z.position_in_user_coordinates.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PupilZ")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "x.position_in_track_box_coordinates.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PupilX")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "y.position_in_track_box_coordinates.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PupilY")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "z.position_in_track_box_coordinates.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PupilZ")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "valid.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.gaze_origin.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "diameter.eye_openness.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "EyeLidDistance")
            .append_child_value("unit", "mm");
        channels.append_child("channel")
            .append_child_value("label", "valid.eye_openness.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        channels.append_child("channel")
            .append_child_value("label", "available.eye_openness.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "AvailableFlag")
            .append_child_value("unit", "bool");

    case Titta::Stream::EyeImage:
        if (asGif_)
            type = "VideoCompressed";
        else
            type = "VideoRaw";
        break;
    case Titta::Stream::ExtSignal:
        channels.append_child("channel")
            .append_child_value("label", "device_time_stamp")
            .append_child_value("type", "TimeStamp")
            .append_child_value("unit", "us");
        channels.append_child("channel")
            .append_child_value("label", "value")
            .append_child_value("type", "TTLIn");
        break;
    case Titta::Stream::TimeSync:
        channels.append_child("channel")
            .append_child_value("label", "system_request_time_stamp")
            .append_child_value("type", "TimeStamp")
            .append_child_value("unit", "us");
        channels.append_child("channel")
            .append_child_value("label", "device_time_stamp")
            .append_child_value("type", "TimeStamp")
            .append_child_value("unit", "us");
        channels.append_child("channel")
            .append_child_value("label", "system_response_time_stamp")
            .append_child_value("type", "TimeStamp")
            .append_child_value("unit", "us");
        break;
    case Titta::Stream::Positioning:
        channels.append_child("channel")
            .append_child_value("label", "x.user_position.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PositionX")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "y.user_position.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PositionY")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "z.user_position.left_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "PositionZ")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "valid.user_position.right_eye")
            .append_child_value("eye", "left")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");

        channels.append_child("channel")
            .append_child_value("label", "x.user_position.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PositionX")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "y.user_position.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PositionY")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "z.user_position.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "PositionZ")
            .append_child_value("unit", "normalized");
        channels.append_child("channel")
            .append_child_value("label", "valid.user_position.right_eye")
            .append_child_value("eye", "right")
            .append_child_value("type", "ValidFlag")
            .append_child_value("unit", "bool");
        break;
    }

    // make the outlet
    _outStreams.insert(std::make_pair(stream_,lsl::stream_outlet(info, 1)));

    // start the eye tracker stream
    return start(stream_, asGif_);
}


void LSL_streamer::setIncludeEyeOpennessInGaze(bool include_)
{
    if (include_ && !(_localEyeTracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA))
        DoExitWithMsg(
            "LSL_streamer::cpp::setIncludeEyeOpennessInGaze: Cannot request to record the " + Titta::streamToString(Titta::Stream::EyeOpenness) + " stream, this eye tracker does not provide it"
        );

    _includeEyeOpennessInGaze = include_;

    // start/stop eye openness stream if needed
    if (_streamingGaze && !_includeEyeOpennessInGaze)
        stop(Titta::Stream::EyeOpenness);
    else if (_streamingGaze && _includeEyeOpennessInGaze)
        start(Titta::Stream::EyeOpenness);
}

bool LSL_streamer::start(Titta::Stream stream_, std::optional<bool> asGif_)
{
    TobiiResearchStatus result=TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
        case Titta::Stream::Gaze:
        {
            if (_streamingGaze)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // start sending
                result = tobii_research_subscribe_to_gaze_data(_localEyeTracker.et, LSLGazeCallback, this);
                stateVar = &_streamingGaze;
            }
            break;
        }
        case Titta::Stream::EyeOpenness:
        {
            if (_streamingEyeOpenness)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // start sending
                result = tobii_research_subscribe_to_eye_openness(_localEyeTracker.et, LSLEyeOpennessCallback, this);
                stateVar = &_streamingEyeOpenness;
            }
            break;
        }
        case Titta::Stream::EyeImage:
        {
            if (_streamingEyeImages)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto asGif = asGif_.value_or(defaults::eyeImageAsGIF);

                // if already recording and switching from gif to normal or other way, first stop old stream
                if (_streamingEyeImages)
                    if (asGif != _eyeImIsGif)
                        doUnsubscribeEyeImage(_localEyeTracker.et, _eyeImIsGif);
                    else
                        // nothing to do
                        return true;

                // subscribe to new stream
                result = doSubscribeEyeImage(_localEyeTracker.et, this, asGif);
                stateVar = &_streamingEyeImages;
                if (result==TOBII_RESEARCH_STATUS_OK)
                    // update type being recorded if subscription to stream was successful
                    _eyeImIsGif = asGif;
            }
            break;
        }
        case Titta::Stream::ExtSignal:
        {
            if (_streamingExtSignal)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // start sending
                result = tobii_research_subscribe_to_external_signal_data(_localEyeTracker.et, LSLExtSignalCallback, this);
                stateVar = &_streamingExtSignal;
            }
            break;
        }
        case Titta::Stream::TimeSync:
        {
            if (_streamingTimeSync)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // start sending
                result = tobii_research_subscribe_to_time_synchronization_data(_localEyeTracker.et, LSLTimeSyncCallback, this);
                stateVar = &_streamingTimeSync;
            }
            break;
        }
        case Titta::Stream::Positioning:
        {
            if (_streamingPositioning)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // start sending
                result = tobii_research_subscribe_to_user_position_guide(_localEyeTracker.et, LSLPositioningCallback, this);
                stateVar = &_streamingPositioning;
            }
            break;
        }
        default:
        {
            DoExitWithMsg("LSL_streamer::cpp::start: Cannot start sending " + Titta::streamToString(stream_) + " stream, not supported to send via outlet");
            break;
        }
    }

    if (stateVar)
        *stateVar = result==TOBII_RESEARCH_STATUS_OK;

    if (result != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("LSL_streamer::cpp::start: Cannot start recording " + Titta::streamToString(stream_) + " stream", result);
    else
    {
        // if requested to merge gaze and eye openness, a call to start eye openness also starts gaze
        if (     stream_== Titta::Stream::EyeOpenness && _includeEyeOpennessInGaze && !_streamingGaze)
            return start(Titta::Stream::Gaze       , asGif_);
        // if requested to merge gaze and eye openness, a call to start gaze also starts eye openness
        else if (stream_== Titta::Stream::Gaze        && _includeEyeOpennessInGaze && !_streamingEyeOpenness)
            return start(Titta::Stream::EyeOpenness, asGif_);
        return true;
    }

    // will never get here, but to make compiler happy
    return true;
}

// tobii to own type helpers
namespace {
    void convert(TobiiTypes::gazePoint& out_, TobiiResearchGazePoint in_)
    {
        out_.position_in_user_coordinates   = in_.position_in_user_coordinates;
        out_.position_on_display_area       = in_.position_on_display_area;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::pupilData& out_, TobiiResearchPupilData in_)
    {
        out_.diameter                       = in_.diameter;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::gazeOrigin& out_, TobiiResearchGazeOrigin in_)
    {
        out_.position_in_track_box_coordinates = in_.position_in_track_box_coordinates;
        out_.position_in_user_coordinates   = in_.position_in_user_coordinates;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::eyeOpenness& out_, TobiiResearchEyeOpennessData* in_, bool leftEye_)
    {
        if (leftEye_)
        {
            out_.diameter = in_->left_eye_openness_value;
            out_.validity = in_->left_eye_validity;
        }
        else
        {
            out_.diameter = in_->right_eye_openness_value;
            out_.validity = in_->right_eye_validity;
        }
        out_.available = true;
    }
    void convert(TobiiTypes::eyeData& out_, TobiiResearchEyeData in_)
    {
        convert(out_.gaze_point, in_.gaze_point);
        convert(out_.pupil, in_.pupil_data);
        convert(out_.gaze_origin, in_.gaze_origin);
    }
}

void LSL_streamer::receiveSample(TobiiResearchGazeData* gaze_data_, TobiiResearchEyeOpennessData* openness_data_)
{
    auto needStage = _streamingGaze && _streamingEyeOpenness;
    if (!needStage && !_gazeStagingEmpty)
    {
        // if any data in staging area but no longer expecting to merge, flush to output
        if (isStreaming(Titta::Stream::Gaze))
        {
            for (auto& samp : _gazeStaging)
                pushSample(samp);
        }
        _gazeStaging.clear();
        _gazeStagingEmpty = true;
    }

    std::unique_lock l(_gazeStageMutex, std::defer_lock);
    if (needStage)
        l.lock();

    Titta::gaze* sample = nullptr;
    std::deque<Titta::gaze> emitBuffer;
    if (needStage)
    {
        // find if there is already a corresponding sample in the staging area
        for (auto it = _gazeStaging.begin(); it != _gazeStaging.end(); )
        {
            if ((!!gaze_data_     && it->device_time_stamp <     gaze_data_->device_time_stamp && it->left_eye.eye_openness.available) ||
                (!!openness_data_ && it->device_time_stamp < openness_data_->device_time_stamp && it->left_eye.gaze_origin.available))
            {
                // We assume samples come in order. Here we have:
                // 1. a sample older than this     gaze     sample for which eye openness is already available, or
                // 2. a sample older than this eye openness sample for which     gaze     is already available;
                // emit it, continue searching
                emitBuffer.push_back(std::move(*it));
                it = _gazeStaging.erase(it);
            }
            else if ((!!gaze_data_     && it->device_time_stamp ==     gaze_data_->device_time_stamp) ||
                     (!!openness_data_ && it->device_time_stamp == openness_data_->device_time_stamp))
            {
                // found, this is the one we want. Move to output, take pointer to it as we'll be adding to it
                emitBuffer.push_back(std::move(*it));
                it = _gazeStaging.erase(it);
                sample = &emitBuffer.back();
                break;
            }
            else
                it++;
        }
    }
    if (!sample)
    {
        if (needStage)
        {
            _gazeStaging.push_back({});
            sample = &_gazeStaging.back();
        }
        else
        {
            emitBuffer.push_back({});
            sample = &emitBuffer.back();
        }

        if (gaze_data_)
        {
            sample->device_time_stamp = gaze_data_->device_time_stamp;
            sample->system_time_stamp = gaze_data_->system_time_stamp;
        }
        else if (openness_data_)
        {
            sample->device_time_stamp = openness_data_->device_time_stamp;
            sample->system_time_stamp = openness_data_->system_time_stamp;
        }
    }

    if (gaze_data_)
    {
        // convert to own gaze data type
        convert(sample->left_eye,  gaze_data_->left_eye);
        convert(sample->right_eye, gaze_data_->right_eye);
    }
    else if (openness_data_)
    {
        // convert to own gaze data type
        convert(sample->left_eye.eye_openness , openness_data_, true);
        convert(sample->right_eye.eye_openness, openness_data_, false);
    }
    if (needStage)
        l.unlock();

    // output if anything
    if (!emitBuffer.empty())
    {
        if (isStreaming(Titta::Stream::Gaze))
            for (auto& samp : emitBuffer)
                pushSample(samp);
    }
}

void LSL_streamer::pushSample(Titta::gaze sample_)
{
    const float sample[] = {
        sample_.left_eye.gaze_point.position_on_display_area.x, sample_.left_eye.gaze_point.position_on_display_area.y,
        sample_.left_eye.gaze_point.position_in_user_coordinates.x, sample_.left_eye.gaze_point.position_in_user_coordinates.y, sample_.left_eye.gaze_point.position_in_user_coordinates.z,
        static_cast<float>(sample_.left_eye.gaze_point.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.left_eye.gaze_point.available),
        sample_.left_eye.pupil.diameter,
        static_cast<float>(sample_.left_eye.pupil.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.left_eye.pupil.available),
        sample_.left_eye.gaze_origin.position_in_user_coordinates.x, sample_.left_eye.gaze_origin.position_in_user_coordinates.y, sample_.left_eye.gaze_origin.position_in_user_coordinates.z,
        sample_.left_eye.gaze_origin.position_in_track_box_coordinates.x, sample_.left_eye.gaze_origin.position_in_track_box_coordinates.y, sample_.left_eye.gaze_origin.position_in_track_box_coordinates.z,
        static_cast<float>(sample_.left_eye.gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.left_eye.gaze_origin.available),
        sample_.left_eye.eye_openness.diameter,
        static_cast<float>(sample_.left_eye.eye_openness.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.left_eye.eye_openness.available),

        sample_.right_eye.gaze_point.position_on_display_area.x, sample_.right_eye.gaze_point.position_on_display_area.y,
        sample_.right_eye.gaze_point.position_in_user_coordinates.x, sample_.right_eye.gaze_point.position_in_user_coordinates.y, sample_.right_eye.gaze_point.position_in_user_coordinates.z,
        static_cast<float>(sample_.right_eye.gaze_point.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.right_eye.gaze_point.available),
        sample_.right_eye.pupil.diameter,
        static_cast<float>(sample_.right_eye.pupil.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.right_eye.pupil.available),
        sample_.right_eye.gaze_origin.position_in_user_coordinates.x, sample_.right_eye.gaze_origin.position_in_user_coordinates.y, sample_.right_eye.gaze_origin.position_in_user_coordinates.z,
        sample_.right_eye.gaze_origin.position_in_track_box_coordinates.x, sample_.right_eye.gaze_origin.position_in_track_box_coordinates.y, sample_.right_eye.gaze_origin.position_in_track_box_coordinates.z,
        static_cast<float>(sample_.right_eye.gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.right_eye.gaze_origin.available),
        sample_.right_eye.eye_openness.diameter,
        static_cast<float>(sample_.right_eye.eye_openness.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<float>(sample_.right_eye.eye_openness.available),
    };
    _outStreams.at(Titta::Stream::Gaze).push_sample(sample, sample_.system_time_stamp/1'000'000.);
}
void LSL_streamer::pushSample(Titta::eyeImage&& sample_)
{

}
void LSL_streamer::pushSample(Titta::extSignal sample_)
{
    const int64_t sample[] = {
        sample_.device_time_stamp, sample_.value
    };
    _outStreams.at(Titta::Stream::ExtSignal).push_sample(sample, sample_.system_time_stamp / 1'000'000.);
}
void LSL_streamer::pushSample(Titta::timeSync sample_)
{
    const int64_t sample[] = {
        sample_.system_request_time_stamp, sample_.device_time_stamp, sample_.system_response_time_stamp
    };
    _outStreams.at(Titta::Stream::TimeSync).push_sample(sample, sample_.system_request_time_stamp / 1'000'000.);
}
void LSL_streamer::pushSample(Titta::positioning sample_)
{
    const float sample[] = {
        sample_.left_eye.user_position.x, sample_.left_eye.user_position.y, sample_.left_eye.user_position.z,
        static_cast<float>(sample_.left_eye.validity == TOBII_RESEARCH_VALIDITY_VALID),
        sample_.right_eye.user_position.x, sample_.right_eye.user_position.y, sample_.right_eye.user_position.z,
        static_cast<float>(sample_.right_eye.validity == TOBII_RESEARCH_VALIDITY_VALID)
    };
    _outStreams.at(Titta::Stream::Positioning).push_sample(sample);
}

bool LSL_streamer::stop(Titta::Stream stream_)
{
    TobiiResearchStatus result = TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
    case Titta::Stream::Gaze:
        result = !_streamingGaze ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_gaze_data(_localEyeTracker.et, LSLGazeCallback);
        stateVar = &_streamingGaze;
        break;
    case Titta::Stream::EyeOpenness:
        result = !_streamingEyeOpenness ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_eye_openness(_localEyeTracker.et, LSLEyeOpennessCallback);
        stateVar = &_streamingEyeOpenness;
        break;
    case Titta::Stream::EyeImage:
        result = !_streamingEyeImages ? TOBII_RESEARCH_STATUS_OK : doUnsubscribeEyeImage(_localEyeTracker.et, _eyeImIsGif);
        stateVar = &_streamingEyeImages;
        break;
    case Titta::Stream::ExtSignal:
        result = !_streamingExtSignal ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_external_signal_data(_localEyeTracker.et, LSLExtSignalCallback);
        stateVar = &_streamingExtSignal;
        break;
    case Titta::Stream::TimeSync:
        result = !_streamingTimeSync ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_time_synchronization_data(_localEyeTracker.et, LSLTimeSyncCallback);
        stateVar = &_streamingTimeSync;
        break;
    case Titta::Stream::Positioning:
        result = !_streamingPositioning ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_user_position_guide(_localEyeTracker.et, LSLPositioningCallback);
        stateVar = &_streamingPositioning;
        break;
    }

    bool success = result==TOBII_RESEARCH_STATUS_OK;
    if (stateVar && success)
        *stateVar = false;

    // if requested to merge gaze and eye openness, a call to stop eye openness also stops gaze
    if (stream_ == Titta::Stream::EyeOpenness && _includeEyeOpennessInGaze && _streamingGaze)
        return stop(Titta::Stream::Gaze) && success;
    // if requested to merge gaze and eye openness, a call to stop gaze also stops eye openness
    else if (stream_ == Titta::Stream::Gaze && _includeEyeOpennessInGaze && _streamingEyeOpenness)
        return stop(Titta::Stream::EyeOpenness) && success;
    return success;
}

bool LSL_streamer::isStreaming(std::string stream_, bool snake_case_on_stream_not_found /*= false*/) const
{
    return isStreaming(Titta::stringToStream(stream_, snake_case_on_stream_not_found));
}
bool LSL_streamer::isStreaming(Titta::Stream stream_) const
{
    bool isStreaming = false;
    switch (stream_)
    {
        case Titta::Stream::Gaze:
            isStreaming = _streamingGaze;
            break;
        case Titta::Stream::EyeOpenness:
            isStreaming = _streamingEyeOpenness;
            break;
        case Titta::Stream::EyeImage:
            isStreaming = _streamingEyeImages;
            break;
        case Titta::Stream::ExtSignal:
            isStreaming = _streamingExtSignal;
            break;
        case Titta::Stream::TimeSync:
            isStreaming = _streamingTimeSync;
            break;
        case Titta::Stream::Positioning:
            isStreaming = _streamingPositioning;
            break;
    }

    // EyeOpenness is always packed in a gaze stream, so check for that instead
    return isStreaming && ((stream_ == Titta::Stream::EyeOpenness && _outStreams.contains(Titta::Stream::Gaze)) || _outStreams.contains(stream_));
}

void LSL_streamer::stopOutlet(std::string stream_, bool snake_case_on_stream_not_found /*= false*/)
{
    stopOutlet(Titta::stringToStream(stream_, snake_case_on_stream_not_found));
}

void LSL_streamer::stopOutlet(Titta::Stream stream_)
{
    // stop the callback
    stop(stream_);

    // stop the outlet, if any
    if (_outStreams.contains(stream_))
        _outStreams.erase(stream_);
}


namespace
{
template <typename T>
std::vector<T> consumeFromVec(std::vector<T>& buf_, typename std::vector<T>::iterator startIt_, typename std::vector<T>::iterator endIt_)
{
    if (std::empty(buf_))
        return std::vector<T>{};

    // move out the indicated elements
    bool whole = startIt_ == std::begin(buf_) && endIt_ == std::end(buf_);
    if (whole)
        return std::vector<T>(std::move(buf_));
    else
    {
        std::vector<T> out;
        out.reserve(std::distance(startIt_, endIt_));
        out.insert(std::end(out), std::make_move_iterator(startIt_), std::make_move_iterator(endIt_));
        buf_.erase(startIt_, endIt_);
        return out;
    }
}

template <typename T>
std::vector<T> peekFromVec(const std::vector<T>& buf_, const typename std::vector<T>::const_iterator startIt_, const typename std::vector<T>::const_iterator endIt_)
{
    if (std::empty(buf_))
        return std::vector<T>{};

    // copy the indicated elements
    return std::vector<T>(startIt_, endIt_);
}

template <typename DataType>
void clearVec(LSL_streamer::Inlet<DataType>& inlet_, int64_t timeStart_, int64_t timeEnd_, bool timeIsLocalTime_)
{
    auto l = lockForWriting(inlet_);  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer(inlet_);
    if (std::empty(buf))
        return;

    // find applicable range
    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<DataType>(timeStart_, timeEnd_, timeIsLocalTime_);
    // clear the flagged bit
    if (whole)
        buf.clear();
    else
        buf.erase(startIt, endIt);
}
}


template <typename DataType>
LSL_streamer::Inlet<DataType>& LSL_streamer::getInlet(uint32_t id_)
{
    if (!_inStreams.contains(id_))
        DoExitWithMsg(std::format("No inlet with id {} is known", id_));

    return std::get<Inlet<DataType>>(_inStreams.at(id_));
}

template <typename DataType>
std::vector<DataType> LSL_streamer::consumeN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_)
{
    // deal with default arguments
    auto N      = NSamp_.value_or(defaults::consumeNSamp);
    auto side   = side_.value_or(defaults::consumeSide);

    auto& inlet = getInlet<DataType>(id_);
    auto l      = lockForWriting(inlet);  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer(inlet);

    auto [startIt, endIt] = getIteratorsFromSampleAndSide(buf, N, side);
    return consumeFromVec(buf, startIt, endIt);
}
template <typename DataType>
std::vector<DataType> LSL_streamer::consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_)
{
    // deal with default arguments
    auto timeStart      = timeStart_      .value_or(defaults::consumeTimeRangeStart);
    auto timeEnd        = timeEnd_        .value_or(defaults::consumeTimeRangeEnd);
    auto timeIsLocalTime= timeIsLocalTime_.value_or(defaults::timeIsLocalTime);

    auto& inlet = getInlet<DataType>(id_);
    auto l      = lockForWriting(inlet);  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer(inlet);

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange(buf, timeStart, timeEnd, timeIsLocalTime);
    return consumeFromVec(buf, startIt, endIt);
}

template <typename DataType>
std::vector<DataType> LSL_streamer::peekN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_)
{
    // deal with default arguments
    auto N      = NSamp_.value_or(defaults::peekNSamp);
    auto side   = side_.value_or(defaults::peekSide);

    auto& inlet = getInlet<DataType>(id_);
    auto l      = lockForReading(inlet);
    auto& buf   = getBuffer(inlet);

    auto [startIt, endIt] = getIteratorsFromSampleAndSide(buf, N, side);
    return peekFromVec(buf, startIt, endIt);
}
template <typename DataType>
std::vector<DataType> LSL_streamer::peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_)
{
    // deal with default arguments
    auto timeStart       = timeStart_      .value_or(defaults::peekTimeRangeStart);
    auto timeEnd         = timeEnd_        .value_or(defaults::peekTimeRangeEnd);
    auto timeIsLocalTime = timeIsLocalTime_.value_or(defaults::timeIsLocalTime);

    auto& inlet     = getInlet<DataType>(id_);
    auto l          = lockForReading(inlet);
    auto& buf       = getBuffer(inlet);

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange(buf, timeStart, timeEnd, timeIsLocalTime);
    return peekFromVec(buf, startIt, endIt);
}

void LSL_streamer::clear(uint32_t id_)
{
    // visit with generic lambda so we get the inlet, lock and cal clear() on its buffer
    /*if (stream_ == Stream::Positioning)
    {
        auto l      = lockForWriting<positioning>();    // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
        auto& buf   = getBuffer<positioning>();
        if (std::empty(buf))
            return;
        buf.clear();
    }
    else
        clearTimeRange(stream_);*/
}
void LSL_streamer::clearTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_)
{
    // deal with default arguments
    auto timeStart       = timeStart_      .value_or(defaults::clearTimeRangeStart);
    auto timeEnd         = timeEnd_        .value_or(defaults::clearTimeRangeEnd);
    auto timeIsLocalTime = timeIsLocalTime_.value_or(defaults::timeIsLocalTime);

    // visit with templated lambda that allows us to get the data type, then
    // check if type is positioning, error, else forward. May need to split in two
    // overloaded lambdas actually, first for positioning, then templated generic
    /*switch (stream_)
    {
        case Stream::Gaze:
        case Stream::EyeOpenness:
            clearVec<gaze>(timeStart, timeEnd);
            break;
        case Stream::EyeImage:
            clearVec<eyeImage>(timeStart, timeEnd);
            break;
        case Stream::ExtSignal:
            clearVec<extSignal>(timeStart, timeEnd);
            break;
        case Stream::TimeSync:
            clearVec<timeSync>(timeStart, timeEnd);
            break;
        case Stream::Positioning:
            DoExitWithMsg("Titta::cpp::clearTimeRange: not supported for the positioning stream.");
            break;
    }*/
}

// gaze data (including eye openness), instantiate templated functions
template std::vector<LSLTypes::gaze> LSL_streamer::consumeN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::gaze> LSL_streamer::consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<LSLTypes::gaze> LSL_streamer::peekN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::gaze> LSL_streamer::peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// eye images, instantiate templated functions
template std::vector<LSLTypes::eyeImage> LSL_streamer::consumeN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::eyeImage> LSL_streamer::consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<LSLTypes::eyeImage> LSL_streamer::peekN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::eyeImage> LSL_streamer::peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// external signals, instantiate templated functions
template std::vector<LSLTypes::extSignal> LSL_streamer::consumeN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::extSignal> LSL_streamer::consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<LSLTypes::extSignal> LSL_streamer::peekN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::extSignal> LSL_streamer::peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// time sync data, instantiate templated functions
template std::vector<LSLTypes::timeSync> LSL_streamer::consumeN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::timeSync> LSL_streamer::consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<LSLTypes::timeSync> LSL_streamer::peekN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<LSLTypes::timeSync> LSL_streamer::peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// positioning data, instantiate templated functions
// NB: positioning data does not have timestamps, so the Time Range version of the below functions are not defined for the positioning stream
template std::vector<Titta::positioning> LSL_streamer::consumeN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
//template std::vector<Titta::positioning> LSL_streamer::consumeTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::positioning> LSL_streamer::peekN(uint32_t id_, std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
//template std::vector<Titta::positioning> LSL_streamer::peekTimeRange(uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
