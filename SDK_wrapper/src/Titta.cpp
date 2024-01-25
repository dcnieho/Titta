#include "Titta/Titta.h"
#include <vector>
#include <algorithm>
#include <string_view>
#include <map>
#include <cstring>

#include "Titta/utils.h"

namespace
{
    // default argument values
    namespace defaults
    {
        constexpr bool                  doErrorWhenCheckCallMode  = false;
        constexpr bool                  forceExitCalibrationMode  = false;

        constexpr size_t                sampleBufSize             = 2<<19;        // about half an hour at 600Hz

        constexpr size_t                eyeImageBufSize           = 2<<11;        // about seven minutes at 2*5Hz
        constexpr bool                  eyeImageAsGIF             = false;

        constexpr size_t                extSignalBufSize          = 2<<9;

        constexpr size_t                timeSyncBufSize           = 2<<9;

        constexpr size_t                positioningBufSize        = 2<<11;

        constexpr size_t                notificationBufSize       = 2<<6;

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

        constexpr size_t                logBufSize                = 2<<8;
        constexpr bool                  logBufClear               = true;
    }

    // Map string to a Stream
    const std::map<std::string, Titta::Stream> streamMapCamelCase =
    {
        { "gaze",           Titta::Stream::Gaze },
        { "eyeOpenness",    Titta::Stream::EyeOpenness },
        { "eyeImage",       Titta::Stream::EyeImage },
        { "externalSignal", Titta::Stream::ExtSignal },
        { "timeSync",       Titta::Stream::TimeSync },
        { "positioning",    Titta::Stream::Positioning },
        { "notification",   Titta::Stream::Notification }
    };
    const std::map<std::string, Titta::Stream> streamMapSnakeCase =
    {
        { "gaze",           Titta::Stream::Gaze },
        { "eye_openness",   Titta::Stream::EyeOpenness },
        { "eye_image",      Titta::Stream::EyeImage },
        { "external_signal",Titta::Stream::ExtSignal },
        { "time_sync",      Titta::Stream::TimeSync },
        { "positioning",    Titta::Stream::Positioning },
        { "notification",   Titta::Stream::Notification }
    };

    // Map string to a Sample Side
    const std::map<std::string, Titta::BufferSide> bufferSideMap =
    {
        { "start",          Titta::BufferSide::Start },
        { "end",            Titta::BufferSide::End }
    };

    std::unique_ptr<std::vector<Titta*>> g_allInstances = std::make_unique<std::vector<Titta*>>();
}

Titta::Stream Titta::stringToStream(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/, const bool forLSL_ /*= false*/)
{
    auto it = streamMapCamelCase.find(stream_);
    if (it == streamMapCamelCase.end())
    {
        it = streamMapSnakeCase.find(stream_);
        if (it == streamMapSnakeCase.end())
        {
            DoExitWithMsg(
                R"(Titta::cpp: Requested stream ")" + stream_ + R"(" is not recognized. Supported streams are: )" + Titta::getAllStreamsString("\"", snake_case_on_stream_not_found, forLSL_)
            );
        }
    }
    return it->second;
}

std::string Titta::streamToString(Titta::Stream stream_, const bool snakeCase_ /*= false*/)
{
    std::pair<std::string, Titta::Stream> v;
    if (snakeCase_)
        v = *std::find_if(streamMapSnakeCase.begin(), streamMapSnakeCase.end(), [&stream_](auto p_) {return p_.second == stream_;});
    else
        v = *std::find_if(streamMapCamelCase.begin(), streamMapCamelCase.end(), [&stream_](auto p_) {return p_.second == stream_;});
    return v.first;
}

std::vector<std::string> Titta::getAllStreams(const bool snakeCase_ /*= false*/, const bool forLSL_ /*= false*/)
{
    using val_t = std::underlying_type_t<Titta::Stream>;
    std::vector<std::string> out;

    for (auto val = static_cast<val_t>(Titta::Stream::Gaze); val < static_cast<val_t>(Titta::Stream::Last); val++)
        if (!forLSL_ || !(val==static_cast<val_t>(Titta::Stream::EyeOpenness) || val==static_cast<val_t>(Titta::Stream::Notification)))
            out.push_back(Titta::streamToString(static_cast<Titta::Stream>(val), snakeCase_));

    return out;
}

std::string Titta::getAllStreamsString(const char* quoteChar_ /*= "\""*/, const bool snakeCase_ /*= false*/, const bool forLSL_ /*= false*/)
{
    std::string out;
    bool first = true;
    for (auto const& s : Titta::getAllStreams(snakeCase_, forLSL_))
    {
        if (first)
            first = false;
        else
            out += ", ";
        out += quoteChar_ + s + quoteChar_;
    }
    return out;
}


Titta::BufferSide Titta::stringToBufferSide(std::string bufferSide_)
{
    const auto it = bufferSideMap.find(bufferSide_);
    if (it == bufferSideMap.end())
        DoExitWithMsg(
            R"(Titta::cpp: Requested buffer side ")" + bufferSide_ + R"(" is not recognized. Supported buffer sides are: )" + Titta::getAllBufferSidesString("\"")
        );
    return it->second;
}

std::string Titta::bufferSideToString(Titta::BufferSide bufferSide_)
{
    auto& v = *find_if(bufferSideMap.begin(), bufferSideMap.end(), [&bufferSide_](auto p_) {return p_.second == bufferSide_;});
    return v.first;
}

std::vector<std::string> Titta::getAllBufferSides()
{
    using val_t = std::underlying_type_t<Titta::BufferSide>;
    std::vector<std::string> out;

    for (auto val = static_cast<val_t>(Titta::BufferSide::Start); val < static_cast<val_t>(Titta::BufferSide::Last); val++)
        out.push_back(Titta::bufferSideToString(static_cast<Titta::BufferSide>(val)));

    return out;
}

std::string Titta::getAllBufferSidesString(const char* quoteChar_ /*= "\""*/)
{
    std::string out;
    bool first = true;
    for (auto const& s : Titta::getAllBufferSides())
    {
        if (first)
            first = false;
        else
            out += ", ";
        out += quoteChar_ + s + quoteChar_;
    }
    return out;
}

// callbacks
void TittaGazeCallback(TobiiResearchGazeData* gaze_data_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        instance->receiveSample(gaze_data_, nullptr);
    }
}
void TittaEyeOpennessCallback(TobiiResearchEyeOpennessData* openness_data_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        instance->receiveSample(nullptr, openness_data_);
    }
}
void TittaEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        auto l = instance->lockForWriting<Titta::eyeImage>();
        instance->_eyeImages.emplace_back(eye_image_);
    }
}
void TittaEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        auto l = instance->lockForWriting<Titta::eyeImage>();
        instance->_eyeImages.emplace_back(eye_image_);
    }
}
void TittaExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        auto l = instance->lockForWriting<Titta::extSignal>();
        instance->_extSignal.push_back(*ext_signal_);
    }
}
void TittaTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        auto l = instance->lockForWriting<Titta::timeSync>();
        instance->_timeSync.push_back(*time_sync_data_);
    }
}
void TittaPositioningCallback(TobiiResearchUserPositionGuide* position_data_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        auto l = instance->lockForWriting<Titta::positioning>();
        instance->_positioning.push_back(*position_data_);
    }
}
void TittaLogCallback(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_)
{
    if (Titta::_logMessages)
    {
        auto l = write_lock(Titta::_logsMutex);
        Titta::_logMessages->emplace_back(Titta::logMessage(system_time_stamp_, source_, level_, message_));
    }
}
void TittaStreamErrorCallback(TobiiResearchStreamErrorData* errorData_, void* user_data_)
{
    if (Titta::_logMessages && errorData_)
    {
        std::string serial;
        if (user_data_)
        {
            char* serial_number;
            tobii_research_get_serial_number(static_cast<TobiiResearchEyeTracker*>(user_data_), &serial_number);
            serial = serial_number;
            tobii_research_free_string(serial_number);
        }
        auto l = write_lock(Titta::_logsMutex);
        Titta::_logMessages->emplace_back(Titta::streamError(std::move(serial), errorData_->system_time_stamp, errorData_->error, errorData_->source, errorData_->message));
    }
}
void TittaNotificationCallback(TobiiResearchNotification* notification_, void* user_data_)
{
    if (user_data_)
    {
        const auto instance = static_cast<Titta*>(user_data_);
        auto l = instance->lockForWriting<Titta::notification>();
        instance->_notification.emplace_back(*notification_);
    }
}

// info getter static functions
TobiiResearchSDKVersion Titta::getSDKVersion()
{
    TobiiResearchSDKVersion sdk_version;
    const TobiiResearchStatus status = tobii_research_get_sdk_version(&sdk_version);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get Tobii SDK version", status);
    return sdk_version;
}
int64_t Titta::getSystemTimestamp()
{
    int64_t system_time_stamp;
    const TobiiResearchStatus status = tobii_research_get_system_time_stamp(&system_time_stamp);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get Tobii SDK system time", status);
    return system_time_stamp;
}
std::vector<TobiiTypes::eyeTracker> Titta::findAllEyeTrackers()
{
    TobiiResearchEyeTrackers* tobiiTrackers = nullptr;
    const TobiiResearchStatus status = tobii_research_find_all_eyetrackers(&tobiiTrackers);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye trackers", status);
    std::vector<TobiiTypes::eyeTracker> eyeTrackers;

    eyeTrackers.insert(eyeTrackers.end(), &tobiiTrackers->eyetrackers[0], &tobiiTrackers->eyetrackers[tobiiTrackers->count]);   // yes, pointer to one past last element
    tobii_research_free_eyetrackers(tobiiTrackers);

    return eyeTrackers;
}
TobiiTypes::eyeTracker Titta::getEyeTrackerFromAddress(std::string address_)
{
    TobiiResearchEyeTracker* et;
    const TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(), &et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker \"" + address_ + "\"", status);
    return et;
}

// logging static functions
bool Titta::startLogging(std::optional<size_t> initialBufferSize_)
{
    if (!_logMessages)
        _logMessages = std::make_unique<std::vector<allLogTypes>>();

    // deal with default arguments
    const auto initialBufferSize = initialBufferSize_.value_or(defaults::logBufSize);

    auto l = write_lock(Titta::_logsMutex);
    _logMessages->reserve(initialBufferSize);
    const auto result = tobii_research_logging_subscribe(TittaLogCallback);

    if (g_allInstances)
    {
        // also start stream error logging on all instances
        for (const auto inst : *g_allInstances)
            if (inst->_eyeTracker.et)
                tobii_research_subscribe_to_stream_errors(inst->_eyeTracker.et, TittaStreamErrorCallback, inst->_eyeTracker.et);
    }

    return _isLogging = result == TOBII_RESEARCH_STATUS_OK;
}
std::vector<Titta::allLogTypes> Titta::getLog(std::optional<bool> clearLog_)
{
    if (!_logMessages)
        return {};

    // deal with default arguments
    const auto clearLog = clearLog_.value_or(defaults::logBufClear);

    auto l = write_lock(Titta::_logsMutex);
    if (clearLog)
        return { std::move(*_logMessages) };
    else
        // provide a copy
        return { *_logMessages };
}
bool Titta::stopLogging()
{
    const auto result = tobii_research_logging_unsubscribe();
    const auto success = result == TOBII_RESEARCH_STATUS_OK;
    if (success)
        _isLogging = false;

    if (g_allInstances)
    {
        // also stop stream error logging on all instances
        for (const auto inst: *g_allInstances)
            if (inst->_eyeTracker.et)
                tobii_research_unsubscribe_from_stream_errors(inst->_eyeTracker.et, TittaStreamErrorCallback);
    }

    return success;
}

namespace
{
    // eye image helpers
    TobiiResearchStatus doSubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, Titta* instance_, const bool asGif_)
    {
        if (asGif_)
            return tobii_research_subscribe_to_eye_image_as_gif(eyetracker_, TittaEyeImageGifCallback, instance_);
        else
            return tobii_research_subscribe_to_eye_image       (eyetracker_,    TittaEyeImageCallback, instance_);
    }
    TobiiResearchStatus doUnsubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, const bool isGif_)
    {
        if (isGif_)
            return tobii_research_unsubscribe_from_eye_image_as_gif(eyetracker_, TittaEyeImageGifCallback);
        else
            return tobii_research_unsubscribe_from_eye_image       (eyetracker_,    TittaEyeImageCallback);
    }
}




Titta::Titta(std::string address_)
{
    TobiiResearchEyeTracker* et;
    const TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(), &et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker \"" + address_ + "\"", status);
    _eyeTracker = TobiiTypes::eyeTracker(et);
    Init();
}
Titta::Titta(TobiiResearchEyeTracker* et_)
{
    _eyeTracker = TobiiTypes::eyeTracker(et_);
    Init();
}
Titta::~Titta()
{
    stop(Stream::Gaze,        true);
    stop(Stream::EyeOpenness, true);
    stop(Stream::EyeImage,    true);
    stop(Stream::ExtSignal,   true);
    stop(Stream::TimeSync,    true);
    stop(Stream::Positioning, true);
    stop(Stream::Notification,true);

    if (_eyeTracker.et)
        tobii_research_unsubscribe_from_stream_errors(_eyeTracker.et, TittaStreamErrorCallback);
    stopLogging();

    leaveCalibrationMode(false);

    if (g_allInstances)
    {
        const auto it = std::find(g_allInstances->begin(), g_allInstances->end(), this);
        if (it != g_allInstances->end())
            g_allInstances->erase(it, it + 1);
    }
}
void Titta::Init()
{
    if (_isLogging)
    {
        // log version of SDK dll that is being used
        if (Titta::_logMessages)
        {
            TobiiResearchSDKVersion v;
            tobii_research_get_sdk_version(&v);
            auto l = lockForWriting<Titta::logMessage>();
            Titta::_logMessages->emplace_back(Titta::logMessage(0, TOBII_RESEARCH_LOG_SOURCE_SDK, TOBII_RESEARCH_LOG_LEVEL_INFORMATION, string_format("Using C SDK version: %d.%d.%d.%d", v.major, v.minor, v.revision, v.build)));
        }

        // start stream error logging
        tobii_research_subscribe_to_stream_errors(_eyeTracker.et, TittaStreamErrorCallback, _eyeTracker.et);
    }
    start(Stream::Notification);    // always start notification stream as soon as we're connected
    if (g_allInstances)
        g_allInstances->push_back(this);
}

// getters and setters
TobiiTypes::eyeTracker Titta::getEyeTrackerInfo(std::optional<std::string> paramToRefresh_ /*= std::nullopt*/)
{
    // refresh ET info to make sure its up to date
    _eyeTracker.refreshInfo(std::move(paramToRefresh_));

    return _eyeTracker;
}
TobiiResearchTrackBox Titta::getTrackBox() const
{
    TobiiResearchTrackBox track_box;
    const TobiiResearchStatus status = tobii_research_get_track_box(_eyeTracker.et, &track_box);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker track box", status);
    return track_box;
}
TobiiResearchDisplayArea Titta::getDisplayArea() const
{
    TobiiResearchDisplayArea display_area;
    const TobiiResearchStatus status = tobii_research_get_display_area(_eyeTracker.et, &display_area);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker display area", status);
    return display_area;
}
// setters
void Titta::setDeviceName(std::string deviceName_)
{
    const TobiiResearchStatus status = tobii_research_set_device_name(_eyeTracker.et, deviceName_.c_str());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot set eye tracker device name", status);

    // refresh eye tracker info to get updated name
    _eyeTracker.refreshInfo("deviceName");
}
void Titta::setFrequency(const float frequency_)
{
    const TobiiResearchStatus status = tobii_research_set_gaze_output_frequency(_eyeTracker.et, frequency_);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot set eye tracker frequency", status);

    // refresh eye tracker info to get updated frequency
    _eyeTracker.refreshInfo("frequency");
}
void Titta::setTrackingMode(std::string trackingMode_)
{
    const TobiiResearchStatus status = tobii_research_set_eye_tracking_mode(_eyeTracker.et, trackingMode_.c_str());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot set eye tracker tracking mode", status);

    // refresh eye tracker info to get updated tracking mode
    _eyeTracker.refreshInfo("trackingMode");
}
// modifiers
std::vector<TobiiResearchLicenseValidationResult> Titta::applyLicenses(std::vector<std::vector<uint8_t>> licenses_)
{
    std::vector<uint8_t*> licenseKeyRing;
    std::vector<size_t>   licenseLengths;
    for (auto& license : licenses_)
    {
        licenseKeyRing.push_back(license.data());
        licenseLengths.push_back(license.size());
    }
    std::vector<TobiiResearchLicenseValidationResult> validationResults(licenses_.size(), TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_UNKNOWN);
    const TobiiResearchStatus status = tobii_research_apply_licenses(_eyeTracker.et, const_cast<const void**>(reinterpret_cast<void**>(licenseKeyRing.data())), licenseLengths.data(), validationResults.data(), licenses_.size());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot apply eye tracker license(s)", status);

    // refresh eye tracker info, e.g. capabilities may have changed after license applied
    _eyeTracker.refreshInfo();

    return validationResults;
}
void Titta::clearLicenses()
{
    const TobiiResearchStatus status = tobii_research_clear_applied_licenses(_eyeTracker.et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot clear eye tracker license(s)", status);

    // refresh eye tracker info, e.g. capabilities may have changed after licenses removed
    _eyeTracker.refreshInfo();
}

//// calibration
void Titta::calibrationThread()
{
    bool keepRunning = true;
    TobiiResearchStatus result;
    while (keepRunning)
    {
        TobiiTypes::CalibrationWorkItem workItem;
        _calibrationWorkQueue.wait_dequeue(workItem);
        switch (workItem.action)
        {
        case TobiiTypes::CalibrationAction::Nothing:
            // no-op
            break;
        case TobiiTypes::CalibrationAction::Enter:
            // enter calibration mode
            result = tobii_research_screen_based_calibration_enter_calibration_mode(_eyeTracker.et);
            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        case TobiiTypes::CalibrationAction::CollectData:
        {
            // Start a data collection
            _calibrationState = TobiiTypes::CalibrationState::CollectingData;
            auto& coords = *workItem.coordinates;
            if (_calibrationIsMonocular)
            {
                TobiiResearchSelectedEye collectEye=TOBII_RESEARCH_SELECTED_EYE_LEFT, ignore;
                if (workItem.eye == "right")
                    collectEye = TOBII_RESEARCH_SELECTED_EYE_RIGHT;

                result = tobii_research_screen_based_monocular_calibration_collect_data(_eyeTracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]), collectEye, &ignore);
            }
            else
                result = tobii_research_screen_based_calibration_collect_data(_eyeTracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]));

            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::DiscardData:
        {
            // discard calibration data for a specific point
            _calibrationState = TobiiTypes::CalibrationState::DiscardingData;
            auto& coords = *workItem.coordinates;
            if (_calibrationIsMonocular)
            {
                TobiiResearchSelectedEye discardEye = TOBII_RESEARCH_SELECTED_EYE_LEFT;
                if (workItem.eye == "right")
                    discardEye = TOBII_RESEARCH_SELECTED_EYE_RIGHT;
                result = tobii_research_screen_based_monocular_calibration_discard_data(_eyeTracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]), discardEye);
            }
            else
                result = tobii_research_screen_based_calibration_discard_data(_eyeTracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]));

            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::Compute:
        {
            _calibrationState = TobiiTypes::CalibrationState::Computing;
            TobiiResearchCalibrationResult* computeResult;
            if (_calibrationIsMonocular)
                result = tobii_research_screen_based_monocular_calibration_compute_and_apply(_eyeTracker.et, &computeResult);
            else
                result = tobii_research_screen_based_calibration_compute_and_apply(_eyeTracker.et, &computeResult);

            _calibrationWorkResultQueue.enqueue({ workItem, result, {}, computeResult });
            tobii_research_free_screen_based_calibration_result(computeResult);

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::GetCalibrationData:
        {
            _calibrationState = TobiiTypes::CalibrationState::GettingCalibrationData;
            TobiiResearchCalibrationData* calData;

            result = tobii_research_retrieve_calibration_data(_eyeTracker.et, &calData);

            TobiiTypes::CalibrationWorkResult workResult{ workItem, result };
            if (calData->size)
                workResult.calibrationData = std::vector<uint8_t>(static_cast<uint8_t*>(calData->data), static_cast<uint8_t*>(calData->data) + calData->size);
            tobii_research_free_calibration_data(calData);
            _calibrationWorkResultQueue.enqueue(std::move(workResult));

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::ApplyCalibrationData:
        {
            _calibrationState = TobiiTypes::CalibrationState::ApplyingCalibrationData;
            if (!workItem.calibrationData.value().empty())
            {
                TobiiResearchCalibrationData calData;
                // copy calibration data into array
                const auto nItem = workItem.calibrationData.value().size();
                calData.data = malloc(nItem);
                calData.size = nItem;
                if (nItem)
                    std::memcpy(calData.data, workItem.calibrationData.value().data(), nItem);

                result = tobii_research_apply_calibration_data(_eyeTracker.et, &calData);
                free(calData.data);

                _calibrationWorkResultQueue.enqueue({workItem, result});
            }
            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::Exit:
            // leave calibration mode and exit
            result = tobii_research_screen_based_calibration_leave_calibration_mode(_eyeTracker.et);
            _calibrationWorkResultQueue.enqueue({workItem, result});
            keepRunning = false;
            break;
        }
    }

    _calibrationState = TobiiTypes::CalibrationState::Left;
}
bool Titta::enterCalibrationMode(const bool doMonocular_)
{
    if (_calibrationThread.joinable())
        return false; // Calibration mode already entered

    _calibrationIsMonocular = doMonocular_;

    // start new calibration worker
    // this calls tobii_research_screen_based_calibration_enter_calibration_mode() in the thread function
    _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::Enter});
    _calibrationState   = TobiiTypes::CalibrationState::NotYetEntered;
    _calibrationThread  = std::thread(&Titta::calibrationThread, this);

    return true;
}
bool Titta::isInCalibrationMode(std::optional<bool> issueErrorIfNot_) const
{
    const bool doError = issueErrorIfNot_.value_or(defaults::doErrorWhenCheckCallMode);
    const bool isInCal = _calibrationThread.joinable();
    if (!isInCal && doError)
        DoExitWithMsg("Titta::cpp::isInCalibrationMode: you have not entered calibration mode, call enterCalibrationMode first");

    return isInCal;
}
bool Titta::leaveCalibrationMode(std::optional<bool> force_)
{
    const bool forceIt = force_.value_or(defaults::forceExitCalibrationMode);
    bool issuedLeave   = false;
    if (forceIt)
    {
        // call leave calibration mode on Tobii SDK, ignore error if any
        // this is provided as user code may need to ensure we're not in
        // calibration mode, e.g. after a previous crash
        tobii_research_screen_based_calibration_leave_calibration_mode(_eyeTracker.et);
    }

    if (_calibrationThread.joinable())
    {
        // tell thread to quit and wait until it quits
        // this calls tobii_research_screen_based_calibration_leave_calibration_mode() in the thread function before exiting
        _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::Exit});
        _calibrationThread.join();
        issuedLeave = true;
    }

    _calibrationState = TobiiTypes::CalibrationState::NotYetEntered;
    return issuedLeave; // we indicate if a leave action had been enqueued. direct force-leave above thus does not lead us to return true
}
void addCoordsEyeToWorkItem(TobiiTypes::CalibrationWorkItem& workItem, std::array<float, 2> coordinates_, std::optional<std::string> eye_)
{
    workItem.coordinates = coordinates_;
    if (eye_)
    {
        workItem.eye = *eye_;
        if (workItem.eye != "left" && workItem.eye != "right")
            DoExitWithMsg(
                "Titta::cpp::calibrationCollectData: Cannot start calibration for eye " + workItem.eye.value() + ", unknown. Expected left or right."
            );
    }
}
void Titta::calibrationCollectData(std::array<float, 2> coordinates_, std::optional<std::string> eye_)
{
    isInCalibrationMode(true);
    TobiiTypes::CalibrationWorkItem workItem{TobiiTypes::CalibrationAction::CollectData};
    addCoordsEyeToWorkItem(workItem, coordinates_, eye_);
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
void Titta::calibrationDiscardData(std::array<float, 2> coordinates_, std::optional<std::string> eye_)
{
    isInCalibrationMode(true);
    TobiiTypes::CalibrationWorkItem workItem{TobiiTypes::CalibrationAction::DiscardData};
    addCoordsEyeToWorkItem(workItem, coordinates_, eye_);
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
void Titta::calibrationComputeAndApply()
{
    isInCalibrationMode(true);
    _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::Compute});
}
void Titta::calibrationGetData()
{
    isInCalibrationMode(true);
    _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::GetCalibrationData});
}
void Titta::calibrationApplyData(std::vector<uint8_t> calibrationData_)
{
    isInCalibrationMode(true);
    TobiiTypes::CalibrationWorkItem workItem{TobiiTypes::CalibrationAction::ApplyCalibrationData};
    workItem.calibrationData = calibrationData_;
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
TobiiTypes::CalibrationState Titta::calibrationGetStatus()
{
    return _calibrationState;
}
std::optional<TobiiTypes::CalibrationWorkResult> Titta::calibrationRetrieveResult(bool makeStatusString_ /*= false*/)
{
    TobiiTypes::CalibrationWorkResult out;
    if (_calibrationWorkResultQueue.try_dequeue(out))
    {
        if (makeStatusString_)
            out.statusString = string_format("Tobii SDK code: %d: %s (%s)", static_cast<int>(out.status), TobiiResearchStatusToString(out.status).c_str(), TobiiResearchStatusToExplanation(out.status).c_str());
        return out;
    }
    else
        return std::nullopt;
}


// helpers to make the below generic
template <typename T>
mutex_type& Titta::getMutex()
{
    if constexpr (std::is_same_v<T, Titta::gaze>)
        return _gazeMutex;
    if constexpr (std::is_same_v<T, Titta::eyeImage>)
        return _extSignalMutex;
    if constexpr (std::is_same_v<T, Titta::extSignal>)
        return _extSignalMutex;
    if constexpr (std::is_same_v<T, Titta::timeSync>)
        return _timeSyncMutex;
    if constexpr (std::is_same_v<T, Titta::positioning>)
        return _positioningMutex;
    if constexpr (std::is_same_v<T, Titta::logMessage>)
        return _logsMutex;
    if constexpr (std::is_same_v<T, Titta::streamError>)
        return _logsMutex;
    if constexpr (std::is_same_v<T, Titta::notification>)
        return _notificationMutex;
}

template <typename T>
read_lock  Titta::lockForReading() { return  read_lock(getMutex<T>()); }
template <typename T>
write_lock Titta::lockForWriting() { return write_lock(getMutex<T>()); }

template <typename T>
std::vector<T>& Titta::getBuffer()
{
    if constexpr (std::is_same_v<T, gaze>)
        return _gaze;
    if constexpr (std::is_same_v<T, eyeImage>)
        return _eyeImages;
    if constexpr (std::is_same_v<T, extSignal>)
        return _extSignal;
    if constexpr (std::is_same_v<T, timeSync>)
        return _timeSync;
    if constexpr (std::is_same_v<T, positioning>)
        return _positioning;
    if constexpr (std::is_same_v<T, notification>)
        return _notification;
}
template <typename T>
std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator>
Titta::getIteratorsFromSampleAndSide(const size_t NSamp_, const Titta::BufferSide side_)
{
    auto& buf       = getBuffer<T>();
    auto startIt    = std::begin(buf);
    auto   endIt    = std::end(buf);
    const auto nSamp= std::min(NSamp_, std::size(buf));

    switch (side_)
    {
    case Titta::BufferSide::Start:
        endIt   = std::next(startIt, nSamp);
        break;
    case Titta::BufferSide::End:
        startIt = std::prev(endIt  , nSamp);
        break;
    default:
        DoExitWithMsg("Titta::cpp::getIteratorsFromSampleAndSide: unknown TittaMex::BufferSide provided.");
        break;
    }
    return { startIt, endIt };
}

template <typename T>
std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator, bool>
Titta::getIteratorsFromTimeRange(const int64_t timeStart_, const int64_t timeEnd_)
{
    // !NB: appropriate locking is responsibility of caller!
    // find elements within given range of time stamps, both sides inclusive.
    // Since returns are iterators, what is returned is first matching element until one past last matching element
    // 1. get buffer to traverse, if empty, return
    auto& buf    = getBuffer<T>();
    auto startIt = std::begin(buf);
    auto   endIt = std::end(buf);
    if (std::empty(buf))
        return {startIt,endIt, true};

    // 2. see which member variable to access
    int64_t T::* field;
    if constexpr (std::is_same_v<T, timeSync>)
        field = &T::system_request_time_stamp;
    else
        field = &T::system_time_stamp;

    // 3. check if requested times are before or after vector start and end
    const bool inclFirst = timeStart_ <= buf.front().*field;
    const bool inclLast  = timeEnd_   >= buf.back().*field;

    // 4. if start time later than beginning of samples, or end time earlier, find correct iterators
    if (!inclFirst)
        startIt = std::lower_bound(startIt, endIt, timeStart_, [&field](const T& a_, const int64_t& b_) {return a_.*field < b_;});
    if (!inclLast)
        endIt   = std::upper_bound(startIt, endIt, timeEnd_  , [&field](const int64_t& a_, const T& b_) {return a_ < b_.*field;});

    // 5. done, return
    return {startIt, endIt, inclFirst&&inclLast};
}


bool Titta::hasStream(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/) const
{
    return hasStream(stringToStream(std::move(stream_), snake_case_on_stream_not_found));
}
bool Titta::hasStream(const Stream stream_) const
{
    switch (stream_)
    {
        case Stream::Gaze:
            return _eyeTracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA;
        case Stream::EyeOpenness:
            return _eyeTracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA;
        case Stream::EyeImage:
            return _eyeTracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES;
        case Stream::ExtSignal:
            return _eyeTracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL;
        case Stream::TimeSync:
            return true;    // no capability that can be checked for this one
        case Stream::Positioning:
            return true;    // no capability that can be checked for this one
        case Stream::Notification:
            return true;    // no capability that can be checked for this one
    }

    return false;
}

bool Titta::setIncludeEyeOpennessInGaze(const bool include_)
{
    if (include_ && !hasStream(Stream::EyeOpenness))
        DoExitWithMsg(
            "Titta::cpp::setIncludeEyeOpennessInGaze: Cannot request to record the " + streamToString(Stream::EyeOpenness) + " stream, this eye tracker does not provide it"
        );

    const auto previous = _includeEyeOpennessInGaze;
    _includeEyeOpennessInGaze = include_;
    // start/stop eye openness stream if needed
    if (_recordingGaze && !_includeEyeOpennessInGaze && _recordingEyeOpenness)
    {
        stop(Stream::EyeOpenness);
    }
    else if (_recordingGaze && _includeEyeOpennessInGaze && !_recordingEyeOpenness)
    {
        start(Stream::EyeOpenness);
    }

    return previous;
}

bool Titta::start(std::string stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_, const bool snake_case_on_stream_not_found /*= false*/)
{
    return start(stringToStream(std::move(stream_), snake_case_on_stream_not_found), initialBufferSize_, asGif_);
}
bool Titta::start(const Stream stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
{
    TobiiResearchStatus result=TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
        case Stream::Gaze:
        {
            if (_recordingGaze)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::sampleBufSize);
                // prepare buffer
                {
                    auto l = lockForWriting<gaze>();
                    _gaze.reserve(initialBufferSize);   // NB: if already reserved when starting eye openness, this will not shrink
                }
                // start buffer
                result = tobii_research_subscribe_to_gaze_data(_eyeTracker.et, TittaGazeCallback, this);
                stateVar = &_recordingGaze;
            }
            break;
        }
        case Stream::EyeOpenness:
        {
            if (_recordingEyeOpenness)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::sampleBufSize);
                // prepare buffer
                {
                    auto l = lockForWriting<gaze>();
                    _gaze.reserve(initialBufferSize);   // NB: if already reserved when starting gaze, this will not shrink
                }
                // start buffer
                result = tobii_research_subscribe_to_eye_openness(_eyeTracker.et, TittaEyeOpennessCallback, this);
                stateVar = &_recordingEyeOpenness;
            }
            break;
        }
        case Stream::EyeImage:
        {
            if (_recordingEyeImages)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::eyeImageBufSize);
                const auto asGif             = asGif_            .value_or(defaults::eyeImageAsGIF);

                // prepare and start buffer
                {
                    auto l = lockForWriting<eyeImage>();
                    _eyeImages.reserve(initialBufferSize);
                }

                // if already recording and switching from gif to normal or other way, first stop old stream
                if (_recordingEyeImages)
                    if (asGif != _eyeImIsGif)
                        doUnsubscribeEyeImage(_eyeTracker.et, _eyeImIsGif);
                    else
                        // nothing to do
                        return true;

                // subscribe to new stream
                result = doSubscribeEyeImage(_eyeTracker.et, this, asGif);
                stateVar = &_recordingEyeImages;
                if (result==TOBII_RESEARCH_STATUS_OK)
                    // update type being recorded if subscription to stream was successful
                    _eyeImIsGif = asGif;
            }
            break;
        }
        case Stream::ExtSignal:
        {
            if (_recordingExtSignal)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::extSignalBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<extSignal>();
                    _extSignal.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_external_signal_data(_eyeTracker.et, TittaExtSignalCallback, this);
                stateVar = &_recordingExtSignal;
            }
            break;
        }
        case Stream::TimeSync:
        {
            if (_recordingTimeSync)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::timeSyncBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<timeSync>();
                    _timeSync.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_time_synchronization_data(_eyeTracker.et, TittaTimeSyncCallback, this);
                stateVar = &_recordingTimeSync;
            }
            break;
        }
        case Stream::Positioning:
        {
            if (_recordingPositioning)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::positioningBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<positioning>();
                    _positioning.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_user_position_guide(_eyeTracker.et, TittaPositioningCallback, this);
                stateVar = &_recordingPositioning;
            }
            break;
        }
        case Stream::Notification:
        {
            if (_recordingNotification)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                const auto initialBufferSize = initialBufferSize_.value_or(defaults::notificationBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<notification>();
                    _notification.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_notifications(_eyeTracker.et, TittaNotificationCallback, this);
                stateVar = &_recordingNotification;
            }
            break;
        }
    }

    if (stateVar)
        *stateVar = result==TOBII_RESEARCH_STATUS_OK;

    if (result != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp::start: Cannot start recording " + streamToString(stream_) + " stream", result);
    else
    {
        // if requested to merge gaze and eye openness, a call to start eye openness also starts gaze
        if (     stream_==Stream::EyeOpenness && _includeEyeOpennessInGaze && !_recordingGaze)
            return start(Stream::Gaze       , initialBufferSize_, asGif_);
        // if requested to merge gaze and eye openness, a call to start gaze also starts eye openness
        else if (stream_==Stream::Gaze        && _includeEyeOpennessInGaze && !_recordingEyeOpenness)
            return start(Stream::EyeOpenness, initialBufferSize_, asGif_);
        return true;
    }

    // will never get here, but to make compiler happy
    return true;
}

// tobii to own type helpers
namespace {
    void convert(TobiiTypes::gazePoint& out_, const TobiiResearchGazePoint in_)
    {
        out_.position_in_user_coordinates   = in_.position_in_user_coordinates;
        out_.position_on_display_area       = in_.position_on_display_area;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::pupilData& out_, const TobiiResearchPupilData in_)
    {
        out_.diameter                       = in_.diameter;
        out_.validity                       = in_.validity;
        out_.available                      = true;
    }
    void convert(TobiiTypes::gazeOrigin& out_, const TobiiResearchGazeOrigin in_)
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
    void convert(TobiiTypes::eyeData& out_, const TobiiResearchEyeData in_)
    {
        convert(out_.gaze_point, in_.gaze_point);
        convert(out_.pupil, in_.pupil_data);
        convert(out_.gaze_origin, in_.gaze_origin);
    }
}

void Titta::receiveSample(const TobiiResearchGazeData* gaze_data_, const TobiiResearchEyeOpennessData* openness_data_)
{
    const auto needStage = _recordingGaze && _recordingEyeOpenness;
    if (!needStage && !_gazeStagingEmpty)
    {
        // if any data in staging area but no longer expecting to merge, flush to output
        auto l    = write_lock(_gazeStageMutex);
        auto lOut = lockForWriting<Titta::gaze>();
        _gaze.insert(_gaze.end(), std::make_move_iterator(_gazeStaging.begin()), std::make_move_iterator(_gazeStaging.end()));
        _gazeStaging.clear();
        _gazeStagingEmpty = true;
    }

    std::unique_lock<mutex_type> l(_gazeStageMutex, std::defer_lock);
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
        auto lOut = lockForWriting<Titta::gaze>();
        _gaze.insert(_gaze.end(), std::make_move_iterator(emitBuffer.begin()), std::make_move_iterator(emitBuffer.end()));
    }
}

bool Titta::isRecording(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/) const
{
    return isRecording(stringToStream(std::move(stream_), snake_case_on_stream_not_found));
}
bool Titta::isRecording(const Stream stream_) const
{
    switch (stream_)
    {
        case Stream::Gaze:
            return _recordingGaze;
        case Stream::EyeOpenness:
            return _recordingEyeOpenness;
        case Stream::EyeImage:
            return _recordingEyeImages;
        case Stream::ExtSignal:
            return _recordingExtSignal;
        case Stream::TimeSync:
            return _recordingTimeSync;
        case Stream::Positioning:
            return _recordingPositioning;
        case Stream::Notification:
            return _recordingNotification;
    }

    return false;
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
std::vector<T> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_)
{
    // deal with default arguments
    const auto N    = NSamp_.value_or(defaults::consumeNSamp);
    const auto side = side_.value_or(defaults::consumeSide);

    auto l          = lockForWriting<T>();  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf       = getBuffer<T>();

    auto [startIt, endIt] = getIteratorsFromSampleAndSide<T>(N, side);
    return consumeFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    const auto timeStart= timeStart_.value_or(defaults::consumeTimeRangeStart);
    const auto timeEnd  = timeEnd_  .value_or(defaults::consumeTimeRangeEnd);

    auto l              = lockForWriting<T>();  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf           = getBuffer<T>();

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<T>(timeStart, timeEnd);
    return consumeFromVec(buf, startIt, endIt);
}

template <typename T>
std::vector<T> peekFromVec(const std::vector<T>& buf_, const typename std::vector<T>::const_iterator startIt_, const typename std::vector<T>::const_iterator endIt_)
{
    if (std::empty(buf_))
        return std::vector<T>{};

    // copy the indicated elements
    return std::vector<T>(startIt_, endIt_);
}
template <typename T>
std::vector<T> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_)
{
    // deal with default arguments
    const auto N    = NSamp_.value_or(defaults::peekNSamp);
    const auto side = side_.value_or(defaults::peekSide);

    auto l          = lockForReading<T>();
    auto& buf       = getBuffer<T>();

    auto [startIt, endIt] = getIteratorsFromSampleAndSide<T>(N, side);
    return peekFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    const auto timeStart= timeStart_.value_or(defaults::peekTimeRangeStart);
    const auto timeEnd  = timeEnd_  .value_or(defaults::peekTimeRangeEnd);

    auto l              = lockForReading<T>();
    auto& buf           = getBuffer<T>();

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<T>(timeStart, timeEnd);
    return peekFromVec(buf, startIt, endIt);
}

template <typename T>
void Titta::clearImpl(const int64_t timeStart_, const int64_t timeEnd_)
{
    auto l      = lockForWriting<T>();  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer<T>();
    if (std::empty(buf))
        return;

    // find applicable range
    auto[startIt, endIt, whole] = getIteratorsFromTimeRange<T>(timeStart_, timeEnd_);
    // clear the flagged bit
    if (whole)
        buf.clear();
    else
        buf.erase(startIt, endIt);
}
void Titta::clear(std::string stream_, const bool snake_case_on_stream_not_found /*= false*/)
{
    clear(stringToStream(std::move(stream_), snake_case_on_stream_not_found));
}
void Titta::clear(const Stream stream_)
{
    if (stream_ == Stream::Positioning)
    {
        auto l      = lockForWriting<positioning>();    // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
        auto& buf   = getBuffer<positioning>();
        if (std::empty(buf))
            return;
        buf.clear();
    }
    else
        clearTimeRange(stream_);
}
void Titta::clearTimeRange(std::string stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, const bool snake_case_on_stream_not_found /*= false*/)
{
    clearTimeRange(stringToStream(std::move(stream_), snake_case_on_stream_not_found), timeStart_, timeEnd_);
}
void Titta::clearTimeRange(const Stream stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    const auto timeStart = timeStart_.value_or(defaults::clearTimeRangeStart);
    const auto timeEnd   = timeEnd_  .value_or(defaults::clearTimeRangeEnd);

    switch (stream_)
    {
        case Stream::Gaze:
        case Stream::EyeOpenness:
            clearImpl<gaze>(timeStart, timeEnd);
            break;
        case Stream::EyeImage:
            clearImpl<eyeImage>(timeStart, timeEnd);
            break;
        case Stream::ExtSignal:
            clearImpl<extSignal>(timeStart, timeEnd);
            break;
        case Stream::TimeSync:
            clearImpl<timeSync>(timeStart, timeEnd);
            break;
        case Stream::Positioning:
            DoExitWithMsg("Titta::cpp::clearTimeRange: not supported for the positioning stream.");
            break;
        case Stream::Notification:
            clearImpl<notification>(timeStart, timeEnd);
            break;
    }
}

bool Titta::stop(std::string stream_, std::optional<bool> clearBuffer_, const bool snake_case_on_stream_not_found /*= false*/)
{
    return stop(stringToStream(std::move(stream_), snake_case_on_stream_not_found), clearBuffer_);
}

bool Titta::stop(const Stream stream_, std::optional<bool> clearBuffer_)
{
    // deal with default arguments
    const auto clearBuffer = clearBuffer_.value_or(defaults::stopBufferEmpties);

    TobiiResearchStatus result=TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
        case Stream::Gaze:
            result = !_recordingGaze ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_gaze_data(_eyeTracker.et, TittaGazeCallback);
            stateVar = &_recordingGaze;
            break;
        case Stream::EyeOpenness:
            result = !_recordingEyeOpenness ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_eye_openness(_eyeTracker.et, TittaEyeOpennessCallback);
            stateVar = &_recordingEyeOpenness;
            break;
        case Stream::EyeImage:
            result = !_recordingEyeImages ? TOBII_RESEARCH_STATUS_OK : doUnsubscribeEyeImage(_eyeTracker.et, _eyeImIsGif);
            stateVar = &_recordingEyeImages;
            break;
        case Stream::ExtSignal:
            result = !_recordingExtSignal ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_external_signal_data(_eyeTracker.et, TittaExtSignalCallback);
            stateVar = &_recordingExtSignal;
            break;
        case Stream::TimeSync:
            result = !_recordingTimeSync ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_time_synchronization_data(_eyeTracker.et, TittaTimeSyncCallback);
            stateVar = &_recordingTimeSync;
            break;
        case Stream::Positioning:
            result = !_recordingPositioning ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_user_position_guide(_eyeTracker.et, TittaPositioningCallback);
            stateVar = &_recordingPositioning;
            break;
        case Stream::Notification:
            result = !_recordingNotification ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_notifications(_eyeTracker.et, TittaNotificationCallback);
            stateVar = &_recordingNotification;
            break;
    }

    if (clearBuffer)
        clear(stream_);

    const bool success = result == TOBII_RESEARCH_STATUS_OK;
    if (stateVar && success)
        *stateVar = false;

    // if requested to merge gaze and eye openness, a call to stop eye openness also stops gaze
    if (stream_==Stream::EyeOpenness && _includeEyeOpennessInGaze && _recordingGaze)
    {
        return stop(Stream::Gaze, clearBuffer) && success;
    }
    // if requested to merge gaze and eye openness, a call to stop gaze also stops eye openness
    else if (stream_==Stream::Gaze && _includeEyeOpennessInGaze && _recordingEyeOpenness)
    {
        return stop(Stream::EyeOpenness, clearBuffer) && success;
    }
    return success;
}

// gaze data (including eye openness), instantiate templated functions
template std::vector<Titta::gaze> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::gaze> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::gaze> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::gaze> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// eye images, instantiate templated functions
template std::vector<Titta::eyeImage> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::eyeImage> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::eyeImage> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::eyeImage> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// external signals, instantiate templated functions
template std::vector<Titta::extSignal> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::extSignal> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::extSignal> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::extSignal> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// time sync data, instantiate templated functions
template std::vector<Titta::timeSync> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::timeSync> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::timeSync> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::timeSync> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// positioning data, instantiate templated functions
// NB: positioning data does not have timestamps, so the Time Range version of the below functions are not defined for the positioning stream
template std::vector<Titta::positioning> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
//template std::vector<Titta::positioning> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::positioning> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
//template std::vector<Titta::positioning> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// notifications, instantiate templated functions
template std::vector<Titta::notification> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::notification> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::notification> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::notification> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
