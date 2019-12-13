#include "TobiiMex/TobiiMex.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>
#include <string_view>
#include <sstream>
#include <map>
#include <cstring>

#include "TobiiMex/utils.h"

namespace
{
    using mutex_type = std::shared_timed_mutex;
    using read_lock  = std::shared_lock<mutex_type>;
    using write_lock = std::unique_lock<mutex_type>;

    mutex_type g_mSamp, g_mEyeImage, g_mExtSignal, g_mTimeSync, g_mPositioning, g_mLogs;

    template <typename T>
    mutex_type& getMutex()
    {
        if constexpr (std::is_same_v<T, TobiiMex::gaze>)
            return g_mSamp;
        if constexpr (std::is_same_v<T, TobiiMex::eyeImage>)
            return g_mEyeImage;
        if constexpr (std::is_same_v<T, TobiiMex::extSignal>)
            return g_mExtSignal;
        if constexpr (std::is_same_v<T, TobiiMex::timeSync>)
            return g_mTimeSync;
        if constexpr (std::is_same_v<T, TobiiMex::positioning>)
            return g_mPositioning;
        if constexpr (std::is_same_v<T, TobiiMex::logMessage>)
            return g_mLogs;
        if constexpr (std::is_same_v<T, TobiiMex::streamError>)
            return g_mLogs;
    }

    template <typename T>
    read_lock  lockForReading() { return  read_lock(getMutex<T>()); }
    template <typename T>
    write_lock lockForWriting() { return write_lock(getMutex<T>()); }

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
        constexpr TobiiMex::BufferSide  consumeSide  = TobiiMex::BufferSide::Start;
        constexpr size_t                consumeNSamp              = -1;           // this overflows on purpose, consume all samples is default
        constexpr int64_t               consumeTimeRangeStart     = 0;
        constexpr int64_t               consumeTimeRangeEnd       = std::numeric_limits<int64_t>::max();
        constexpr TobiiMex::BufferSide  peekSide     = TobiiMex::BufferSide::End;
        constexpr size_t                peekNSamp                 = 1;
        constexpr int64_t               peekTimeRangeStart        = 0;
        constexpr int64_t               peekTimeRangeEnd          = std::numeric_limits<int64_t>::max();

        constexpr size_t                logBufSize                = 2<<8;
        constexpr bool                  logBufClear               = true;
    }

    // Map string to a Data Stream
    const std::map<std::string, TobiiMex::DataStream> dataStreamMap =
    {
        { "gaze",           TobiiMex::DataStream::Gaze },
        { "eyeImage",       TobiiMex::DataStream::EyeImage },
        { "externalSignal", TobiiMex::DataStream::ExtSignal },
        { "timeSync",       TobiiMex::DataStream::TimeSync },
        { "positioning",    TobiiMex::DataStream::Positioning }
    };

    // Map string to a Sample Side
    const std::map<std::string, TobiiMex::BufferSide> bufferSideMap =
    {
        { "start",          TobiiMex::BufferSide::Start },
        { "end",            TobiiMex::BufferSide::End }
    };

    std::unique_ptr<std::vector<TobiiMex*>> g_allInstances = std::make_unique<std::vector<TobiiMex*>>();
}

TobiiMex::DataStream TobiiMex::stringToDataStream(std::string stream_)
{
    auto it = dataStreamMap.find(stream_);
    if (it == dataStreamMap.end())
    {
        std::stringstream os;
        os << R"(Titta: Requested stream ")" << stream_ << R"(" is not recognized. Supported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning")";
        DoExitWithMsg(os.str());
    }
    return it->second;
}

std::string TobiiMex::dataStreamToString(TobiiMex::DataStream stream_)
{
    auto v = *find_if(dataStreamMap.begin(), dataStreamMap.end(), [&stream_](auto p) {return p.second == stream_;});
    return v.first;
}

TobiiMex::BufferSide TobiiMex::stringToBufferSide(std::string bufferSide_)
{
    auto it = bufferSideMap.find(bufferSide_);
    if (it == bufferSideMap.end())
    {
        std::stringstream os;
        os << R"("Titta: Requested buffer side ")" << bufferSide_ << R"(" is not recognized. Supported sample sides are: "first" and "last")";
        DoExitWithMsg(os.str());
    }
    return it->second;
}

std::string TobiiMex::bufferSideToString(TobiiMex::BufferSide bufferSide_)
{
    auto v = *find_if(bufferSideMap.begin(), bufferSideMap.end(), [&bufferSide_](auto p) {return p.second == bufferSide_;});
    return v.first;
}

// callbacks
void TobiiGazeCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiMex::gaze>();
        static_cast<TobiiMex*>(user_data)->_gaze.push_back(*gaze_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiMex::eyeImage>();
        static_cast<TobiiMex*>(user_data)->_eyeImages.emplace_back(eye_image_);
    }
}
void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiMex::eyeImage>();
        static_cast<TobiiMex*>(user_data)->_eyeImages.emplace_back(eye_image_);
    }
}
void TobiiExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiMex::extSignal>();
        static_cast<TobiiMex*>(user_data)->_extSignal.push_back(*ext_signal_);
    }
}
void TobiiTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiMex::timeSync>();
        static_cast<TobiiMex*>(user_data)->_timeSync.push_back(*time_sync_data_);
    }
}
void TobiiPositioningCallback(TobiiResearchUserPositionGuide* position_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiMex::positioning>();
        static_cast<TobiiMex*>(user_data)->_positioning.push_back(*position_data_);
    }
}
void TobiiLogCallback(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_)
{
    if (TobiiMex::_logMessages)
    {
        auto l = lockForWriting<TobiiMex::logMessage>();
        TobiiMex::_logMessages->emplace_back(TobiiMex::logMessage(system_time_stamp_, source_, level_, message_));
    }
}
void TobiiStreamErrorCallback(TobiiResearchStreamErrorData* errorData_, void* user_data)
{
    if (TobiiMex::_logMessages && errorData_)
    {
        std::string serial;
        if (user_data)
        {
            char* serial_number;
            tobii_research_get_serial_number(static_cast<TobiiResearchEyeTracker*>(user_data), &serial_number);
            serial = serial_number;
            tobii_research_free_string(serial_number);
        }
        auto l = lockForWriting<TobiiMex::streamError>();
        TobiiMex::_logMessages->emplace_back(TobiiMex::streamError(serial,errorData_->system_time_stamp, errorData_->error, errorData_->source, errorData_->message));
    }
}

// info getter static functions
TobiiResearchSDKVersion TobiiMex::getSDKVersion()
{
    TobiiResearchSDKVersion sdk_version;
    TobiiResearchStatus status = tobii_research_get_sdk_version(&sdk_version);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get Tobii SDK version", status);
    return sdk_version;
}
int64_t TobiiMex::getSystemTimestamp()
{
    int64_t system_time_stamp;
    TobiiResearchStatus status = tobii_research_get_system_time_stamp(&system_time_stamp);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get Tobii SDK system time", status);
    return system_time_stamp;
}
std::vector<TobiiTypes::eyeTracker> TobiiMex::findAllEyeTrackers()
{
    TobiiResearchEyeTrackers* tobiiTrackers = nullptr;
    TobiiResearchStatus status = tobii_research_find_all_eyetrackers(&tobiiTrackers);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get eye trackers", status);
    std::vector<TobiiTypes::eyeTracker> eyeTrackers;

    eyeTrackers.insert(eyeTrackers.end(), &tobiiTrackers->eyetrackers[0], &tobiiTrackers->eyetrackers[tobiiTrackers->count]);   // yes, pointer to one past last element
    tobii_research_free_eyetrackers(tobiiTrackers);

    return eyeTrackers;
}

// logging static functions
bool TobiiMex::startLogging(std::optional<size_t> initialBufferSize_)
{
    if (!_logMessages)
        _logMessages = std::make_unique<std::vector<allLogTypes>>();

    // deal with default arguments
    auto initialBufferSize = initialBufferSize_.value_or(defaults::logBufSize);

    auto l = lockForWriting<logMessage>();
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
std::vector<TobiiMex::allLogTypes> TobiiMex::getLog(std::optional<bool> clearLog_)
{
    if (!_logMessages)
        return {};

    // deal with default arguments
    auto clearLog = clearLog_.value_or(defaults::logBufClear);

    auto l = lockForWriting<logMessage>();
    if (clearLog)
        return std::vector<allLogTypes>(std::move(*_logMessages));
    else
        // provide a copy
        return std::vector<allLogTypes>(*_logMessages);
}
bool TobiiMex::stopLogging()
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
    TobiiResearchStatus doSubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, TobiiMex* instance_, bool asGif_)
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




TobiiMex::TobiiMex(std::string address_)
{
    TobiiResearchEyeTracker* et;
    TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(),&et);
    if (status != TOBII_RESEARCH_STATUS_OK)
    {
        std::stringstream os;
        os << "Cannot get eye tracker \"" << address_ << "\"";
        ErrorExit(os.str(), status);
    }
    _eyetracker = TobiiTypes::eyeTracker(et);
    Init();
}
TobiiMex::TobiiMex(TobiiResearchEyeTracker* et_)
{
    _eyetracker = TobiiTypes::eyeTracker(et_);
    Init();
}
TobiiMex::~TobiiMex()
{
    stop(DataStream::Gaze,        true);
    stop(DataStream::EyeImage,    true);
    stop(DataStream::ExtSignal,   true);
    stop(DataStream::TimeSync,    true);
    stop(DataStream::Positioning, true);

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
void TobiiMex::Init()
{
    if (_isLogging)
    {
        // log version of SDK dll that is being used
        if (TobiiMex::_logMessages)
        {
            TobiiResearchSDKVersion version;
            tobii_research_get_sdk_version(&version);
            std::stringstream os;
            os << "Using C SDK version: " << version.major << "." << version.minor << "." << version.revision << "." << version.build;
            auto l = lockForWriting<TobiiMex::logMessage>();
            TobiiMex::_logMessages->emplace_back(TobiiMex::logMessage(0, TOBII_RESEARCH_LOG_SOURCE_SDK, TOBII_RESEARCH_LOG_LEVEL_INFORMATION, os.str()));
        }

        // start stream error logging
        tobii_research_subscribe_to_stream_errors(_eyetracker.et, TobiiStreamErrorCallback, _eyetracker.et);
    }
    if (g_allInstances)
        g_allInstances->push_back(this);
}

// getters and setters
const TobiiTypes::eyeTracker TobiiMex::getEyeTrackerInfo(std::optional<std::string> paramToRefresh_ /*= std::nullopt*/)
{
    // refresh ET info to make sure its up to date
    _eyetracker.refreshInfo(paramToRefresh_);

    return _eyetracker;
}
const float TobiiMex::getFrequency() const
{
    float gaze_output_frequency;
    TobiiResearchStatus status = tobii_research_get_gaze_output_frequency(_eyetracker.et, &gaze_output_frequency);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get eye tracker current frequency", status);
    return gaze_output_frequency;
}
const std::string TobiiMex::getTrackingMode() const
{
    char* eye_tracking_mode;
    TobiiResearchStatus status = tobii_research_get_eye_tracking_mode(_eyetracker.et, &eye_tracking_mode);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get eye tracker current tracking mode", status);

    std::string etMode(eye_tracking_mode);
    tobii_research_free_string(eye_tracking_mode);
    return etMode;
}
const TobiiResearchTrackBox TobiiMex::getTrackBox() const
{
    TobiiResearchTrackBox track_box;
    TobiiResearchStatus status = tobii_research_get_track_box(_eyetracker.et, &track_box);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get eye tracker track box", status);
    return track_box;
}
const TobiiResearchDisplayArea TobiiMex::getDisplayArea() const
{
    TobiiResearchDisplayArea display_area;
    TobiiResearchStatus status = tobii_research_get_display_area(_eyetracker.et, &display_area);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get eye tracker display area", status);
    return display_area;
}
// setters
void TobiiMex::setFrequency(float frequency_)
{
    TobiiResearchStatus status = tobii_research_set_gaze_output_frequency(_eyetracker.et, frequency_);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot set eye tracker frequency", status);
}
void TobiiMex::setTrackingMode(std::string trackingMode_)
{
    TobiiResearchStatus status = tobii_research_set_eye_tracking_mode(_eyetracker.et, trackingMode_.c_str());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot set eye tracker tracking mode", status);
}
void TobiiMex::setDeviceName(std::string deviceName_)
{
    TobiiResearchStatus status = tobii_research_set_device_name(_eyetracker.et, deviceName_.c_str());
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot set eye tracker device name", status);

    // refresh eye tracker info to get updated name
    _eyetracker.refreshInfo();
}
// modifiers
std::vector<TobiiResearchLicenseValidationResult> TobiiMex::applyLicenses(std::vector<std::vector<uint8_t>> licenses_)
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
        ErrorExit("Cannot apply eye tracker license(s)", status);

    // refresh eye tracker info, e.g. capabilities may have changed after license applied
    _eyetracker.refreshInfo();

    return validationResults;
}
void TobiiMex::clearLicenses()
{
    TobiiResearchStatus status = tobii_research_clear_applied_licenses(_eyetracker.et);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot clear eye tracker license(s)", status);

    // refresh eye tracker info, e.g. capabilities may have changed after licenses removed
    _eyetracker.refreshInfo();
}

//// calibration
void TobiiMex::calibrationThread()
{
    bool keepRunning            = true;
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
            if (_calibrationIsMonocular)
            {
                TobiiResearchSelectedEye collectEye=TOBII_RESEARCH_SELECTED_EYE_LEFT, ignore;
                if (workItem.eye == "right")
                    collectEye = TOBII_RESEARCH_SELECTED_EYE_RIGHT;
                result = tobii_research_screen_based_monocular_calibration_collect_data(_eyetracker.et, static_cast<float>(workItem.coordinates[0]), static_cast<float>(workItem.coordinates[1]), collectEye, &ignore);
            }
            else
                result = tobii_research_screen_based_calibration_collect_data(_eyetracker.et, static_cast<float>(workItem.coordinates[0]), static_cast<float>(workItem.coordinates[1]));

            _calibrationWorkResultQueue.enqueue({workItem, result});

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::DiscardData:
        {
            // discard calibration data for a specific point
            _calibrationState = TobiiTypes::CalibrationState::DiscardingData;
            if (_calibrationIsMonocular)
            {
                TobiiResearchSelectedEye discardEye = TOBII_RESEARCH_SELECTED_EYE_LEFT;
                if (workItem.eye == "right")
                    discardEye = TOBII_RESEARCH_SELECTED_EYE_RIGHT;
                result = tobii_research_screen_based_monocular_calibration_discard_data(_eyetracker.et, static_cast<float>(workItem.coordinates[0]), static_cast<float>(workItem.coordinates[1]), discardEye);
            }
            else
                result = tobii_research_screen_based_calibration_discard_data(_eyetracker.et, static_cast<float>(workItem.coordinates[0]), static_cast<float>(workItem.coordinates[1]));

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

            TobiiTypes::CalibrationWorkResult workResult{workItem, result};
            if (computeResult)
                workResult.calibrationResult = {computeResult,tobii_research_free_screen_based_calibration_result};
            _calibrationWorkResultQueue.enqueue(std::move(workResult));

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
                workResult.calibrationData = {calData,tobii_research_free_calibration_data};
            _calibrationWorkResultQueue.enqueue(std::move(workResult));

            _calibrationState = TobiiTypes::CalibrationState::AwaitingCalPoint;
            break;
        }
        case TobiiTypes::CalibrationAction::ApplyCalibrationData:
        {
            _calibrationState = TobiiTypes::CalibrationState::ApplyingCalibrationData;
            if (!workItem.calData.empty())
            {
                TobiiResearchCalibrationData calData;
                // copy calibration data into array
                auto nItem = workItem.calData.size();
                calData.data = malloc(nItem);
                calData.size = nItem;
                if (nItem)
                    std::memcpy(calData.data, &workItem.calData[0], nItem);

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
void TobiiMex::enterCalibrationMode(bool doMonocular_)
{
    if (_calibrationThread.joinable())
    {
        DoExitWithMsg("enterCalibrationMode: Calibration mode already entered");
    }

    _calibrationIsMonocular = doMonocular_;

    // start new calibration worker
    // this calls tobii_research_screen_based_calibration_enter_calibration_mode() in the thread function
    _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::Enter});
    _calibrationState   = TobiiTypes::CalibrationState::NotYetEntered;
    _calibrationThread  = std::thread(&TobiiMex::calibrationThread, this);
}
void TobiiMex::leaveCalibrationMode(bool force_)
{
    if (force_)
    {
        // call leave calibration mode on Tobii SDK, ignore error
        // this is provided as user code may need to ensure we're not in
        // calibration mode, e.g. after a previous crash
        tobii_research_screen_based_calibration_leave_calibration_mode(_eyetracker.et);
    }

    if (_calibrationThread.joinable())
    {
        // tell thread to quit and wait until it quits
        // this calls tobii_research_screen_based_calibration_leave_calibration_mode() in the thread function before exiting
        _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::Exit});
        if (_calibrationThread.joinable())
            _calibrationThread.join();
    }

    _calibrationState = TobiiTypes::CalibrationState::NotYetEntered;
}
void addCoordsEyeToWorkItem(TobiiTypes::CalibrationWorkItem& workItem, std::array<double, 2> coordinates_, std::optional<std::string> eye_)
{
    workItem.coordinates = {coordinates_.begin(),coordinates_.end()};
    if (eye_)
    {
        workItem.eye = *eye_;
        if (workItem.eye != "left" && workItem.eye != "right")
        {
            std::stringstream os;
            os << "calibrationCollectData: Cannot start calibration for eye " << workItem.eye << ", unknown. Expected left or right.";
            DoExitWithMsg(os.str());
        }
    }
}
void TobiiMex::calibrationCollectData(std::array<double, 2> coordinates_, std::optional<std::string> eye_)
{
    if (!_calibrationThread.joinable())
    {
        DoExitWithMsg("calibrationCollectData: you have not entered calibration mode, call enterCalibrationMode first");
    }

    TobiiTypes::CalibrationWorkItem workItem{TobiiTypes::CalibrationAction::CollectData};
    addCoordsEyeToWorkItem(workItem, coordinates_, eye_);
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
void TobiiMex::calibrationDiscardData(std::array<double, 2> coordinates_, std::optional<std::string> eye_)
{
    if (!_calibrationThread.joinable())
    {
        DoExitWithMsg("calibrationDiscardData: you have not entered calibration mode, call enterCalibrationMode first");
    }

    TobiiTypes::CalibrationWorkItem workItem{ TobiiTypes::CalibrationAction::DiscardData };
    addCoordsEyeToWorkItem(workItem, coordinates_, eye_);
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
void TobiiMex::calibrationComputeAndApply()
{
    if (!_calibrationThread.joinable())
    {
        DoExitWithMsg("calibrationComputeAndApply: you have not entered calibration mode, call enterCalibrationMode first");
    }

    _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::Compute});
}
void TobiiMex::calibrationGetData()
{
    if (!_calibrationThread.joinable())
    {
        DoExitWithMsg("calibrationGetData: you have not entered calibration mode, call enterCalibrationMode first");
    }

    _calibrationWorkQueue.enqueue({TobiiTypes::CalibrationAction::GetCalibrationData});
}
void TobiiMex::calibrationApplyData(std::vector<uint8_t> calData_)
{
    if (!_calibrationThread.joinable())
    {
        DoExitWithMsg("calibrationApplyData: you have not entered calibration mode, call enterCalibrationMode first");
    }

    TobiiTypes::CalibrationWorkItem workItem{TobiiTypes::CalibrationAction::ApplyCalibrationData};
    workItem.calData = calData_;
    _calibrationWorkQueue.enqueue(std::move(workItem));
}
TobiiTypes::CalibrationState TobiiMex::calibrationGetStatus()
{
    return _calibrationState;
}
std::optional<TobiiTypes::CalibrationWorkResult> TobiiMex::calibrationRetrieveResult(bool makeString /*= false*/)
{
    TobiiTypes::CalibrationWorkResult out;
    if (_calibrationWorkResultQueue.try_dequeue(out))
    {
        if (makeString)
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
std::vector<T>& TobiiMex::getBuffer()
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
}
template <typename T>
std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator>
TobiiMex::getIteratorsFromSampleAndSide(size_t NSamp_, TobiiMex::BufferSide side_)
{
    auto& buf    = getBuffer<T>();
    auto startIt = std::begin(buf);
    auto   endIt = std::end(buf);
    auto nSamp   = std::min(NSamp_, std::size(buf));

    switch (side_)
    {
    case TobiiMex::BufferSide::Start:
        endIt   = std::next(startIt, nSamp);
        break;
    case TobiiMex::BufferSide::End:
        startIt = std::prev(endIt  , nSamp);
        break;
    default:
        DoExitWithMsg("Titta: Mex: getIteratorsFromSampleAndSide: unknown TobiiMex::BufferSide provided.");
        break;
    }
    return { startIt, endIt };
}

template <typename T>
std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator, bool>
TobiiMex::getIteratorsFromTimeRange(int64_t timeStart_, int64_t timeEnd_)
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


bool TobiiMex::hasStream(std::string stream_) const
{
    return hasStream(stringToDataStream(stream_));
}
bool TobiiMex::hasStream(DataStream  stream_) const
{
    bool supported = false;
    switch (stream_)
    {
        case DataStream::Gaze:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA;
        case DataStream::EyeImage:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES;
        case DataStream::ExtSignal:
            return _eyetracker.capabilities & TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL;
        case DataStream::TimeSync:
            return true;    // no capability that can be checked for this one
        case DataStream::Positioning:
            return true;    // no capability that can be checked for this one
    }

    return supported;
}

bool TobiiMex::start(std::string stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
{
    return start(stringToDataStream(stream_), initialBufferSize_, asGif_);
}
bool TobiiMex::start(DataStream  stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
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
                // prepare and start buffer
                auto l = lockForWriting<gaze>();
                _gaze.reserve(initialBufferSize);
                result = tobii_research_subscribe_to_gaze_data(_eyetracker.et, TobiiGazeCallback, this);
                stateVar = &_recordingGaze;
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
                auto l = lockForWriting<eyeImage>();
                _eyeImages.reserve(initialBufferSize);

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
                auto l = lockForWriting<extSignal>();
                _extSignal.reserve(initialBufferSize);
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
                auto l = lockForWriting<timeSync>();
                _timeSync.reserve(initialBufferSize);
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
                auto l = lockForWriting<positioning>();
                _positioning.reserve(initialBufferSize);
                result = tobii_research_subscribe_to_user_position_guide(_eyetracker.et, TobiiPositioningCallback, this);
                stateVar = &_recordingPositioning;
            }
            break;
        }
    }

    if (stateVar)
        *stateVar = result==TOBII_RESEARCH_STATUS_OK;

    if (result != TOBII_RESEARCH_STATUS_OK)
    {
        std::stringstream os;
        os << "Cannot start recording " << dataStreamToString(stream_) << " stream";
        ErrorExit(os.str(), result);
    }

    return result == TOBII_RESEARCH_STATUS_OK;
}

bool TobiiMex::isRecording(std::string stream_) const
{
    return isRecording(stringToDataStream(stream_));
}
bool TobiiMex::isRecording(DataStream  stream_) const
{
    bool success = false;
    switch (stream_)
    {
        case DataStream::Gaze:
            return _recordingGaze;
        case DataStream::EyeImage:
            return _recordingEyeImages;
        case DataStream::ExtSignal:
            return _recordingExtSignal;
        case DataStream::TimeSync:
            return _recordingTimeSync;
        case DataStream::Positioning:
            return _recordingPositioning;
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
std::vector<T> TobiiMex::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_)
{
    // deal with default arguments
    auto N      = NSamp_.value_or(defaults::consumeNSamp);
    auto side   = side_.value_or(defaults::consumeSide);

    auto l = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf    = getBuffer<T>();

    auto [startIt, endIt] = getIteratorsFromSampleAndSide<T>(N, side);
    return consumeFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> TobiiMex::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    auto timeStart = timeStart_.value_or(defaults::consumeTimeRangeStart);
    auto timeEnd   = timeEnd_  .value_or(defaults::consumeTimeRangeEnd);

    auto l = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer<T>();

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
std::vector<T> TobiiMex::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_)
{
    // deal with default arguments
    auto N      = NSamp_.value_or(defaults::peekNSamp);
    auto side   = side_.value_or(defaults::peekSide);

    auto l = lockForReading<T>();
    auto& buf = getBuffer<T>();

    auto [startIt, endIt] = getIteratorsFromSampleAndSide<T>(N, side);
    return peekFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> TobiiMex::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    auto timeStart = timeStart_.value_or(defaults::peekTimeRangeStart);
    auto timeEnd   = timeEnd_  .value_or(defaults::peekTimeRangeEnd);

    auto l = lockForReading<T>();
    auto& buf = getBuffer<T>();

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<T>(timeStart, timeEnd);
    return peekFromVec(buf, startIt, endIt);
}

template <typename T>
void TobiiMex::clearImpl(int64_t timeStart_, int64_t timeEnd_)
{
    auto l = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer<T>();
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
void TobiiMex::clear(std::string stream_)
{
    clear(stringToDataStream(stream_));
}
void TobiiMex::clear(DataStream stream_)
{
    if (stream_ == DataStream::Positioning)
    {
        auto l = lockForWriting<positioning>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
        auto& buf = getBuffer<positioning>();
        if (std::empty(buf))
            return;
        buf.clear();
    }
    else
        clearTimeRange(stream_);
}
void TobiiMex::clearTimeRange(std::string stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    clearTimeRange(stringToDataStream(stream_), timeStart_, timeEnd_);
}
void TobiiMex::clearTimeRange(DataStream stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    auto timeStart = timeStart_.value_or(defaults::clearTimeRangeStart);
    auto timeEnd   = timeEnd_  .value_or(defaults::clearTimeRangeEnd);

    switch (stream_)
    {
        case DataStream::Gaze:
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
            DoExitWithMsg("clearTimeRange: not supported for the positioning stream.");
            break;
    }
}

bool TobiiMex::stop(std::string stream_, std::optional<bool> clearBuffer_)
{
    return stop(stringToDataStream(stream_), clearBuffer_);
}

bool TobiiMex::stop(DataStream  stream_, std::optional<bool> clearBuffer_)
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
    }

    if (clearBuffer)
        clear(stream_);

    bool success = result == TOBII_RESEARCH_STATUS_OK;
    if (stateVar && success)
        *stateVar = false;

    return success;
}

// gaze data, instantiate templated functions
template std::vector<TobiiMex::gaze> TobiiMex::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::gaze> TobiiMex::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiMex::gaze> TobiiMex::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::gaze> TobiiMex::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// eye images, instantiate templated functions
template std::vector<TobiiMex::eyeImage> TobiiMex::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::eyeImage> TobiiMex::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiMex::eyeImage> TobiiMex::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::eyeImage> TobiiMex::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// external signals, instantiate templated functions
template std::vector<TobiiMex::extSignal> TobiiMex::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::extSignal> TobiiMex::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiMex::extSignal> TobiiMex::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::extSignal> TobiiMex::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// time sync data, instantiate templated functions
template std::vector<TobiiMex::timeSync> TobiiMex::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::timeSync> TobiiMex::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiMex::timeSync> TobiiMex::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
template std::vector<TobiiMex::timeSync> TobiiMex::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// positioning data, instantiate templated functions
// NB: positioning data does not have timestamps, so the Time Range version of the below functions are not defined for the positioning stream
template std::vector<TobiiMex::positioning> TobiiMex::consumeN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
//template std::vector<TobiiMex::positioning> TobiiMex::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiMex::positioning> TobiiMex::peekN(std::optional<size_t> NSamp_, std::optional<BufferSide> side_);
//template std::vector<TobiiMex::positioning> TobiiMex::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
