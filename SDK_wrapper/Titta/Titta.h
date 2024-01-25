#pragma once
#include <vector>
#include <deque>
#include <array>
#include <string>
#include <tuple>
#include <optional>
#include <thread>
#include <atomic>
#include <variant>
#include <tobii_research.h>
#include <tobii_research_eyetracker.h>
#include <tobii_research_streams.h>
#pragma comment(lib, "tobii_research.lib")
#ifndef BUILD_FROM_SCRIPT
#   ifdef _DEBUG
#       pragma comment(lib, "Titta_d.lib")
#   else
#       pragma comment(lib, "Titta.lib")
#   endif
#endif
#include <readerwriterqueue/readerwriterqueue.h>

#include "types.h"


class Titta
{
public:
    using gaze          = TobiiTypes::gazeData;
    using eyeImage      = TobiiTypes::eyeImage;
    using extSignal     = TobiiResearchExternalSignalData;
    using timeSync      = TobiiResearchTimeSynchronizationData;
    using positioning   = TobiiResearchUserPositionGuide;
    using logMessage    = TobiiTypes::logMessage;
    using streamError   = TobiiTypes::streamErrorMessage;
    using notification  = TobiiTypes::notification;
    using allLogTypes   = std::variant<logMessage, streamError>;

    // data stream type (NB: not log, as that isn't a class member)
    enum class Stream
    {
        Unknown,
        Gaze,
        EyeOpenness,
        EyeImage,
        ExtSignal,
        TimeSync,
        Positioning,
        Notification,
        Last            // fake value for iteration
    };
    // "gaze", "eyeOpenness", "eyeImage", "externalSignal", "timeSync", "positioning", or "notification"
    static Titta::Stream stringToStream(std::string stream_, bool snake_case_on_stream_not_found = false, bool forLSL_ = false);
    static std::string streamToString(Titta::Stream stream_, bool snakeCase_ = false);      // by default output camelCase, if true, output snake_case
    static std::vector<std::string> getAllStreams(bool snakeCase_ = false, bool forLSL_ = false);
    static std::string getAllStreamsString(const char* quoteChar_ = "\"", bool snakeCase_ = false, bool forLSL_ = false);

    // side of buffer to get samples from
    enum class BufferSide
    {
        Unknown,
        Start,
        End,
        Last            // fake value for iteration
    };
    // "start", or "end"
    static Titta::BufferSide stringToBufferSide(std::string bufferSide_);
    static std::string bufferSideToString(Titta::BufferSide bufferSide_);
    static std::vector<std::string> getAllBufferSides();
    static std::string getAllBufferSidesString(const char* quoteChar_ = "\"");

public:
    Titta(std::string address_);
    Titta(TobiiResearchEyeTracker* et_);
    ~Titta();

    //// global SDK functions
    static TobiiResearchSDKVersion getSDKVersion();
    static int64_t getSystemTimestamp();
    static std::vector<TobiiTypes::eyeTracker> findAllEyeTrackers();
    static TobiiTypes::eyeTracker getEyeTrackerFromAddress(std::string address_);
    // logging
    static bool startLogging(std::optional<size_t> initialBufferSize_ = std::nullopt);
    static std::vector<Titta::allLogTypes> getLog(std::optional<bool> clearLog_ = std::nullopt);
    static bool stopLogging();	// always clears buffer

    //// eye-tracker specific getters and setters
    // getters
    TobiiTypes::eyeTracker getEyeTrackerInfo(std::optional<std::string> paramToRefresh_ = std::nullopt);
    TobiiResearchTrackBox getTrackBox() const;
    TobiiResearchDisplayArea getDisplayArea() const;
    // setters. NB: these trigger a refresh of eye tracker info
    void setDeviceName(std::string deviceName_);
    void setFrequency(float frequency_);
    void setTrackingMode(std::string trackingMode_);
    // modifiers. NB: these trigger a refresh of eye tracker info
    std::vector<TobiiResearchLicenseValidationResult> applyLicenses(std::vector<std::vector<uint8_t>> licenses_);
    void clearLicenses();

    //// calibration
    bool enterCalibrationMode(bool doMonocular_);
    bool isInCalibrationMode(std::optional<bool> issueErrorIfNot_) const;
    bool leaveCalibrationMode(std::optional<bool> force_);
    void calibrationCollectData(std::array<float, 2> coordinates_, std::optional<std::string> eye_);
    void calibrationDiscardData(std::array<float, 2> coordinates_, std::optional<std::string> eye_);
    void calibrationComputeAndApply();
    void calibrationGetData();
    void calibrationApplyData(std::vector<uint8_t> calibrationData_);
    TobiiTypes::CalibrationState calibrationGetStatus();
    std::optional<TobiiTypes::CalibrationWorkResult> calibrationRetrieveResult(bool makeStatusString_ = false);

    //// data streams
    // query if stream is supported
    bool hasStream(std::string stream_, bool snake_case_on_stream_not_found = false) const;
    bool hasStream(Stream      stream_) const;

    // deal with eyeOpenness stream
    bool setIncludeEyeOpennessInGaze(bool include_);    // returns previous state

    // start stream
    bool start(std::string stream_, std::optional<size_t> initialBufferSize_ = std::nullopt, std::optional<bool> asGif_ = std::nullopt, bool snake_case_on_stream_not_found = false);
    bool start(Stream      stream_, std::optional<size_t> initialBufferSize_ = std::nullopt, std::optional<bool> asGif_ = std::nullopt);

    // request stream state
    bool isRecording(std::string stream_, bool snake_case_on_stream_not_found = false) const;
    bool isRecording(Stream      stream_) const;

    // consume samples (by default all)
    template <typename T>
    std::vector<T> consumeN(std::optional<size_t> NSamp_ = std::nullopt, std::optional<BufferSide> side_ = std::nullopt);
    // consume samples within given timestamps (inclusive, by default whole buffer)
    template <typename T>
    std::vector<T> consumeTimeRange(std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // peek samples (by default only last one, can specify how many to peek, and from which side of buffer)
    template <typename T>
    std::vector<T> peekN(std::optional<size_t> NSamp_ = std::nullopt, std::optional<BufferSide> side_ = std::nullopt);
    // peek samples within given timestamps (inclusive, by default whole buffer)
    template <typename T>
    std::vector<T> peekTimeRange(std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // clear all buffer contents
    void clear(std::string stream_, bool snake_case_on_stream_not_found = false);
    void clear(Stream      stream_);
    // clear contents buffer within given timestamps (inclusive, by default whole buffer)
    void clearTimeRange(std::string stream_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt, bool snake_case_on_stream_not_found = false);
    void clearTimeRange(Stream      stream_, std::optional<int64_t> timeStart_ = std::nullopt, std::optional<int64_t> timeEnd_ = std::nullopt);

    // stop, optionally deletes the buffer
    bool stop(std::string stream_, std::optional<bool> clearBuffer_ = std::nullopt, bool snake_case_on_stream_not_found = false);
    bool stop(Stream      stream_, std::optional<bool> clearBuffer_ = std::nullopt);

private:
    void Init();
    // Tobii callbacks need to be friends
    friend void TittaGazeCallback       (TobiiResearchGazeData*                     gaze_data_, void* user_data_);
    friend void TittaEyeOpennessCallback(TobiiResearchEyeOpennessData*          openness_data_, void* user_data_);
    friend void TittaEyeImageCallback   (TobiiResearchEyeImage*                     eye_image_, void* user_data_);
    friend void TittaEyeImageGifCallback(TobiiResearchEyeImageGif*                  eye_image_, void* user_data_);
    friend void TittaExtSignalCallback  (TobiiResearchExternalSignalData*          ext_signal_, void* user_data_);
    friend void TittaTimeSyncCallback   (TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data_);
    friend void TittaPositioningCallback(TobiiResearchUserPositionGuide*        position_data_, void* user_data_);
    friend void TittaLogCallback        (int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_);
    friend void TittaStreamErrorCallback(TobiiResearchStreamErrorData*              errorData_, void* user_data_);
    friend void TittaNotificationCallback(TobiiResearchNotification*             notification_, void* user_data_);
    // calibration
    void calibrationThread();
    // gaze + eye openness receiver
    void receiveSample(const TobiiResearchGazeData* gaze_data_, const TobiiResearchEyeOpennessData* openness_data_);
    //// generic functions for internal use
    // helpers
    template <typename T>  mutex_type&      getMutex();
    template <typename T>  read_lock        lockForReading();
    template <typename T>  write_lock       lockForWriting();
    template <typename T>  std::vector<T>&  getBuffer();
    template <typename T>
                           std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator>
                                            getIteratorsFromSampleAndSide(size_t NSamp_, BufferSide side_);
    template <typename T>
                           std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator, bool>
                                            getIteratorsFromTimeRange(int64_t timeStart_, int64_t timeEnd_);
    // generic implementations
    template <typename T>  void             clearImpl(int64_t timeStart_, int64_t timeEnd_);

private:
    TobiiTypes::eyeTracker      _eyeTracker;

    bool                        _recordingGaze          = false;
    bool                        _recordingEyeOpenness   = false;
    bool                        _includeEyeOpennessInGaze = false;
    std::vector<gaze>           _gaze;
    mutex_type                  _gazeMutex;
    // staging area to merge gaze and eye openness
    std::deque<gaze>            _gazeStaging;
    std::atomic<bool>           _gazeStagingEmpty       = true;
    mutex_type                  _gazeStageMutex;

    bool                        _recordingEyeImages     = false;
    std::vector<eyeImage>       _eyeImages;
    bool                        _eyeImIsGif             = false;
    mutex_type                  _eyeImagesMutex;

    bool                        _recordingExtSignal     = false;
    std::vector<extSignal>      _extSignal;
    mutex_type                  _extSignalMutex;

    bool                        _recordingTimeSync      = false;
    std::vector<timeSync>       _timeSync;
    mutex_type                  _timeSyncMutex;

    bool                        _recordingPositioning   = false;
    std::vector<positioning>    _positioning;
    mutex_type                  _positioningMutex;

    bool                        _recordingNotification  = false;
    std::vector<notification>   _notification;
    mutex_type                  _notificationMutex;

    static inline bool          _isLogging              = false;
    static inline std::unique_ptr<
        std::vector<allLogTypes>> _logMessages          = nullptr;
    static inline mutex_type    _logsMutex;

    // calibration
    bool                                        _calibrationIsMonocular = false;
    std::thread                                 _calibrationThread;
    moodycamel::BlockingReaderWriterQueue<TobiiTypes::CalibrationWorkItem>   _calibrationWorkQueue;
    moodycamel::BlockingReaderWriterQueue<TobiiTypes::CalibrationWorkResult> _calibrationWorkResultQueue;
    std::atomic<TobiiTypes::CalibrationState>   _calibrationState;
};
