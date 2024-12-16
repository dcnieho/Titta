#include "TittaLSL/TittaLSL.h"
#include <vector>
#include <algorithm>
#include <string_view>
#include <numeric>
#include <map>
#include <ranges>

#include "Titta/utils.h"

namespace
{
    // default argument values
    namespace defaults
    {
        constexpr bool                  createStartsSending     = true;
        constexpr bool                  createStartsRecording   = false;

        constexpr size_t                gazeBufSize             = 2<<19;        // about half an hour at 600Hz

        constexpr size_t                extSignalBufSize        = 2<<9;

        constexpr size_t                timeSyncBufSize         = 2<<9;

        constexpr size_t                positioningBufSize      = 2<<11;

        constexpr int64_t               clearTimeRangeStart     = 0;
        constexpr int64_t               clearTimeRangeEnd       = std::numeric_limits<int64_t>::max();

        constexpr bool                  stopBufferEmpties       = false;
        constexpr Titta::BufferSide     consumeSide             = Titta::BufferSide::Start;
        constexpr size_t                consumeNSamp            = -1;           // this overflows on purpose, consume all samples is default
        constexpr int64_t               consumeTimeRangeStart   = 0;
        constexpr int64_t               consumeTimeRangeEnd     = std::numeric_limits<int64_t>::max();
        constexpr Titta::BufferSide     peekSide                = Titta::BufferSide::End;
        constexpr size_t                peekNSamp               = 1;
        constexpr int64_t               peekTimeRangeStart      = 0;
        constexpr int64_t               peekTimeRangeEnd        = std::numeric_limits<int64_t>::max();
        constexpr bool                  timeIsLocalTime         = true;
    }

    template <class...> constexpr std::false_type always_false_t{};
    template <auto...> constexpr std::false_type always_false_nt{};

    template <Titta::Stream T> struct TittaStreamToLSLInletType { static_assert(always_false_nt<T>, "TittaStreamToLSLInletType not implemented for this enum value: this stream type is not supported as an TittaLSL inlet"); };
    template <>                struct TittaStreamToLSLInletType<Titta::Stream::Gaze> { using type = TittaLSL::Receiver::gaze; };
    template <>                struct TittaStreamToLSLInletType<Titta::Stream::EyeOpenness> { using type = TittaLSL::Receiver::gaze; };
    template <>                struct TittaStreamToLSLInletType<Titta::Stream::ExtSignal> { using type = TittaLSL::Receiver::extSignal; };
    template <>                struct TittaStreamToLSLInletType<Titta::Stream::TimeSync> { using type = TittaLSL::Receiver::timeSync; };
    template <>                struct TittaStreamToLSLInletType<Titta::Stream::Positioning> { using type = TittaLSL::Receiver::positioning; };
    template <Titta::Stream T>
    using TittaStreamToLSLInletType_t = typename TittaStreamToLSLInletType<T>::type;

    template <typename T> struct LSLInletTypeToTittaStream { static_assert(always_false_t<T>, "LSLInletTypeToTittaStream not implemented for this type"); static constexpr Titta::Stream value = Titta::Stream::Unknown; };
    template <>           struct LSLInletTypeToTittaStream<TittaLSL::Receiver::gaze> { static constexpr Titta::Stream value = Titta::Stream::Gaze; };
    template <>           struct LSLInletTypeToTittaStream<TittaLSL::Receiver::extSignal> { static constexpr Titta::Stream value = Titta::Stream::ExtSignal; };
    template <>           struct LSLInletTypeToTittaStream<TittaLSL::Receiver::timeSync> { static constexpr Titta::Stream value = Titta::Stream::TimeSync; };
    template <>           struct LSLInletTypeToTittaStream<TittaLSL::Receiver::positioning> { static constexpr Titta::Stream value = Titta::Stream::Positioning; };
    template <typename T>
    constexpr Titta::Stream LSLInletTypeToTittaStream_v = LSLInletTypeToTittaStream<T>::value;

    template <typename T> struct LSLInletTypeNumSamples { static_assert(always_false_t<T>, "LSLInletTypeNumSamples not implemented for this type"); static constexpr size_t value = 0; };
    template <>           struct LSLInletTypeNumSamples<TittaLSL::Receiver::gaze> { static constexpr size_t value = 43; };
    template <>           struct LSLInletTypeNumSamples<TittaLSL::Receiver::extSignal> { static constexpr size_t value = 4; };
    template <>           struct LSLInletTypeNumSamples<TittaLSL::Receiver::timeSync> { static constexpr size_t value = 3; };
    template <>           struct LSLInletTypeNumSamples<TittaLSL::Receiver::positioning> { static constexpr size_t value = 8; };
    template <typename T>
    constexpr size_t LSLInletTypeNumSamples_v = LSLInletTypeNumSamples<T>::value;

    template <typename T> struct LSLInletTypeToChannelFormat { static_assert(always_false_t<T>, "LSLInletTypeToChannelFormat not implemented for this type"); static constexpr enum lsl::channel_format_t value = lsl::cf_undefined; };
    template <>           struct LSLInletTypeToChannelFormat<TittaLSL::Receiver::gaze> { static constexpr enum lsl::channel_format_t value = lsl::cf_double64; };
    template <>           struct LSLInletTypeToChannelFormat<TittaLSL::Receiver::extSignal> { static constexpr enum lsl::channel_format_t value = lsl::cf_int64; };
    template <>           struct LSLInletTypeToChannelFormat<TittaLSL::Receiver::timeSync> { static constexpr enum lsl::channel_format_t value = lsl::cf_int64; };
    template <>           struct LSLInletTypeToChannelFormat<TittaLSL::Receiver::positioning> { static constexpr enum lsl::channel_format_t value = lsl::cf_float32; };
    template <typename T>
    constexpr enum lsl::channel_format_t LSLInletTypeToChannelFormat_v = LSLInletTypeToChannelFormat<T>::value;

    template <enum lsl::channel_format_t T> struct LSLChannelFormatToCppType { static_assert(always_false_nt<T>, "LSLChannelFormatToCppType not implemented for this enum value: this channel format is not supported by TittaLSL"); };
    template <>                struct LSLChannelFormatToCppType<lsl::cf_float32> { using type = float; };
    template <>                struct LSLChannelFormatToCppType<lsl::cf_double64> { using type = double; };
    template <>                struct LSLChannelFormatToCppType<lsl::cf_int64> { using type = int64_t; };
    template <enum lsl::channel_format_t T>
    using LSLChannelFormatToCppType_t = typename LSLChannelFormatToCppType<T>::type;
}

namespace TittaLSL
{
TobiiResearchSDKVersion getTobiiSDKVersion()
{
    TobiiResearchSDKVersion sdk_version;
    const TobiiResearchStatus status = tobii_research_get_sdk_version(&sdk_version);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get Tobii SDK version", status);
    return sdk_version;
}
int32_t getLSLVersion()
{
    return lsl::library_version();
}


// callbacks
void GazeCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        const auto instance = static_cast<TittaLSL::Sender*>(user_data);
        instance->receiveSample(gaze_data_, nullptr);
    }
}
void EyeOpennessCallback(TobiiResearchEyeOpennessData* openness_data_, void* user_data)
{
    if (user_data)
    {
        const auto instance = static_cast<TittaLSL::Sender*>(user_data);
        instance->receiveSample(nullptr, openness_data_);
    }
}
void ExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        const auto instance = static_cast<TittaLSL::Sender*>(user_data);
        if (instance->isStreaming(Titta::Stream::ExtSignal))
            instance->pushSample(*ext_signal_);
    }
}
void TimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        const auto instance = static_cast<TittaLSL::Sender*>(user_data);
        if (instance->isStreaming(Titta::Stream::TimeSync))
            instance->pushSample(*time_sync_data_);
    }
}
void PositioningCallback(TobiiResearchUserPositionGuide* position_data_, void* user_data)
{
    if (user_data)
    {
        const auto instance = static_cast<TittaLSL::Sender*>(user_data);
        if (instance->isStreaming(Titta::Stream::Positioning))
            instance->pushSample(*position_data_);
    }
}
}

namespace TittaLSL
{
Sender::Sender(std::string address_)
{
    connect(std::move(address_));
}
Sender::Sender(TobiiResearchEyeTracker* et_)
{
    connect(et_);
}
Sender::Sender(const TobiiTypes::eyeTracker& et_)
{
    connect(et_.et);
}
Sender::~Sender()
{
    destroy(Titta::Stream::Gaze);
    destroy(Titta::Stream::EyeOpenness);
    destroy(Titta::Stream::ExtSignal);
    destroy(Titta::Stream::TimeSync);
    destroy(Titta::Stream::Positioning);
}

void Sender::CheckClocks()
{
    // check tobii/titta clock and lsl clock are the same
    // 1. warm up clocks by calling them once
    Titta::getSystemTimestamp();
    lsl::local_clock();

    // acquire a bunch of samples, in both orders of calling
    constexpr size_t nSample = 20;
    std::array<double, nSample> tobiiTime;
    std::array<double, nSample> lslTime;

    for (size_t i = 0; i < nSample / 2; i++)
    {
        tobiiTime[i] = Titta::getSystemTimestamp() / 1'000'000.;
        lslTime[i] = lsl::local_clock();
    }
    for (size_t i = nSample / 2; i < nSample; i++)
    {
        lslTime[i] = lsl::local_clock();
        tobiiTime[i] = Titta::getSystemTimestamp() / 1'000'000.;
    }
    // get differences
    std::array<double, nSample> diff;
    std::transform(tobiiTime.begin(), tobiiTime.end(), lslTime.begin(), diff.begin(), std::minus<double>{});

    // get average value
    const auto average = std::reduce(diff.begin(), diff.end(), 0.) / nSample;

    // should be well within a millisecond (actually, if different clocks are used
    // it would be super wrong), so check
    if (std::abs(average) > 0.001)
        DoExitWithMsg(string_format("LSL and Tobii/Titta clocks are not the same (average offset over %zu samples was %.3f s), or you are having some serious clock trouble. Cannot continue", nSample, average));
}


void Sender::connect(std::string address_)
{
    TobiiResearchEyeTracker* et;
    const TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(), &et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp::Sender: Cannot get eye tracker \"" + address_ + "\"", status);
    connect(et);
}

void Sender::connect(TobiiResearchEyeTracker* et_)
{
    _localEyeTracker = et_;
    CheckClocks();
}


TobiiTypes::eyeTracker Sender::getEyeTracker()
{
    _localEyeTracker.refreshInfo();
    return _localEyeTracker;
}

std::string Sender::getStreamSourceID(std::string stream_, bool snake_case_on_stream_not_found /*= false*/) const
{
    return getStreamSourceID(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true));
}
std::string Sender::getStreamSourceID(Titta::Stream stream_) const
{
    const auto streamName = Titta::streamToString(stream_);
    const auto lslStreamName = string_format("Tobii_%s", streamName.c_str());
    return string_format("TittaLSL:%s@%s", lslStreamName.c_str(), _localEyeTracker.serialNumber.c_str());
}

bool Sender::create(std::string stream_, std::optional<bool> doStartSending_, const bool snake_case_on_stream_not_found /*= false*/)
{
    // deal with default arguments
    const auto doStartSending = doStartSending_.value_or(defaults::createStartsSending);

    return create(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true), doStartSending);
}
bool Sender::create(const Titta::Stream stream_, std::optional<bool> doStartSending_)
{
    // deal with default arguments
    const auto doStartSending = doStartSending_.value_or(defaults::createStartsSending);

    // if already streaming, don't start again
    if (isStreaming(stream_))
        return false;

    // for gaze signal, get info about the eye tracker's gaze stream
    const auto hasFreq = stream_ == Titta::Stream::Gaze || stream_ == Titta::Stream::EyeOpenness;
    if (hasFreq)
        _localEyeTracker.refreshInfo();

    std::string type;
    int nChannel = 0;
    enum lsl::channel_format_t format = lsl::cf_undefined;
    switch (stream_)
    {
    case Titta::Stream::Gaze:
    case Titta::Stream::EyeOpenness:
        type = "Gaze";
        nChannel = LSLInletTypeNumSamples_v<TittaStreamToLSLInletType_t<Titta::Stream::Gaze>>;
        format = LSLInletTypeToChannelFormat_v<TittaStreamToLSLInletType_t<Titta::Stream::Gaze>>;
        break;
    case Titta::Stream::ExtSignal:
        type = "TTL";
        nChannel = LSLInletTypeNumSamples_v<TittaStreamToLSLInletType_t<Titta::Stream::ExtSignal>>;
        format = LSLInletTypeToChannelFormat_v<TittaStreamToLSLInletType_t<Titta::Stream::ExtSignal>>;
        break;
    case Titta::Stream::TimeSync:
        type = "TimeSync";
        nChannel = LSLInletTypeNumSamples_v<TittaStreamToLSLInletType_t<Titta::Stream::TimeSync>>;
        format = LSLInletTypeToChannelFormat_v<TittaStreamToLSLInletType_t<Titta::Stream::TimeSync>>;
        break;
    case Titta::Stream::Positioning:
        type = "Positioning";
        nChannel = LSLInletTypeNumSamples_v<TittaStreamToLSLInletType_t<Titta::Stream::Positioning>>;
        format = LSLInletTypeToChannelFormat_v<TittaStreamToLSLInletType_t<Titta::Stream::Positioning>>;
        break;
    default:
        DoExitWithMsg(string_format("TittaLSL::cpp::Sender::create: opening an outlet for %s stream is not supported.", Titta::streamToString(stream_).c_str()));
        break;
    }

    // set up the outlet
    const auto streamName = Titta::streamToString(stream_);
    const auto lslStreamName = string_format("Tobii_%s", streamName.c_str());
    lsl::stream_info info(lslStreamName,
        type,
        nChannel,
        hasFreq ? _localEyeTracker.frequency : lsl::IRREGULAR_RATE,
        format,
        getStreamSourceID(stream_));

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
        break;
    case Titta::Stream::ExtSignal:
        channels.append_child("channel")
            .append_child_value("label", "device_time_stamp")
            .append_child_value("type", "TimeStamp")
            .append_child_value("unit", "us");
        channels.append_child("channel")
            .append_child_value("label", "system_time_stamp")
            .append_child_value("type", "TimeStamp")
            .append_child_value("unit", "us");
        channels.append_child("channel")
            .append_child_value("label", "value")
            .append_child_value("type", "TTLIn");
        channels.append_child("channel")
            .append_child_value("label", "change_type")
            .append_child_value("type", "flag");
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
    return attachCallback(stream_, doStartSending);
}

bool Sender::hasStream(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/) const
{
    return hasStream(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true));
}
bool Sender::hasStream(const Titta::Stream stream_) const
{
    switch (stream_)
    {
    case Titta::Stream::Gaze:
        return _gazeRegistered && _outStreams.contains(Titta::Stream::Gaze);
    case Titta::Stream::EyeOpenness:
        return _eyeOpennessRegistered && _outStreams.contains(Titta::Stream::Gaze); // NB: EyeOpenness is always packed into a gaze stream
    case Titta::Stream::ExtSignal:
        return _extSignalRegistered && _outStreams.contains(Titta::Stream::ExtSignal);
    case Titta::Stream::TimeSync:
        return _timeSyncRegistered && _outStreams.contains(Titta::Stream::TimeSync);
    case Titta::Stream::Positioning:
        return _positioningRegistered && _outStreams.contains(Titta::Stream::Positioning);
    }
}


void Sender::setIncludeEyeOpennessInGaze(const bool include_)
{
    if (include_ && !(_localEyeTracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA))
        DoExitWithMsg(
            "TittaLSL::cpp::Sender::setIncludeEyeOpennessInGaze: Cannot request to stream " + Titta::streamToString(Titta::Stream::EyeOpenness) + ", this eye tracker does not provide it"
        );

    _includeEyeOpennessInGaze = include_;

    // start/stop eye openness stream if needed
    if (hasStream(Titta::Stream::EyeOpenness) && !_includeEyeOpennessInGaze)
        removeCallback(Titta::Stream::EyeOpenness);
    else if (hasStream(Titta::Stream::Gaze) && _includeEyeOpennessInGaze)
        attachCallback(Titta::Stream::EyeOpenness, isStreaming(Titta::Stream::Gaze));
}



void Sender::start(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/)
{
    start(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true));
}

void Sender::start(const Titta::Stream stream_)
{
    // first check if we have a stream to start
    if (!hasStream(stream_))
        DoExitWithMsg(
            "TittaLSL::cpp::Sender::start: Cannot start a " + Titta::streamToString(stream_) + " stream, you need to create it first"
        );

    bool* stateVar = nullptr;
    switch (stream_)
    {
    case Titta::Stream::Gaze:
        stateVar = &_streamingGaze;
        break;
    case Titta::Stream::EyeOpenness:
        stateVar = &_streamingEyeOpenness;
        break;
    case Titta::Stream::ExtSignal:
        stateVar = &_streamingExtSignal;
        break;
    case Titta::Stream::TimeSync:
        stateVar = &_streamingTimeSync;
        break;
    case Titta::Stream::Positioning:
        stateVar = &_streamingPositioning;
        break;
    }

    *stateVar = true;
    // if requested to merge gaze and eye openness, a call to start eye openness also starts gaze
    if (stream_ == Titta::Stream::EyeOpenness && _includeEyeOpennessInGaze)
        start(Titta::Stream::Gaze);
    // if requested to merge gaze and eye openness, a call to start gaze also starts eye openness
    else if (stream_ == Titta::Stream::Gaze && _includeEyeOpennessInGaze)
        start(Titta::Stream::EyeOpenness);
}

bool Sender::attachCallback(const Titta::Stream stream_, bool doStartSending_)
{
    TobiiResearchStatus result = TOBII_RESEARCH_STATUS_UNINITIALIZED;
    bool* registeredVar = nullptr;
    bool* sendingVar = nullptr;
    switch (stream_)
    {
        case Titta::Stream::Gaze:
        {
            if (_streamingGaze)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // start sending
                result = tobii_research_subscribe_to_gaze_data(_localEyeTracker.et, GazeCallback, this);
                registeredVar = &_gazeRegistered;
                sendingVar = &_streamingGaze;
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
                result = tobii_research_subscribe_to_eye_openness(_localEyeTracker.et, EyeOpennessCallback, this);
                registeredVar = &_eyeOpennessRegistered;
                sendingVar = &_streamingEyeOpenness;
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
                result = tobii_research_subscribe_to_external_signal_data(_localEyeTracker.et, ExtSignalCallback, this);
                registeredVar = &_extSignalRegistered;
                sendingVar = &_streamingExtSignal;
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
                result = tobii_research_subscribe_to_time_synchronization_data(_localEyeTracker.et, TimeSyncCallback, this);
                registeredVar = &_timeSyncRegistered;
                sendingVar = &_streamingTimeSync;
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
                result = tobii_research_subscribe_to_user_position_guide(_localEyeTracker.et, PositioningCallback, this);
                registeredVar = &_positioningRegistered;
                sendingVar = &_streamingPositioning;
            }
            break;
        }
        default:
        {
            DoExitWithMsg("TittaLSL::cpp::Sender::create: Cannot create " + Titta::streamToString(stream_) + " stream, not supported to send via outlet");
            break;
        }
    }

    if (registeredVar)
        *registeredVar = result == TOBII_RESEARCH_STATUS_OK;
    if (sendingVar && doStartSending_)
        *sendingVar = result == TOBII_RESEARCH_STATUS_OK;

    if (result != TOBII_RESEARCH_STATUS_OK)
    {
        _outStreams.erase(stream_);
        ErrorExit("TittaLSL::cpp::Sender::create: Cannot create " + Titta::streamToString(stream_) + " stream", result);
    }
    else
    {
        // if requested to merge gaze and eye openness, a call to create eye openness also registers for gaze
        if (     stream_== Titta::Stream::EyeOpenness && _includeEyeOpennessInGaze && !_gazeRegistered)
            return attachCallback(Titta::Stream::Gaze, doStartSending_);
        // if requested to merge gaze and eye openness, a call to create gaze also registers for eye openness
        else if (stream_== Titta::Stream::Gaze        && _includeEyeOpennessInGaze && !_eyeOpennessRegistered)
            return attachCallback(Titta::Stream::EyeOpenness, doStartSending_);
        return true;
    }

    // will never get here, but to make compiler happy
    return true;
}

// tobii to own type helpers
namespace {
    void convert(TobiiTypes::gazePoint& out_, const TobiiResearchGazePoint& in_)
    {
        out_.position_in_user_coordinates   = in_.position_in_user_coordinates;
        out_.position_on_display_area       = in_.position_on_display_area;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::pupilData& out_, const TobiiResearchPupilData& in_)
    {
        out_.diameter                       = in_.diameter;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::gazeOrigin& out_, const TobiiResearchGazeOrigin& in_)
    {
        out_.position_in_track_box_coordinates = in_.position_in_track_box_coordinates;
        out_.position_in_user_coordinates   = in_.position_in_user_coordinates;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::eyeOpenness& out_, const TobiiResearchEyeOpennessData* in_, const bool leftEye_)
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
    void convert(TobiiTypes::eyeData& out_, const TobiiResearchEyeData& in_)
    {
        convert(out_.gaze_point, in_.gaze_point);
        convert(out_.pupil, in_.pupil_data);
        convert(out_.gaze_origin, in_.gaze_origin);
    }
}

void Sender::receiveSample(const TobiiResearchGazeData* gaze_data_, const TobiiResearchEyeOpennessData* openness_data_)
{
    const auto needStage = _gazeRegistered && _eyeOpennessRegistered;
    if (!needStage && !_gazeStagingEmpty)
    {
        // if any data in staging area but no longer expecting to merge, flush to output
        if (isStreaming(Titta::Stream::Gaze))
        {
            for (const auto& sample : _gazeStaging)
                pushSample(sample);
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
                emitBuffer.push_back(*it);
                it = _gazeStaging.erase(it);
            }
            else if ((!!gaze_data_     && it->device_time_stamp ==     gaze_data_->device_time_stamp) ||
                     (!!openness_data_ && it->device_time_stamp == openness_data_->device_time_stamp))
            {
                // found, this is the one we want. Move to output, take pointer to it as we'll be adding to it
                emitBuffer.push_back(*it);
                it = _gazeStaging.erase(it);
                sample = &emitBuffer.back();
                break;
            }
            else
                ++it;
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
            for (const auto& samp : emitBuffer)
                pushSample(samp);
    }
}

void Sender::pushSample(const Titta::gaze& sample_)
{
    using lsl_inlet_type = TittaStreamToLSLInletType_t<Titta::Stream::Gaze>;
    using data_t = LSLChannelFormatToCppType_t<LSLInletTypeToChannelFormat_v<lsl_inlet_type>>;

    const data_t sample[LSLInletTypeNumSamples_v<lsl_inlet_type>] = {
        sample_.left_eye.gaze_point.position_on_display_area.x, sample_.left_eye.gaze_point.position_on_display_area.y,
        sample_.left_eye.gaze_point.position_in_user_coordinates.x, sample_.left_eye.gaze_point.position_in_user_coordinates.y, sample_.left_eye.gaze_point.position_in_user_coordinates.z,
        static_cast<data_t>(sample_.left_eye.gaze_point.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.left_eye.gaze_point.available),
        sample_.left_eye.pupil.diameter,
        static_cast<data_t>(sample_.left_eye.pupil.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.left_eye.pupil.available),
        sample_.left_eye.gaze_origin.position_in_user_coordinates.x, sample_.left_eye.gaze_origin.position_in_user_coordinates.y, sample_.left_eye.gaze_origin.position_in_user_coordinates.z,
        sample_.left_eye.gaze_origin.position_in_track_box_coordinates.x, sample_.left_eye.gaze_origin.position_in_track_box_coordinates.y, sample_.left_eye.gaze_origin.position_in_track_box_coordinates.z,
        static_cast<data_t>(sample_.left_eye.gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.left_eye.gaze_origin.available),
        sample_.left_eye.eye_openness.diameter,
        static_cast<data_t>(sample_.left_eye.eye_openness.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.left_eye.eye_openness.available),

        sample_.right_eye.gaze_point.position_on_display_area.x, sample_.right_eye.gaze_point.position_on_display_area.y,
        sample_.right_eye.gaze_point.position_in_user_coordinates.x, sample_.right_eye.gaze_point.position_in_user_coordinates.y, sample_.right_eye.gaze_point.position_in_user_coordinates.z,
        static_cast<data_t>(sample_.right_eye.gaze_point.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.right_eye.gaze_point.available),
        sample_.right_eye.pupil.diameter,
        static_cast<data_t>(sample_.right_eye.pupil.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.right_eye.pupil.available),
        sample_.right_eye.gaze_origin.position_in_user_coordinates.x, sample_.right_eye.gaze_origin.position_in_user_coordinates.y, sample_.right_eye.gaze_origin.position_in_user_coordinates.z,
        sample_.right_eye.gaze_origin.position_in_track_box_coordinates.x, sample_.right_eye.gaze_origin.position_in_track_box_coordinates.y, sample_.right_eye.gaze_origin.position_in_track_box_coordinates.z,
        static_cast<data_t>(sample_.right_eye.gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.right_eye.gaze_origin.available),
        sample_.right_eye.eye_openness.diameter,
        static_cast<data_t>(sample_.right_eye.eye_openness.validity == TOBII_RESEARCH_VALIDITY_VALID),static_cast<data_t>(sample_.right_eye.eye_openness.available),

        static_cast<data_t>(sample_.device_time_stamp) / 1'000'000.
    };
    _outStreams.at(Titta::Stream::Gaze).push_sample(sample, static_cast<double>(sample_.system_time_stamp)/1'000'000.);
}
void Sender::pushSample(const Titta::extSignal& sample_)
{
    using lsl_inlet_type = TittaStreamToLSLInletType_t<Titta::Stream::ExtSignal>;
    using data_t = LSLChannelFormatToCppType_t<LSLInletTypeToChannelFormat_v<lsl_inlet_type>>;

    const data_t sample[LSLInletTypeNumSamples_v<lsl_inlet_type>] = {
        sample_.device_time_stamp, sample_.system_time_stamp, sample_.value, sample_.change_type
    };
    _outStreams.at(Titta::Stream::ExtSignal).push_sample(sample, static_cast<double>(sample_.system_time_stamp) / 1'000'000.);
}
void Sender::pushSample(const Titta::timeSync& sample_)
{
    using lsl_inlet_type = TittaStreamToLSLInletType_t<Titta::Stream::TimeSync>;
    using data_t = LSLChannelFormatToCppType_t<LSLInletTypeToChannelFormat_v<lsl_inlet_type>>;

    const data_t sample[LSLInletTypeNumSamples_v<lsl_inlet_type>] = {
        sample_.system_request_time_stamp, sample_.device_time_stamp, sample_.system_response_time_stamp
    };
    _outStreams.at(Titta::Stream::TimeSync).push_sample(sample, static_cast<double>(sample_.system_request_time_stamp) / 1'000'000.);
}
void Sender::pushSample(const Titta::positioning& sample_)
{
    using lsl_inlet_type = TittaStreamToLSLInletType_t<Titta::Stream::Positioning>;
    using data_t = LSLChannelFormatToCppType_t<LSLInletTypeToChannelFormat_v<lsl_inlet_type>>;

    const data_t sample[LSLInletTypeNumSamples_v<lsl_inlet_type>] = {
        sample_.left_eye.user_position.x, sample_.left_eye.user_position.y, sample_.left_eye.user_position.z,
        static_cast<float>(sample_.left_eye.validity == TOBII_RESEARCH_VALIDITY_VALID),
        sample_.right_eye.user_position.x, sample_.right_eye.user_position.y, sample_.right_eye.user_position.z,
        static_cast<float>(sample_.right_eye.validity == TOBII_RESEARCH_VALIDITY_VALID)
    };
    _outStreams.at(Titta::Stream::Positioning).push_sample(sample); // this stream doesn't have a timestamp
}

bool Sender::removeCallback(const Titta::Stream stream_)
{
    TobiiResearchStatus result = TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
    case Titta::Stream::Gaze:
        result = !_gazeRegistered ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_gaze_data(_localEyeTracker.et, GazeCallback);
        stateVar = &_gazeRegistered;
        break;
    case Titta::Stream::EyeOpenness:
        result = !_eyeOpennessRegistered ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_eye_openness(_localEyeTracker.et, EyeOpennessCallback);
        stateVar = &_eyeOpennessRegistered;
        break;
    case Titta::Stream::ExtSignal:
        result = !_extSignalRegistered ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_external_signal_data(_localEyeTracker.et, ExtSignalCallback);
        stateVar = &_extSignalRegistered;
        break;
    case Titta::Stream::TimeSync:
        result = !_timeSyncRegistered ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_time_synchronization_data(_localEyeTracker.et, TimeSyncCallback);
        stateVar = &_timeSyncRegistered;
        break;
    case Titta::Stream::Positioning:
        result = !_positioningRegistered ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_user_position_guide(_localEyeTracker.et, PositioningCallback);
        stateVar = &_positioningRegistered;
        break;
    }

    const bool success = result==TOBII_RESEARCH_STATUS_OK;
    if (stateVar && success)
    {
        *stateVar = false;
        // ensure also not marked as streaming
        stop(stream_);
    }

    // if requested to merge gaze and eye openness, a call to stop eye openness also stops gaze
    if (stream_==Titta::Stream::EyeOpenness && _includeEyeOpennessInGaze)
        return removeCallback(Titta::Stream::Gaze) && success;
    // if requested to merge gaze and eye openness, a call to stop gaze also stops eye openness
    else if (stream_==Titta::Stream::Gaze && _includeEyeOpennessInGaze)
        return removeCallback(Titta::Stream::EyeOpenness) && success;
    return success;
}

bool Sender::isStreaming(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/) const
{
    return isStreaming(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true));
}
bool Sender::isStreaming(const Titta::Stream stream_) const
{
    if (!hasStream(stream_))
        return false;

    bool isStreaming = false;
    switch (stream_)
    {
        case Titta::Stream::Gaze:
            return _streamingGaze;
        case Titta::Stream::EyeOpenness:
            return _streamingEyeOpenness;
        case Titta::Stream::ExtSignal:
            return _streamingExtSignal;
        case Titta::Stream::TimeSync:
            return _streamingTimeSync;
        case Titta::Stream::Positioning:
            return _streamingPositioning;
    }

    return false;
}

void Sender::stop(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/)
{
    stop(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true));
}

void Sender::stop(const Titta::Stream stream_)
{
    // NB: may be no op if stream for this data type is stopped or was never even created,
    // but that's harmless, so no need to check

    bool* stateVar = nullptr;
    switch (stream_)
    {
    case Titta::Stream::Gaze:
        stateVar = &_streamingGaze;
        break;
    case Titta::Stream::EyeOpenness:
        stateVar = &_streamingEyeOpenness;
        break;
    case Titta::Stream::ExtSignal:
        stateVar = &_streamingExtSignal;
        break;
    case Titta::Stream::TimeSync:
        stateVar = &_streamingTimeSync;
        break;
    case Titta::Stream::Positioning:
        stateVar = &_streamingPositioning;
        break;
    }

    if (stateVar)
        *stateVar = false;

    // if requested to merge gaze and eye openness, a call to stop eye openness also stops gaze
    if (stream_==Titta::Stream::EyeOpenness && _includeEyeOpennessInGaze)
        _streamingGaze = false;
    // if requested to merge gaze and eye openness, a call to stop gaze also stops eye openness
    else if (stream_==Titta::Stream::Gaze && _includeEyeOpennessInGaze)
        _streamingEyeOpenness = false;
}

void Sender::destroy(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/)
{
    destroy(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true));
}

void Sender::destroy(const Titta::Stream stream_)
{
    // stop the stream, remove the callback
    stop(stream_);
    removeCallback(stream_);

    // stop the outlet, if any
    _outStreams.erase(stream_);
}
}

/* inlet stuff starts here */
namespace
{
inline int64_t timeStampSecondsToUs(double ts_)
{
    return static_cast<int64_t>(ts_ * 1'000'000);
}
Titta::Stream getInletTypeImpl(TittaLSL::Receiver::AllInlets& inlet_)
{
    return std::visit(
        [] <typename T>(TittaLSL::Receiver::Inlet<T>&) {
        return LSLInletTypeToTittaStream_v<T>;
    }
    , inlet_);
}

lsl::stream_inlet& getLSLInlet(TittaLSL::Receiver::AllInlets& inlet_)
{
    return std::visit(
        [](auto& in_) -> lsl::stream_inlet& {
            return in_._lsl_inlet;
        }, inlet_);
}

// helpers to make the below generic
template <typename DataType>
read_lock  lockForReading(TittaLSL::Receiver::Inlet<DataType>& inlet_) { return  read_lock(inlet_._mutex); }
template <typename DataType>
write_lock lockForWriting(TittaLSL::Receiver::Inlet<DataType>& inlet_) { return write_lock(inlet_._mutex); }
template <typename DataType>
std::vector<DataType>& getBuffer(TittaLSL::Receiver::Inlet<DataType>& inlet_)
{
    return inlet_._buffer;
}
template <typename DataType>
std::tuple<typename std::vector<DataType>::iterator, typename std::vector<DataType>::iterator>
getIteratorsFromSampleAndSide(std::vector<DataType>& buf_, const size_t NSamp_, const Titta::BufferSide side_)
{
    auto startIt    = std::begin(buf_);
    auto   endIt    = std::end(buf_);
    const auto nSamp= std::min(NSamp_, std::size(buf_));

    switch (side_)
    {
    case Titta::BufferSide::Start:
        endIt   = std::next(startIt, nSamp);
        break;
    case Titta::BufferSide::End:
        startIt = std::prev(endIt  , nSamp);
        break;
    default:
        DoExitWithMsg("TittaLSL::cpp::Receiver::getIteratorsFromSampleAndSide: unknown Titta::BufferSide provided.");
        break;
    }
    return { startIt, endIt };
}

template <typename DataType>
std::tuple<typename std::vector<DataType>::iterator, typename std::vector<DataType>::iterator, bool>
getIteratorsFromTimeRange(std::vector<DataType>& buf_, const int64_t timeStart_, const int64_t timeEnd_, const bool timeIsLocalTime_)
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
        field = &DataType::localSystemTimeStamp;
    else
        field = &DataType::remoteSystemTimeStamp;

    // 3. check if requested times are before or after vector start and end
    const bool inclFirst = timeStart_ <= buf_.front().*field;
    const bool inclLast  = timeEnd_   >= buf_.back().*field;

    // 4. if start time later than beginning of samples, or end time earlier, find correct iterators
    if (!inclFirst)
        startIt = std::lower_bound(startIt, endIt, timeStart_, [&field](const DataType& a_, const int64_t& b_) {return a_.*field < b_;});
    if (!inclLast)
        endIt   = std::upper_bound(startIt, endIt, timeEnd_  , [&field](const int64_t& a_, const DataType& b_) {return a_ < b_.*field;});

    // 5. done, return
    return {startIt, endIt, inclFirst&&inclLast};
}

template <typename T>
std::vector<T> consumeFromVec(std::vector<T>& buf_, typename std::vector<T>::iterator startIt_, typename std::vector<T>::iterator endIt_)
{
    if (std::empty(buf_))
        return std::vector<T>{};

    // move out the indicated elements
    if (startIt_==std::begin(buf_) && endIt_==std::end(buf_))
        // whole buffer
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
void clearVec(TittaLSL::Receiver::Inlet<DataType>& inlet_, const int64_t timeStart_, const int64_t timeEnd_, const bool timeIsLocalTime_)
{
    auto l = lockForWriting(inlet_);  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer(inlet_);
    if (std::empty(buf))
        return;

    // find applicable range
    auto [startIt, endIt, whole] = getIteratorsFromTimeRange(buf, timeStart_, timeEnd_, timeIsLocalTime_);
    // clear the flagged bit
    if (whole)
        buf.clear();
    else
        buf.erase(startIt, endIt);
}
}

namespace TittaLSL
{
Receiver::Receiver(std::string streamSourceID_, const std::optional<size_t> initialBufferSize_, const std::optional<bool> startListening_)
{
    if (streamSourceID_.empty())
        DoExitWithMsg("TittaLSL::cpp::Receiver: must specify stream source ID, cannot be empty");

    // find stream with specified source ID
    const auto streams = lsl::resolve_stream("source_id", streamSourceID_, 1, 2.);
    if (streams.empty())
        DoExitWithMsg(string_format("TittaLSL::cpp::Receiver: stream with source ID %s could not be found", streamSourceID_.c_str()));
    else if (streams.size()>1)
        DoExitWithMsg(string_format("TittaLSL::cpp::Receiver: more than one stream with source ID %s found", streamSourceID_.c_str()));

    create(streams[0], initialBufferSize_, startListening_);
}
Receiver::Receiver(lsl::stream_info streamInfo_, std::optional<size_t> initialBufferSize_, std::optional<bool> doStartRecording_)
{
    create(std::move(streamInfo_), initialBufferSize_, doStartRecording_);
}
void Receiver::create(lsl::stream_info streamInfo_, std::optional<size_t> initialBufferSize_, std::optional<bool> doStartListening_)
{
    // deal with default arguments
    const auto doStartRecording = doStartListening_.value_or(defaults::createStartsRecording);

    if (!streamInfo_.source_id().starts_with("TittaLSL:Tobii_"))
        DoExitWithMsg(string_format("TittaLSL::cpp::Receiver: stream %s (source_id: %s) is not an TittaLSL stream, cannot be used.", streamInfo_.name().c_str(), streamInfo_.source_id().c_str()));

# define MAKE_INLET(type, defaultName) \
    _inlet = std::make_unique<AllInlets>(std::in_place_type<Inlet<gaze>>, streamInfo_); \
    auto& inlet = getInlet<type>(); \
    createdInlet = &inlet._lsl_inlet; \
    getBuffer<type>(inlet).reserve(initialBufferSize_.value_or(defaults::defaultName));

    // subscribe to the stream
    const auto sType = streamInfo_.type();
    lsl::stream_inlet* createdInlet = nullptr;
    if (sType =="Gaze")
    {
        MAKE_INLET(TittaLSL::Receiver::gaze, gazeBufSize)
    }
    else if (sType == "TTL")
    {
        MAKE_INLET(TittaLSL::Receiver::extSignal, extSignalBufSize)
    }
    else if (sType == "TimeSync")
    {
        MAKE_INLET(TittaLSL::Receiver::timeSync, timeSyncBufSize)
    }
    else if (sType == "Positioning")
    {
        MAKE_INLET(TittaLSL::Receiver::positioning, positioningBufSize)
    }
    else
        DoExitWithMsg(string_format("TittaLSL::cpp::Receiver: stream %s (source_id: %s}) has type %s, which is not understood.", streamInfo_.name().c_str(), streamInfo_.source_id().c_str(), sType.c_str()));

    if (createdInlet)
    {
        // immediately start time offset collection, we'll need that
        createdInlet->time_correction(5.);

        // start the stream
        if (doStartRecording)
            start();
    }
#undef MAKE_INLET
}
Receiver::~Receiver()
{
    stop();
    // std::unique_ptr cleanup takes care of the rest
}

template <typename DataType>
void TittaLSL::Receiver::checkInletType() const
{
    if (!std::holds_alternative<TittaLSL::Receiver::Inlet<DataType>>(*_inlet))
    {
        const auto wanted = LSLInletTypeToTittaStream_v<DataType>;
        const auto actual = getInletTypeImpl(*_inlet);
        DoExitWithMsg(string_format("TittaLSL::cpp::Receiver: Inlet should be of type %s, but instead was of type %s. Fatal error", Titta::streamToString(wanted).c_str(), Titta::streamToString(actual).c_str()));
    }
}

template <typename DataType>
TittaLSL::Receiver::Inlet<DataType>& Receiver::getInlet() const
{
    checkInletType<DataType>();

    return std::get<Inlet<DataType>>(*_inlet);
}
std::unique_ptr<std::thread>& Receiver::getWorkerThread(TittaLSL::Receiver::AllInlets& inlet_)
{
    return std::visit(
        [](auto& in_) -> std::unique_ptr<std::thread>&{
            return in_._recorder;
        }, inlet_);
}
bool Receiver::getWorkerThreadStopFlag(TittaLSL::Receiver::AllInlets& inlet_)
{
    return std::visit(
        [](auto& in_) -> bool {
            return in_._recorder_should_stop;
        }, inlet_);
}
void Receiver::setWorkerThreadStopFlag(TittaLSL::Receiver::AllInlets& inlet_)
{
    std::visit(
        [](auto& in_){
            in_._recorder_should_stop = true;
        }, inlet_);
}

std::vector<lsl::stream_info> Receiver::GetStreams(std::string stream_, const std::optional<double> timeout_, const bool snake_case_on_stream_not_found)
{
    if (!stream_.empty())
        return GetStreams(Titta::stringToStream(std::move(stream_), snake_case_on_stream_not_found, true), timeout_);
    else
        return GetStreams(std::nullopt, timeout_);
}
std::vector<lsl::stream_info> Receiver::GetStreams(const std::optional<Titta::Stream> stream_, const std::optional<double> timeout_)
{
    // deal with default arguments
    const auto timeout = timeout_.value_or(1.);

    // filter if wanted
    if (stream_.has_value())
    {
        if (*stream_!=Titta::Stream::Gaze && *stream_!=Titta::Stream::ExtSignal && *stream_!=Titta::Stream::TimeSync && *stream_!=Titta::Stream::Positioning)
            DoExitWithMsg(string_format("TittaLSL::cpp::Receiver::GetStreams: %s streams are not supported.", Titta::streamToString(*stream_).c_str()));
        const auto streamName = string_format("Tobii_%s", Titta::streamToString(*stream_).c_str());
        return lsl::resolve_stream("name", streamName, 0, timeout);
    }
    else
        return lsl::resolve_streams(timeout);
}

Titta::Stream Receiver::getType() const
{
    return getInletTypeImpl(*_inlet);
}

lsl::stream_info Receiver::getInfo() const
{
    // get inlet
    lsl::stream_inlet& lslInlet = std::visit(
        [](auto& in_) -> lsl::stream_inlet& {
            return in_._lsl_inlet;
        }, * _inlet);

    // return it's stream info
    return lslInlet.info(2.);
}

void Receiver::start()
{
    auto& inlet = *_inlet;
    // ignore if listener already started
    if (getWorkerThread(inlet))
        return;

    // start receiving samples
    auto& lslInlet = getLSLInlet(inlet);
    lslInlet.open_stream(5.);

    // start recorder thread
    switch (getType())
    {
    case Titta::Stream::Gaze:
    case Titta::Stream::EyeOpenness:
        getInlet<gaze>()._recorder = std::make_unique<std::thread>(&Receiver::recorderThreadFunc<gaze>, this);
        break;
    case Titta::Stream::ExtSignal:
        getInlet<gaze>()._recorder = std::make_unique<std::thread>(&Receiver::recorderThreadFunc<extSignal>, this);
        break;
    case Titta::Stream::TimeSync:
        getInlet<gaze>()._recorder = std::make_unique<std::thread>(&Receiver::recorderThreadFunc<timeSync>, this);
        break;
    case Titta::Stream::Positioning:
        getInlet<gaze>()._recorder = std::make_unique<std::thread>(&Receiver::recorderThreadFunc<positioning>, this);
        break;
    }
}

bool Receiver::isRecording() const
{
    auto& inlet = *_inlet;
    return getWorkerThread(inlet) && !getWorkerThreadStopFlag(inlet);
}

template <typename DataType>
void Receiver::recorderThreadFunc()
{
    using data_t = LSLChannelFormatToCppType_t<LSLInletTypeToChannelFormat_v<DataType>>;
    constexpr size_t numElem = LSLInletTypeNumSamples_v<DataType>;
    using array_t = data_t[numElem];
    auto& inlet = getInlet<DataType>();
    double lastTCorr = -1.;
    while (!inlet._recorder_should_stop)
    {
        array_t sample = { 0 };
        double remoteT = 0.;
        double tCorr = 0.;
        try
        {
            remoteT = inlet._lsl_inlet.template pull_sample<data_t, numElem>(sample, 0.1);
        }
        catch (const lsl::lost_error&)
        {
            break;
        }
        if (remoteT <= 0.)
            // no new sample available
            continue;

        try
        {
            tCorr = inlet._lsl_inlet.time_correction(0);
        }
        catch (const lsl::timeout_error&)
        {
            tCorr = lastTCorr;
        }
        catch (const lsl::lost_error&)
        {
            break;
        }
        lastTCorr = tCorr;

        // now parse into type
        if constexpr (std::is_same_v<DataType, TittaLSL::Receiver::gaze>)
        {
            data_t* ptr = sample;
            inlet._buffer.emplace_back(TittaLSL::Receiver::gaze{
                {
                    {   // left eye
                        {   // gazePoint
                            {   // position_on_display_area
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            {   // position_in_user_coordinates
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                        {   // pupilData
                            static_cast<float>(*ptr++),
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                        {   // gazeOrigin
                            {   // position_in_user_coordinates
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            {   // position_in_track_box_coordinates
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                        {   // eyeOpenness
                            static_cast<float>(*ptr++),
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                    },
                    // right eye
                    {
                        {   // gazePoint
                            {   // position_on_display_area
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            {   // position_in_user_coordinates
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                        {   // pupilData
                            static_cast<float>(*ptr++),
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                        {   // gazeOrigin
                            {   // position_in_user_coordinates
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            {   // position_in_track_box_coordinates
                                static_cast<float>(*ptr++), static_cast<float>(*ptr++), static_cast<float>(*ptr++)
                            },
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                        {   // eyeOpenness
                            static_cast<float>(*ptr++),
                            *ptr++ == 1. ? TOBII_RESEARCH_VALIDITY_VALID : TOBII_RESEARCH_VALIDITY_INVALID,
                            *ptr++ == 1.
                        },
                    },
                    // device time
                    timeStampSecondsToUs(*ptr),
                    // system timestamp, transmitted as remote time
                    timeStampSecondsToUs(remoteT),
                },
            timeStampSecondsToUs(remoteT),
            timeStampSecondsToUs(remoteT + tCorr)
            });
        }
        else if constexpr (std::is_same_v<DataType, TittaLSL::Receiver::extSignal>)
        {
            data_t* ptr = sample;
            inlet._buffer.emplace_back(TittaLSL::Receiver::extSignal{
                {
                    *ptr++, *ptr++, static_cast<uint32_t>(*ptr++), *ptr==TOBII_RESEARCH_EXTERNAL_SIGNAL_VALUE_CHANGED? TOBII_RESEARCH_EXTERNAL_SIGNAL_VALUE_CHANGED: *ptr == TOBII_RESEARCH_EXTERNAL_SIGNAL_INITIAL_VALUE? TOBII_RESEARCH_EXTERNAL_SIGNAL_INITIAL_VALUE: TOBII_RESEARCH_EXTERNAL_SIGNAL_CONNECTION_RESTORED
                },
                timeStampSecondsToUs(remoteT),
                timeStampSecondsToUs(remoteT + tCorr)
            });
        }
        else if constexpr (std::is_same_v<DataType, TittaLSL::Receiver::timeSync>)
        {
            data_t* ptr = sample;
            inlet._buffer.emplace_back(TittaLSL::Receiver::timeSync{
                {
                    *ptr++, *ptr++, *ptr
                },
                timeStampSecondsToUs(remoteT),
                timeStampSecondsToUs(remoteT + tCorr)
            });
        }
        else if constexpr (std::is_same_v<DataType, TittaLSL::Receiver::positioning>)
        {
            data_t* ptr = sample;
            inlet._buffer.emplace_back(TittaLSL::Receiver::positioning{
                {
                    // left eye
                    {
                        {*ptr++, *ptr++, *ptr++},
                        *ptr++ == 1.f ? TOBII_RESEARCH_VALIDITY_VALID: TOBII_RESEARCH_VALIDITY_INVALID
                    },
                    // right eye
                    {
                        {*ptr++, *ptr++, *ptr++},
                        *ptr   == 1.f ? TOBII_RESEARCH_VALIDITY_VALID: TOBII_RESEARCH_VALIDITY_INVALID
                    }
                },
                timeStampSecondsToUs(remoteT),
                timeStampSecondsToUs(remoteT + tCorr)
            });
        }
    }
    // also marked as stopped
    inlet._recorder_should_stop = true;
}


template <typename DataType>
std::vector<DataType> Receiver::consumeN(const std::optional<size_t> NSamp_, const std::optional<Titta::BufferSide> side_)
{
    // deal with default arguments
    const auto N    = NSamp_.value_or(defaults::consumeNSamp);
    const auto side = side_ .value_or(defaults::consumeSide);

    auto& inlet = getInlet<DataType>();
    auto l      = lockForWriting(inlet);  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer(inlet);

    auto [startIt, endIt] = getIteratorsFromSampleAndSide(buf, N, side);
    return consumeFromVec(buf, startIt, endIt);
}
template <typename DataType>
std::vector<DataType> Receiver::consumeTimeRange(const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_, const std::optional<bool> timeIsLocalTime_)
{
    // deal with default arguments
    const auto timeStart        = timeStart_      .value_or(defaults::consumeTimeRangeStart);
    const auto timeEnd          = timeEnd_        .value_or(defaults::consumeTimeRangeEnd);
    const auto timeIsLocalTime  = timeIsLocalTime_.value_or(defaults::timeIsLocalTime);

    auto& inlet = getInlet<DataType>();
    auto l      = lockForWriting(inlet);  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer(inlet);

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange(buf, timeStart, timeEnd, timeIsLocalTime);
    return consumeFromVec(buf, startIt, endIt);
}

template <typename DataType>
std::vector<DataType> Receiver::peekN(const std::optional<size_t> NSamp_, const std::optional<Titta::BufferSide> side_)
{
    // deal with default arguments
    const auto N    = NSamp_.value_or(defaults::peekNSamp);
    const auto side = side_ .value_or(defaults::peekSide);

    auto& inlet = getInlet<DataType>();
    auto l      = lockForReading(inlet);
    auto& buf   = getBuffer(inlet);

    auto [startIt, endIt] = getIteratorsFromSampleAndSide(buf, N, side);
    return peekFromVec(buf, startIt, endIt);
}
template <typename DataType>
std::vector<DataType> Receiver::peekTimeRange(const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_, const std::optional<bool> timeIsLocalTime_)
{
    // deal with default arguments
    auto timeStart       = timeStart_      .value_or(defaults::peekTimeRangeStart);
    auto timeEnd         = timeEnd_        .value_or(defaults::peekTimeRangeEnd);
    auto timeIsLocalTime = timeIsLocalTime_.value_or(defaults::timeIsLocalTime);

    auto& inlet     = getInlet<DataType>();
    auto l          = lockForReading(inlet);
    auto& buf       = getBuffer(inlet);

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange(buf, timeStart, timeEnd, timeIsLocalTime);
    return peekFromVec(buf, startIt, endIt);
}

void Receiver::clear()
{
    // visit with generic lambda so we get the inlet, lock and cal clear() on its buffer
    const auto stream = getType();
    if (stream == Titta::Stream::Positioning)
    {
        auto& inlet = getInlet<TittaLSL::Receiver::positioning>();
        auto l      = lockForWriting(inlet);    // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
        auto& buf   = getBuffer(inlet);
        if (std::empty(buf))
            return;
        buf.clear();
    }
    else
        clearTimeRange();
}
void Receiver::clearTimeRange(const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_, const std::optional<bool> timeIsLocalTime_)
{
    // deal with default arguments
    const auto timeStart        = timeStart_      .value_or(defaults::clearTimeRangeStart);
    const auto timeEnd          = timeEnd_        .value_or(defaults::clearTimeRangeEnd);
    const auto timeIsLocalTime  = timeIsLocalTime_.value_or(defaults::timeIsLocalTime);

    // visit with templated lambda that allows us to get the data type, then
    // check if type is positioning, error, else forward. May need to split in two
    // overloaded lambdas actually, first for positioning, then templated generic
    switch (getType())
    {
        case Titta::Stream::Gaze:
        case Titta::Stream::EyeOpenness:
            clearVec(getInlet<TittaLSL::Receiver::gaze>(), timeStart, timeEnd, timeIsLocalTime);
            break;
        case Titta::Stream::ExtSignal:
            clearVec(getInlet<TittaLSL::Receiver::extSignal>(), timeStart, timeEnd, timeIsLocalTime);
            break;
        case Titta::Stream::TimeSync:
            clearVec(getInlet<TittaLSL::Receiver::timeSync>(), timeStart, timeEnd, timeIsLocalTime);
            break;
        case Titta::Stream::Positioning:
            DoExitWithMsg("Titta::cpp::Receiver::clearTimeRange: not supported for the positioning stream.");
            break;
    }
}

void Receiver::stop(const std::optional<bool> clearBuffer_)
{
    // deal with default arguments
    const auto clearBuffer = clearBuffer_.value_or(defaults::stopBufferEmpties);

    auto& inlet = *_inlet;
    const auto& thr = getWorkerThread(inlet);
    if (thr && thr->joinable())
    {
        auto& lsl_inlet = getLSLInlet(inlet);

        // stop thread
        setWorkerThreadStopFlag(inlet);
        getWorkerThread(inlet)->join();

        // close stream
        lsl_inlet.close_stream();

        // flush to be sure there's nothing stale left in LSL's buffers that would appear when we restart
        lsl_inlet.flush();
    }

    // clean up if wanted
    if (clearBuffer)
        clear();
}

// gaze data (including eye openness), instantiate templated functions
template std::vector<TittaLSL::Receiver::gaze> Receiver::consumeN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<TittaLSL::Receiver::gaze> Receiver::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<TittaLSL::Receiver::gaze> Receiver::peekN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<TittaLSL::Receiver::gaze> Receiver::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// external signals, instantiate templated functions
template std::vector<TittaLSL::Receiver::extSignal> Receiver::consumeN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<TittaLSL::Receiver::extSignal> Receiver::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<TittaLSL::Receiver::extSignal> Receiver::peekN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<TittaLSL::Receiver::extSignal> Receiver::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// time sync data, instantiate templated functions
template std::vector<TittaLSL::Receiver::timeSync> Receiver::consumeN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<TittaLSL::Receiver::timeSync> Receiver::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);
template std::vector<TittaLSL::Receiver::timeSync> Receiver::peekN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
template std::vector<TittaLSL::Receiver::timeSync> Receiver::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_);

// positioning data, instantiate templated functions
// NB: positioning data does not have timestamps, so the Time Range version of the below functions are not defined for the positioning stream
template std::vector<TittaLSL::Receiver::positioning> Receiver::consumeN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
//template std::vector<TittaLSL::Receiver::positioning> Receiver::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TittaLSL::Receiver::positioning> Receiver::peekN(std::optional<size_t> NSamp_, std::optional<Titta::BufferSide> side_);
//template std::vector<TittaLSL::Receiver::positioning> Receiver::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
}