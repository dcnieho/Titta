#include "Titta/Titta.h"
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

    // Map string to a Data Stream
    const std::map<std::string, Titta::DataStream> dataStreamMap =
    {
        { "gaze",           Titta::DataStream::Gaze },
        { "eyeOpenness",    Titta::DataStream::EyeOpenness },
        { "eye_openness",   Titta::DataStream::EyeOpenness },
        { "eyeImage",       Titta::DataStream::EyeImage },
        { "eye_image",      Titta::DataStream::EyeImage },
        { "externalSignal", Titta::DataStream::ExtSignal },
        { "external_signal",Titta::DataStream::ExtSignal },
        { "timeSync",       Titta::DataStream::TimeSync },
        { "time_sync",      Titta::DataStream::TimeSync },
        { "positioning",    Titta::DataStream::Positioning },
        { "notification",   Titta::DataStream::Notification }
    };

    // Map string to a Sample Side
    const std::map<std::string, Titta::BufferSide> bufferSideMap =
    {
        { "start",          Titta::BufferSide::Start },
        { "end",            Titta::BufferSide::End }
    };

    std::unique_ptr<std::vector<Titta*>> g_allInstances = std::make_unique<std::vector<Titta*>>();
}

Titta::DataStream Titta::stringToDataStream(std::string stream_)
{
    auto it = dataStreamMap.find(stream_);
    if (it == dataStreamMap.end())
        DoExitWithMsg(
            R"(Titta::cpp: Requested stream ")" + stream_ + R"(" is not recognized. Supported streams are: )" + Titta::getAllDataStreamsString("\"")
        );
    return it->second;
}

std::string Titta::dataStreamToString(Titta::DataStream stream_)
{
    auto v = *find_if(dataStreamMap.begin(), dataStreamMap.end(), [&stream_](auto p) {return p.second == stream_;});
    return v.first;
}

std::vector<std::string> Titta::getAllDataStreams()
{
    using val_t = typename std::underlying_type<Titta::DataStream>::type;
    std::vector<std::string> out;

    for (auto val = static_cast<val_t>(Titta::DataStream::Gaze); val < static_cast<val_t>(Titta::DataStream::Last); val++)
        out.push_back(Titta::dataStreamToString(static_cast<Titta::DataStream>(val)));

    return out;
}

std::string Titta::getAllDataStreamsString(const char* quoteChar_ /*= "\""*/)
{
    std::string out;
    bool first = true;
    for (auto const& s : Titta::getAllDataStreams())
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
    auto it = bufferSideMap.find(bufferSide_);
    if (it == bufferSideMap.end())
        DoExitWithMsg(
            R"(Titta::cpp: Requested buffer side ")" + bufferSide_ + R"(" is not recognized. Supported buffer sides are: )" + Titta::getAllBufferSidesString("\"")
        );
    return it->second;
}

std::string Titta::bufferSideToString(Titta::BufferSide bufferSide_)
{
    auto v = *find_if(bufferSideMap.begin(), bufferSideMap.end(), [&bufferSide_](auto p) {return p.second == bufferSide_;});
    return v.first;
}

std::vector<std::string> Titta::getAllBufferSides()
{
    using val_t = typename std::underlying_type<Titta::BufferSide>::type;
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
void TobiiGazeCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        instance->receiveSample(gaze_data_, nullptr);
    }
}
void TobiiEyeOpennessCallback(TobiiResearchEyeOpennessData* openness_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        instance->receiveSample(nullptr, openness_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        auto l = instance->lockForWriting<Titta::eyeImage>();
        instance->_eyeImages.emplace_back(eye_image_);
    }
}
void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        auto l = instance->lockForWriting<Titta::eyeImage>();
        instance->_eyeImages.emplace_back(eye_image_);
    }
}
void TobiiExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        auto l = instance->lockForWriting<Titta::extSignal>();
        instance->_extSignal.push_back(*ext_signal_);
    }
}
void TobiiTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        auto l = instance->lockForWriting<Titta::timeSync>();
        instance->_timeSync.push_back(*time_sync_data_);
    }
}
void TobiiPositioningCallback(TobiiResearchUserPositionGuide* position_data_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        auto l = instance->lockForWriting<Titta::positioning>();
        instance->_positioning.push_back(*position_data_);
    }
}
void TobiiLogCallback(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_)
{
    if (Titta::_logMessages)
    {
        auto l = write_lock(Titta::_logsMutex);
        Titta::_logMessages->emplace_back(Titta::logMessage(system_time_stamp_, source_, level_, message_));
    }
}
void TobiiStreamErrorCallback(TobiiResearchStreamErrorData* errorData_, void* user_data)
{
    if (Titta::_logMessages && errorData_)
    {
        std::string serial;
        if (user_data)
        {
            char* serial_number;
            tobii_research_get_serial_number(static_cast<TobiiResearchEyeTracker*>(user_data), &serial_number);
            serial = serial_number;
            tobii_research_free_string(serial_number);
        }
        auto l = write_lock(Titta::_logsMutex);
        Titta::_logMessages->emplace_back(Titta::streamError(serial,errorData_->system_time_stamp, errorData_->error, errorData_->source, errorData_->message));
    }
}
void TobiiNotificationCallback(TobiiResearchNotification* notification_, void* user_data)
{
    if (user_data)
    {
        auto instance = static_cast<Titta*>(user_data);
        auto l = instance->lockForWriting<Titta::notification>();
        instance->_notification.emplace_back(*notification_);
    }
}

// info getter static functions
TobiiResearchSDKVersion Titta::getSDKVersion()
{
    TobiiResearchSDKVersion sdk_version;
    TobiiResearchStatus status = tobii_research_get_sdk_version(&sdk_version);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get Tobii SDK version", status);
    return sdk_version;
}
int64_t Titta::getSystemTimestamp()
{
    int64_t system_time_stamp;
    TobiiResearchStatus status = tobii_research_get_system_time_stamp(&system_time_stamp);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get Tobii SDK system time", status);
    return system_time_stamp;
}
std::vector<TobiiTypes::eyeTracker> Titta::findAllEyeTrackers()
{
    TobiiResearchEyeTrackers* tobiiTrackers = nullptr;
    TobiiResearchStatus status = tobii_research_find_all_eyetrackers(&tobiiTrackers);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye trackers", status);
    std::vector<TobiiTypes::eyeTracker> eyeTrackers;

    eyeTrackers.insert(eyeTrackers.end(), &tobiiTrackers->eyetrackers[0], &tobiiTrackers->eyetrackers[tobiiTrackers->count]);   // yes, pointer to one past last element
    tobii_research_free_eyetrackers(tobiiTrackers);

    return eyeTrackers;
}

// logging static functions
bool Titta::startLogging(std::optional<size_t> initialBufferSize_)
{
    if (!_logMessages)
        _logMessages = std::make_unique<std::vector<allLogTypes>>();

    // deal with default arguments
    auto initialBufferSize = initialBufferSize_.value_or(defaults::logBufSize);

    auto l = write_lock(Titta::_logsMutex);
    _logMessages->reserve(initialBufferSize);
    auto result = tobii_research_logging_subscribe(TobiiLogCallback);

    if (g_allInstances)
    {
        // also start stream error logging on all instances
        for (auto inst : *g_allInstances)
            if (inst->_eyetracker.et)
                tobii_research_subscribe_to_stream_errors(inst->_eyetracker.et, TobiiStreamErrorCallback, inst->_eyetracker.et);
    }

    return _isLogging = result == TOBII_RESEARCH_STATUS_OK;
}
std::vector<Titta::allLogTypes> Titta::getLog(std::optional<bool> clearLog_)
{
    if (!_logMessages)
        return {};

    // deal with default arguments
    auto clearLog = clearLog_.value_or(defaults::logBufClear);

    auto l = write_lock(Titta::_logsMutex);
    if (clearLog)
        return std::vector<allLogTypes>(std::move(*_logMessages));
    else
        // provide a copy
        return std::vector<allLogTypes>(*_logMessages);
}
bool Titta::stopLogging()
{
    auto result = tobii_research_logging_unsubscribe();
    auto success = result == TOBII_RESEARCH_STATUS_OK;
    if (success)
        _isLogging = false;

    if (g_allInstances)
    {
        // also stop stream error logging on all instances
        for (auto inst: *g_allInstances)
            if (inst->_eyetracker.et)
                tobii_research_unsubscribe_from_stream_errors(inst->_eyetracker.et, TobiiStreamErrorCallback);
    }

    return success;
}

namespace
{
    // eye image helpers
    TobiiResearchStatus doSubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, Titta* instance_, bool asGif_)
    {
        if (asGif_)
            return tobii_research_subscribe_to_eye_image_as_gif(eyetracker_, TobiiEyeImageGifCallback, instance_);
        else
            return tobii_research_subscribe_to_eye_image       (eyetracker_,    TobiiEyeImageCallback, instance_);
    }
    TobiiResearchStatus doUnsubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, bool isGif_)
    {
        if (isGif_)
            return tobii_research_unsubscribe_from_eye_image_as_gif(eyetracker_, TobiiEyeImageGifCallback);
        else
            return tobii_research_unsubscribe_from_eye_image       (eyetracker_,    TobiiEyeImageCallback);
    }
}




Titta::Titta(std::string address_)
{
    TobiiResearchEyeTracker* et;
    TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(),&et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker \"" + address_ + "\"", status);
    _eyetracker = TobiiTypes::eyeTracker(et);
    Init();
}
Titta::Titta(TobiiResearchEyeTracker* et_)
{
    _eyetracker = TobiiTypes::eyeTracker(et_);
    Init();
}
Titta::~Titta()
{
    stop(DataStream::Gaze,        true);
    stop(DataStream::EyeOpenness, true);
    stop(DataStream::EyeImage,    true);
    stop(DataStream::ExtSignal,   true);
    stop(DataStream::TimeSync,    true);
    stop(DataStream::Positioning, true);
    stop(DataStream::Notification,true);

    if (_eyetracker.et)
        tobii_research_unsubscribe_from_stream_errors(_eyetracker.et, TobiiStreamErrorCallback);
    stopLogging();

    leaveCalibrationMode(false);

    if (g_allInstances)
    {
        auto it = std::find(g_allInstances->begin(), g_allInstances->end(), this);
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
            TobiiResearchSDKVersion version;
            tobii_research_get_sdk_version(&version);
            std::stringstream os;
            os << "Using C SDK version: " << version.major << "." << version.minor << "." << version.revision << "." << version.build;
            auto l = lockForWriting<Titta::logMessage>();
            Titta::_logMessages->emplace_back(Titta::logMessage(0, TOBII_RESEARCH_LOG_SOURCE_SDK, TOBII_RESEARCH_LOG_LEVEL_INFORMATION, os.str()));
        }

        // start stream error logging
        tobii_research_subscribe_to_stream_errors(_eyetracker.et, TobiiStreamErrorCallback, _eyetracker.et);
    }
    start(DataStream::Notification);    // always start notification stream as soon as we're connected
    if (g_allInstances)
        g_allInstances->push_back(this);
}

// getters and setters
const TobiiTypes::eyeTracker Titta::getEyeTrackerInfo(std::optional<std::string> paramToRefresh_ /*= std::nullopt*/)
{
    // refresh ET info to make sure its up to date
    _eyetracker.refreshInfo(paramToRefresh_);

    return _eyetracker;
}
const TobiiResearchTrackBox Titta::getTrackBox() const
{
    TobiiResearchTrackBox track_box;
    TobiiResearchStatus status = tobii_research_get_track_box(_eyetracker.et, &track_box);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker track box", status);
    return track_box;
}
const TobiiResearchDisplayArea Titta::getDisplayArea() const
{
    TobiiResearchDisplayArea display_area;
    TobiiResearchStatus status = tobii_research_get_display_area(_eyetracker.et, &display_area);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot get eye tracker display area", status);
    return display_area;
}
// setters
void Titta::setDeviceName(std::string deviceName_)
{
    TobiiResearchStatus status = tobii_research_set_device_name(_eyetracker.et, deviceName_.c_str());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot set eye tracker device name", status);

    // refresh eye tracker info to get updated name
    _eyetracker.refreshInfo("deviceName");
}
void Titta::setFrequency(float frequency_)
{
    TobiiResearchStatus status = tobii_research_set_gaze_output_frequency(_eyetracker.et, frequency_);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot set eye tracker frequency", status);

    // refresh eye tracker info to get updated frequency
    _eyetracker.refreshInfo("frequency");
}
void Titta::setTrackingMode(std::string trackingMode_)
{
    TobiiResearchStatus status = tobii_research_set_eye_tracking_mode(_eyetracker.et, trackingMode_.c_str());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot set eye tracker tracking mode", status);

    // refresh eye tracker info to get updated tracking mode
    _eyetracker.refreshInfo("trackingMode");
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
    TobiiResearchStatus status = tobii_research_apply_licenses(_eyetracker.et, const_cast<const void**>(reinterpret_cast<void**>(licenseKeyRing.data())), licenseLengths.data(), validationResults.data(), licenses_.size());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot apply eye tracker license(s)", status);

    // refresh eye tracker info, e.g. capabilities may have changed after license applied
    _eyetracker.refreshInfo();

    return validationResults;
}
void Titta::clearLicenses()
{
    TobiiResearchStatus status = tobii_research_clear_applied_licenses(_eyetracker.et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp: Cannot clear eye tracker license(s)", status);

    // refresh eye tracker info, e.g. capabilities may have changed after licenses removed
    _eyetracker.refreshInfo();
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
            result = tobii_research_screen_based_calibration_enter_calibration_mode(_eyetracker.et);
            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        case TobiiTypes::CalibrationAction::CollectData:
        {
            // Start a data collection
            _calibrationState = TobiiTypes::CalibrationState::CollectingData;
            auto& coords = workItem.coordinates.value();
            if (_calibrationIsMonocular)
            {
                TobiiResearchSelectedEye collectEye=TOBII_RESEARCH_SELECTED_EYE_LEFT, ignore;
                if (workItem.eye == "right")
                    collectEye = TOBII_RESEARCH_SELECTED_EYE_RIGHT;
                
                result = tobii_research_screen_based_monocular_calibration_collect_data(_eyetracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]), collectEye, &ignore);
            }
            else
                result = tobii_research_screen_based_calibration_collect_data(_eyetracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]));

            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::DiscardData:
        {
            // discard calibration data for a specific point
            _calibrationState = TobiiTypes::CalibrationState::DiscardingData;
            auto& coords = workItem.coordinates.value();
            if (_calibrationIsMonocular)
            {
                TobiiResearchSelectedEye discardEye = TOBII_RESEARCH_SELECTED_EYE_LEFT;
                if (workItem.eye == "right")
                    discardEye = TOBII_RESEARCH_SELECTED_EYE_RIGHT;
                result = tobii_research_screen_based_monocular_calibration_discard_data(_eyetracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]), discardEye);
            }
            else
                result = tobii_research_screen_based_calibration_discard_data(_eyetracker.et, static_cast<float>(coords[0]), static_cast<float>(coords[1]));

            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::Compute:
        {
            _calibrationState = TobiiTypes::CalibrationState::Computing;
            TobiiResearchCalibrationResult* computeResult;
            if (_calibrationIsMonocular)
                result = tobii_research_screen_based_monocular_calibration_compute_and_apply(_eyetracker.et, &computeResult);
            else
                result = tobii_research_screen_based_calibration_compute_and_apply(_eyetracker.et, &computeResult);

            _calibrationWorkResultQueue.enqueue({ workItem, result, {}, computeResult });
            tobii_research_free_screen_based_calibration_result(computeResult);

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::GetCalibrationData:
        {
            _calibrationState = TobiiTypes::CalibrationState::GettingCalibrationData;
            TobiiResearchCalibrationData* calData;

            result = tobii_research_retrieve_calibration_data(_eyetracker.et, &calData);

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
                auto nItem = workItem.calibrationData.value().size();
                calData.data = malloc(nItem);
                calData.size = nItem;
                if (nItem)
                    std::memcpy(calData.data, &workItem.calibrationData.value()[0], nItem);

                result = tobii_research_apply_calibration_data(_eyetracker.et, &calData);
                free(calData.data);

                _calibrationWorkResultQueue.enqueue({workItem, result});
            }
            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::Exit:
            // leave calibration mode and exit
            result = tobii_research_screen_based_calibration_leave_calibration_mode(_eyetracker.et);
            _calibrationWorkResultQueue.enqueue({workItem, result});
            keepRunning = false;
            break;
        }
    }

    _calibrationState = TobiiTypes::CalibrationState::Left;
}
bool Titta::enterCalibrationMode(bool doMonocular_)
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
bool Titta::isInCalibrationMode(std::optional<bool> issueErrorIfNot_)
{
    bool doError = issueErrorIfNot_.value_or(defaults::doErrorWhenCheckCallMode);
    bool isInCal = _calibrationThread.joinable();
    if (!isInCal && doError)
        DoExitWithMsg("Titta::cpp::isInCalibrationMode: you have not entered calibration mode, call enterCalibrationMode first");

    return isInCal;
}
bool Titta::leaveCalibrationMode(std::optional<bool> force_)
{
    bool forceIt = force_.value_or(defaults::forceExitCalibrationMode);
    bool issuedLeave = false;
    if (forceIt)
    {
        // call leave calibration mode on Tobii SDK, ignore error if any
        // this is provided as user code may need to ensure we're not in
        // calibration mode, e.g. after a previous crash
        tobii_research_screen_based_calibration_leave_calibration_mode(_eyetracker.et);
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
void addCoordsEyeToWorkItem(TobiiTypes::CalibrationWorkItem& workItem, std::array<double, 2> coordinates_, std::optional<std::string> eye_)
{
    workItem.coordinates = {coordinates_.begin(),coordinates_.end()};
    if (eye_)
    {
        workItem.eye = *eye_;
        if (workItem.eye != "left" && workItem.eye != "right")
            DoExitWithMsg(
                "Titta::cpp::calibrationCollectData: Cannot start calibration for eye " + workItem.eye.value() + ", unknown. Expected left or right."
            );
    }
}
void Titta::calibrationCollectData(std::array<double, 2> coordinates_, std::optional<std::string> eye_)
{
    isInCalibrationMode(true);
    TobiiTypes::CalibrationWorkItem workItem{TobiiTypes::CalibrationAction::CollectData};
    addCoordsEyeToWorkItem(workItem, coordinates_, eye_);
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
void Titta::calibrationDiscardData(std::array<double, 2> coordinates_, std::optional<std::string> eye_)
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
        {
            std::stringstream os;
            os << "Tobii SDK code: " << static_cast<int>(out.status) << ": " << TobiiResearchStatusToString(out.status) << " (" << TobiiResearchStatusToExplanation(out.status) << ")";
            out.statusString = os.str();
        }
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
Titta::getIteratorsFromSampleAndSide(size_t NSamp_, Titta::BufferSide side_)
{
    auto& buf    = getBuffer<T>();
    auto startIt = std::begin(buf);
    auto   endIt = std::end(buf);
    auto nSamp   = std::min(NSamp_, std::size(buf));

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
Titta::getIteratorsFromTimeRange(int64_t timeStart_, int64_t timeEnd_)
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
    bool inclFirst = timeStart_ <= buf.front().*field;
    bool inclLast  = timeEnd_   >= buf.back().*field;

    // 4. if start time later than beginning of samples, or end time earlier, find correct iterators
    if (!inclFirst)
        startIt = std::lower_bound(startIt, endIt, timeStart_, [&field](const T& a_, const int64_t& b_) {return a_.*field < b_;});
    if (!inclLast)
        endIt   = std::upper_bound(startIt, endIt, timeEnd_  , [&field](const int64_t& a_, const T& b_) {return a_ < b_.*field;});

    // 5. done, return
    return {startIt, endIt, inclFirst&&inclLast};
}


bool Titta::hasStream(std::string stream_) const
{
    return hasStream(stringToDataStream(stream_));
}
bool Titta::hasStream(DataStream  stream_) const
{
    bool supported = false;
    switch (stream_)
    {
        case DataStream::Gaze:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA;
        case DataStream::EyeOpenness:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA;
        case DataStream::EyeImage:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES;
        case DataStream::ExtSignal:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL;
        case DataStream::TimeSync:
            return true;    // no capability that can be checked for this one
        case DataStream::Positioning:
            return true;    // no capability that can be checked for this one
        case DataStream::Notification:
            return true;    // no capability that can be checked for this one
    }

    return supported;
}

bool Titta::setIncludeEyeOpennessInGaze(bool include_)
{
    if (include_ && !hasStream(DataStream::EyeOpenness))
        DoExitWithMsg(
            "Titta::cpp::setIncludeEyeOpennessInGaze: Cannot request to record the " + dataStreamToString(DataStream::EyeOpenness) + " stream, this eye tracker does not provide it"
        );

    auto previous = _includeEyeOpennessInGaze;
    _includeEyeOpennessInGaze = include_;
    // start/stop eye openness stream if needed
    if (_recordingGaze && !_includeEyeOpennessInGaze && _recordingEyeOpenness)
    {
        stop(DataStream::EyeOpenness);
    }
    else if (_recordingGaze && _includeEyeOpennessInGaze && !_recordingEyeOpenness)
    {
        start(DataStream::EyeOpenness);
    }

    return previous;
}

bool Titta::start(std::string stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
{
    return start(stringToDataStream(stream_), initialBufferSize_, asGif_);
}
bool Titta::start(DataStream  stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
{
    TobiiResearchStatus result=TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
        case DataStream::Gaze:
        {
            if (_recordingGaze)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::sampleBufSize);
                // prepare buffer
                {
                    auto l = lockForWriting<gaze>();
                    _gaze.reserve(initialBufferSize);   // NB: if already reserved when starting eye openness, this will not shrink
                }
                // start buffer
                result = tobii_research_subscribe_to_gaze_data(_eyetracker.et, TobiiGazeCallback, this);
                stateVar = &_recordingGaze;
            }
            break;
        }
        case DataStream::EyeOpenness:
        {
            if (_recordingEyeOpenness)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::sampleBufSize);
                // prepare buffer
                {
                    auto l = lockForWriting<gaze>();
                    _gaze.reserve(initialBufferSize);   // NB: if already reserved when starting gaze, this will not shrink
                }
                // start buffer
                result = tobii_research_subscribe_to_eye_openness(_eyetracker.et, TobiiEyeOpennessCallback, this);
                stateVar = &_recordingEyeOpenness;
            }
            break;
        }
        case DataStream::EyeImage:
        {
            if (_recordingEyeImages)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::eyeImageBufSize);
                auto asGif             = asGif_.value_or(defaults::eyeImageAsGIF);

                // prepare and start buffer
                {
                    auto l = lockForWriting<eyeImage>();
                    _eyeImages.reserve(initialBufferSize);
                }

                // if already recording and switching from gif to normal or other way, first stop old stream
                if (_recordingEyeImages)
                    if (asGif != _eyeImIsGif)
                        doUnsubscribeEyeImage(_eyetracker.et, _eyeImIsGif);
                    else
                        // nothing to do
                        return true;

                // subscribe to new stream
                result = doSubscribeEyeImage(_eyetracker.et, this, asGif);
                stateVar = &_recordingEyeImages;
                if (result==TOBII_RESEARCH_STATUS_OK)
                    // update type being recorded if subscription to stream was successful
                    _eyeImIsGif = asGif;
            }
            break;
        }
        case DataStream::ExtSignal:
        {
            if (_recordingExtSignal)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::extSignalBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<extSignal>();
                    _extSignal.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_external_signal_data(_eyetracker.et, TobiiExtSignalCallback, this);
                stateVar = &_recordingExtSignal;
            }
            break;
        }
        case DataStream::TimeSync:
        {
            if (_recordingTimeSync)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::timeSyncBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<timeSync>();
                    _timeSync.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_time_synchronization_data(_eyetracker.et, TobiiTimeSyncCallback, this);
                stateVar = &_recordingTimeSync;
            }
            break;
        }
        case DataStream::Positioning:
        {
            if (_recordingPositioning)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::positioningBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<positioning>();
                    _positioning.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_user_position_guide(_eyetracker.et, TobiiPositioningCallback, this);
                stateVar = &_recordingPositioning;
            }
            break;
        }
        case DataStream::Notification:
        {
            if (_recordingNotification)
                result = TOBII_RESEARCH_STATUS_OK;
            else
            {
                // deal with default arguments
                auto initialBufferSize = initialBufferSize_.value_or(defaults::notificationBufSize);
                // prepare and start buffer
                {
                    auto l = lockForWriting<notification>();
                    _notification.reserve(initialBufferSize);
                }
                result = tobii_research_subscribe_to_notifications(_eyetracker.et, TobiiNotificationCallback, this);
                stateVar = &_recordingNotification;
            }
            break;
        }
    }

    if (stateVar)
        *stateVar = result==TOBII_RESEARCH_STATUS_OK;

    if (result != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Titta::cpp::start: Cannot start recording " + dataStreamToString(stream_) + " stream", result);
    else
    {
        // if requested to merge gaze and eye openness, a call to start eye openness also starts gaze
        if (     stream_==DataStream::EyeOpenness && _includeEyeOpennessInGaze && !_recordingGaze)
            return start(DataStream::Gaze       , initialBufferSize_, asGif_);
        // if requested to merge gaze and eye openness, a call to start gaze also starts eye openness
        else if (stream_==DataStream::Gaze        && _includeEyeOpennessInGaze && !_recordingEyeOpenness)
            return start(DataStream::EyeOpenness, initialBufferSize_, asGif_);
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

void Titta::receiveSample(TobiiResearchGazeData* gaze_data_, TobiiResearchEyeOpennessData* openness_data_)
{
    auto needStage = _recordingGaze && _recordingEyeOpenness;
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
        auto lOut = lockForWriting<Titta::gaze>();
        _gaze.insert(_gaze.end(), std::make_move_iterator(emitBuffer.begin()), std::make_move_iterator(emitBuffer.end()));
    }
}

bool Titta::isRecording(std::string stream_) const
{
    return isRecording(stringToDataStream(stream_));
}
bool Titta::isRecording(DataStream  stream_) const
{
    bool success = false;
    switch (stream_)
    {
        case DataStream::Gaze:
            return _recordingGaze;
        case DataStream::EyeOpenness:
            return _recordingEyeOpenness;
        case DataStream::EyeImage:
            return _recordingEyeImages;
        case DataStream::ExtSignal:
            return _recordingExtSignal;
        case DataStream::TimeSync:
            return _recordingTimeSync;
        case DataStream::Positioning:
            return _recordingPositioning;
        case DataStream::Notification:
            return _recordingNotification;
    }

    return success;
}

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
std::vector<T> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_)
{
    // deal with default arguments
    auto N      = NSamp_.value_or(defaults::consumeNSamp);
    auto side   = side_.value_or(defaults::consumeSide);

    auto l      = lockForWriting<T>();  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer<T>();

    auto [startIt, endIt] = getIteratorsFromSampleAndSide<T>(N, side);
    return consumeFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    auto timeStart  = timeStart_.value_or(defaults::consumeTimeRangeStart);
    auto timeEnd    = timeEnd_  .value_or(defaults::consumeTimeRangeEnd);

    auto l          = lockForWriting<T>();  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf       = getBuffer<T>();

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
    auto N      = NSamp_.value_or(defaults::peekNSamp);
    auto side   = side_.value_or(defaults::peekSide);

    auto l      = lockForReading<T>();
    auto& buf   = getBuffer<T>();

    auto [startIt, endIt] = getIteratorsFromSampleAndSide<T>(N, side);
    return peekFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    auto timeStart  = timeStart_.value_or(defaults::peekTimeRangeStart);
    auto timeEnd    = timeEnd_  .value_or(defaults::peekTimeRangeEnd);

    auto l          = lockForReading<T>();
    auto& buf       = getBuffer<T>();

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<T>(timeStart, timeEnd);
    return peekFromVec(buf, startIt, endIt);
}

template <typename T>
void Titta::clearImpl(int64_t timeStart_, int64_t timeEnd_)
{
    auto l      = lockForWriting<T>();  // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf   = getBuffer<T>();
    if (std::empty(buf))
        return;

    // find applicable range
    auto[start, end, whole] = getIteratorsFromTimeRange<T>(timeStart_, timeEnd_);
    // clear the flagged bit
    if (whole)
        buf.clear();
    else
        buf.erase(start, end);
}
void Titta::clear(std::string stream_)
{
    clear(stringToDataStream(stream_));
}
void Titta::clear(DataStream stream_)
{
    if (stream_ == DataStream::Positioning)
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
void Titta::clearTimeRange(std::string stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    clearTimeRange(stringToDataStream(stream_), timeStart_, timeEnd_);
}
void Titta::clearTimeRange(DataStream stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    auto timeStart = timeStart_.value_or(defaults::clearTimeRangeStart);
    auto timeEnd   = timeEnd_  .value_or(defaults::clearTimeRangeEnd);

    switch (stream_)
    {
        case DataStream::Gaze:
        case DataStream::EyeOpenness:
            clearImpl<gaze>(timeStart, timeEnd);
            break;
        case DataStream::EyeImage:
            clearImpl<eyeImage>(timeStart, timeEnd);
            break;
        case DataStream::ExtSignal:
            clearImpl<extSignal>(timeStart, timeEnd);
            break;
        case DataStream::TimeSync:
            clearImpl<timeSync>(timeStart, timeEnd);
            break;
        case DataStream::Positioning:
            DoExitWithMsg("Titta::cpp::clearTimeRange: not supported for the positioning stream.");
            break;
        case DataStream::Notification:
            clearImpl<notification>(timeStart, timeEnd);
            break;
    }
}

bool Titta::stop(std::string stream_, std::optional<bool> clearBuffer_)
{
    return stop(stringToDataStream(stream_), clearBuffer_);
}

bool Titta::stop(DataStream  stream_, std::optional<bool> clearBuffer_)
{
    // deal with default arguments
    auto clearBuffer = clearBuffer_.value_or(defaults::stopBufferEmpties);

    TobiiResearchStatus result=TOBII_RESEARCH_STATUS_OK;
    bool* stateVar = nullptr;
    switch (stream_)
    {
        case DataStream::Gaze:
            result = !_recordingGaze ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_gaze_data(_eyetracker.et, TobiiGazeCallback);
            stateVar = &_recordingGaze;
            break;
        case DataStream::EyeOpenness:
            result = !_recordingEyeOpenness ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_eye_openness(_eyetracker.et, TobiiEyeOpennessCallback);
            stateVar = &_recordingEyeOpenness;
            break;
        case DataStream::EyeImage:
            result = !_recordingEyeImages ? TOBII_RESEARCH_STATUS_OK : doUnsubscribeEyeImage(_eyetracker.et, _eyeImIsGif);
            stateVar = &_recordingEyeImages;
            break;
        case DataStream::ExtSignal:
            result = !_recordingExtSignal ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_external_signal_data(_eyetracker.et, TobiiExtSignalCallback);
            stateVar = &_recordingExtSignal;
            break;
        case DataStream::TimeSync:
            result = !_recordingTimeSync ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_time_synchronization_data(_eyetracker.et, TobiiTimeSyncCallback);
            stateVar = &_recordingTimeSync;
            break;
        case DataStream::Positioning:
            result = !_recordingPositioning ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_user_position_guide(_eyetracker.et, TobiiPositioningCallback);
            stateVar = &_recordingPositioning;
            break;
        case DataStream::Notification:
            result = !_recordingNotification ? TOBII_RESEARCH_STATUS_OK : tobii_research_unsubscribe_from_notifications(_eyetracker.et, TobiiNotificationCallback);
            stateVar = &_recordingNotification;
            break;
    }

    if (clearBuffer)
        clear(stream_);

    bool success = result == TOBII_RESEARCH_STATUS_OK;
    if (stateVar && success)
        *stateVar = false;

    // if requested to merge gaze and eye openness, a call to stop eye openness also stops gaze
    if (stream_==DataStream::EyeOpenness && _includeEyeOpennessInGaze && _recordingGaze)
    {
        return stop(DataStream::Gaze, clearBuffer) && success;
    }
    // if requested to merge gaze and eye openness, a call to stop gaze also stops eye openness
    else if (stream_==DataStream::Gaze && _includeEyeOpennessInGaze && _recordingEyeOpenness)
    {
        return stop(DataStream::EyeOpenness, clearBuffer) && success;
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
//template std::vector<Titta::positioning> Tobii::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::positioning> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
//template std::vector<Titta::positioning> Tobii::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// time sync data, instantiate templated functions
template std::vector<Titta::notification> Titta::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::notification> Titta::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<Titta::notification> Titta::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<Titta::notification> Titta::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
