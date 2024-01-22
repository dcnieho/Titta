#pragma once
#include <string>
#include <memory>
#include <array>
#include <vector>
#include <cstring>
#include <optional>
#include <mutex>
#include <shared_mutex>
#include <limits>

#include <tobii_research_streams.h>
#include <tobii_research_calibration.h>

using mutex_type = std::shared_mutex;
using read_lock  = std::shared_lock<mutex_type>;
using write_lock = std::unique_lock<mutex_type>;

namespace TobiiTypes
{
    class eyeTracker
    {
    public:
        eyeTracker() = default;
        eyeTracker(TobiiResearchEyeTracker* et_);
        eyeTracker(std::string deviceName_, std::string serialNumber_, std::string model_, std::string firmwareVersion_, std::string runtimeVersion_, std::string address_,
            float frequency_, std::string trackingMode_, TobiiResearchCapabilities capabilities_, std::vector<float> supportedFrequencies_, std::vector<std::string> supportedModes_);

        void refreshInfo(std::optional<std::string> paramToRefresh_ = std::nullopt);

    public:
        TobiiResearchEyeTracker*    et = nullptr;
        std::string                 deviceName, serialNumber, model, firmwareVersion, runtimeVersion, address;
        float                       frequency = 0.f;
        std::string                 trackingMode;
        TobiiResearchCapabilities   capabilities = TOBII_RESEARCH_CAPABILITIES_NONE;
        std::vector<float>          supportedFrequencies;
        std::vector<std::string>    supportedModes;
    };

    // extended gaze data (for merging gaze and eye openness
    struct gazeOrigin
    {
        // The gaze origin position in 3D in the user coordinate system.
        TobiiResearchPoint3D position_in_user_coordinates = { std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN() };

        // The normalized gaze origin position in 3D in the track box coordinate system.
        TobiiResearchNormalizedPoint3D position_in_track_box_coordinates = { std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN() };

        // The validity of the gaze origin data.
        TobiiResearchValidity validity = TOBII_RESEARCH_VALIDITY_INVALID;

        bool available = false;
    };

    struct pupilData
    {
        // The diameter of the pupil in millimeters.
        float diameter = std::numeric_limits<float>::quiet_NaN();

        // The validity of the pupil data.
        TobiiResearchValidity validity = TOBII_RESEARCH_VALIDITY_INVALID;

        bool available = false;
    };

    struct gazePoint
    {
        // The gaze point position in 2D on the active display area.
        TobiiResearchNormalizedPoint2D position_on_display_area = { std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN() };

        // The gaze point position in 3D in the user coordinate system.
        TobiiResearchPoint3D position_in_user_coordinates = { std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::quiet_NaN() };

        // The validity of the gaze point data.
        TobiiResearchValidity validity = TOBII_RESEARCH_VALIDITY_INVALID;

        bool available = false;
    };

    struct eyeOpenness
    {
        // The value of the right absolute eye openness.
        float diameter = std::numeric_limits<float>::quiet_NaN();

        // The validity of the eye openness data.
        TobiiResearchValidity validity = TOBII_RESEARCH_VALIDITY_INVALID;

        bool available = false;
    };

    struct eyeData
    {
        // The gaze point data.
        gazePoint   gaze_point;

        // The pupil data.
        pupilData   pupil;

        // The gaze origin data.
        gazeOrigin  gaze_origin;

        // The eye openness data.
        eyeOpenness eye_openness;
    };

    struct gazeData
    {
        // The gaze data for the left eye.
        eyeData left_eye;

        // The gaze data for the right eye.
        eyeData right_eye;

        // The time stamp according to the eye tracker's internal clock.
        int64_t device_time_stamp;

        // The time stamp according to the computer's internal clock.
        int64_t system_time_stamp;
    };

    // My own almost POD class for Tobii eye images, for safe resource management
    // of the data heap array member
    class eyeImage
    {
    public:
        eyeImage() :
            is_gif(false),
            device_time_stamp(0),
            system_time_stamp(0),
            bits_per_pixel(0),
            padding_per_pixel(0),
            width(0),
            height(0),
            region_id(0),
            region_top(0),
            region_left(0),
            type(TOBII_RESEARCH_EYE_IMAGE_TYPE_UNKNOWN),
            camera_id(0),
            data_size(0),
            _eyeIm({nullptr,std::free})
        {}
        eyeImage(const TobiiResearchEyeImage* e_) :
            is_gif(false),
            device_time_stamp(e_->device_time_stamp),
            system_time_stamp(e_->system_time_stamp),
            bits_per_pixel(e_->bits_per_pixel),
            padding_per_pixel(e_->padding_per_pixel),
            width(e_->width),
            height(e_->height),
            region_id(e_->region_id),
            region_top(e_->top),
            region_left(e_->left),
            type(e_->type),
            camera_id(e_->camera_id),
            data_size(e_->data_size),
            _eyeIm({malloc(e_->data_size),std::free})
        {
            std::memcpy(_eyeIm.get(), e_->data, e_->data_size);
        }
        eyeImage(const TobiiResearchEyeImageGif* e_) :
            is_gif(true),
            device_time_stamp(e_->device_time_stamp),
            system_time_stamp(e_->system_time_stamp),
            bits_per_pixel(0),
            padding_per_pixel(0),
            width(0),
            height(0),
            region_id(e_->region_id),
            region_top(e_->top),
            region_left(e_->left),
            type(e_->type),
            camera_id(e_->camera_id),
            data_size(e_->image_size),
            _eyeIm({malloc(e_->image_size),std::free})
        {
            std::memcpy(_eyeIm.get(), e_->image_data, e_->image_size);
        }
        eyeImage(eyeImage&&) noexcept = default;
        eyeImage(const eyeImage& other_) :
            is_gif(other_.is_gif),
            device_time_stamp(other_.device_time_stamp),
            system_time_stamp(other_.system_time_stamp),
            bits_per_pixel(other_.bits_per_pixel),
            padding_per_pixel(other_.padding_per_pixel),
            width(other_.width),
            height(other_.height),
            region_id(other_.region_id),
            region_top(other_.region_top),
            region_left(other_.region_left),
            type(other_.type),
            camera_id(other_.camera_id),
            data_size(other_.data_size),
            _eyeIm({malloc(other_.data_size),std::free})
        {
            std::memcpy(_eyeIm.get(), other_.data(), other_.data_size);
        }
        eyeImage& operator= (eyeImage other_)
        {
            swap(*this, other_);
            return *this;
        }
        ~eyeImage() = default;

        // get eye image data
        void* data() const { return _eyeIm.get(); }
        // set eye image data
        void setData(const uint8_t* data_, const size_t nBytes_)
        {
            if (nBytes_)
            {
                _eyeIm.reset(malloc(nBytes_));
                std::memcpy(_eyeIm.get(), data_, nBytes_);
                data_size = nBytes_;
            }
        }

        friend void swap(eyeImage& first_, eyeImage& second_)
        {
            using std::swap;

            swap(first_.is_gif, second_.is_gif);
            swap(first_.device_time_stamp, second_.device_time_stamp);
            swap(first_.system_time_stamp, second_.system_time_stamp);
            swap(first_.bits_per_pixel, second_.bits_per_pixel);
            swap(first_.padding_per_pixel, second_.padding_per_pixel);
            swap(first_.width, second_.width);
            swap(first_.height, second_.height);
            swap(first_.region_id, second_.region_id);
            swap(first_.region_top, second_.region_top);
            swap(first_.region_left, second_.region_left);
            swap(first_.type, second_.type);
            swap(first_.camera_id, second_.camera_id);
            swap(first_.data_size, second_.data_size);
            swap(first_._eyeIm, second_._eyeIm);
        }

    public:
        bool						is_gif;
        int64_t                     device_time_stamp;
        int64_t                     system_time_stamp;
        int                         bits_per_pixel;
        int                         padding_per_pixel;
        int                         width;
        int                         height;
        int                         region_id;
        int                         region_top;
        int                         region_left;
        TobiiResearchEyeImageType   type;
        int                         camera_id;
        size_t                      data_size;
    private:
        std::unique_ptr<void, decltype(std::free)*> _eyeIm;
    };

    // My own almost POD class for Tobii log messages, for safe resource management
    // of the message heap array member
    class logMessage
    {
    public:
        logMessage() = default;
        logMessage(const int64_t system_time_stamp_, const TobiiResearchLogSource source_, const TobiiResearchLogLevel level_, std::string message_) :
            system_time_stamp(system_time_stamp_),
            source(source_),
            level(level_),
            message(std::move(message_))
        {}

    public:
        int64_t                system_time_stamp = 0;
        TobiiResearchLogSource source = TOBII_RESEARCH_LOG_SOURCE_STREAM_ENGINE;
        TobiiResearchLogLevel  level  = TOBII_RESEARCH_LOG_LEVEL_ERROR;
        std::string            message;
    };

    // My own almost POD class for Tobii stream error messages, for safe resource management
    // of the message heap array member
    class streamErrorMessage
    {
    public:
        streamErrorMessage() = default;
        streamErrorMessage(std::string serial_, const int64_t system_time_stamp_, const TobiiResearchStreamError error_, const TobiiResearchStreamErrorSource source_, std::string message_) :
            machine_serial(std::move(serial_)),
            system_time_stamp(system_time_stamp_),
            error(error_),
            source(source_),
            message(std::move(message_))
        {}

    public:
        std::string                     machine_serial;
        int64_t                         system_time_stamp = 0;
        TobiiResearchStreamError        error  = TOBII_RESEARCH_STREAM_ERROR_CONNECTION_LOST;
        TobiiResearchStreamErrorSource  source = TOBII_RESEARCH_STREAM_ERROR_SOURCE_USER;
        std::string                     message;
    };

    // My own almost class for Tobii notifications, for turning the union into something nicer to deal with
    class notification
    {
    public:
        notification() = default;
        notification(const TobiiResearchNotification notification_) :
            system_time_stamp(notification_.system_time_stamp),
            notification_type(notification_.notification_type)
        {
            // fill optional fields, depending on type of notification
            if (notification_type==TOBII_RESEARCH_NOTIFICATION_DEVICE_FAULTS || notification_type==TOBII_RESEARCH_NOTIFICATION_DEVICE_WARNINGS)
                errors_or_warnings = notification_.value.text;
            else if (notification_type==TOBII_RESEARCH_NOTIFICATION_DISPLAY_AREA_CHANGED)
                display_area = notification_.value.display_area;
            else if (notification_type==TOBII_RESEARCH_NOTIFICATION_GAZE_OUTPUT_FREQUENCY_CHANGED)
                output_frequency = notification_.value.output_frequency;
        }
        notification(const int64_t system_time_stamp_, const TobiiResearchNotificationType notification_type_, std::optional<float> output_frequency_, std::optional<TobiiResearchDisplayArea> display_area_, std::optional<std::string> errors_or_warnings_) :
            system_time_stamp(system_time_stamp_),
            notification_type(notification_type_),
            output_frequency(output_frequency_),
            display_area(display_area_),
            errors_or_warnings(errors_or_warnings_)
        {}

    public:
        int64_t                                 system_time_stamp = 0;
        TobiiResearchNotificationType           notification_type = TOBII_RESEARCH_NOTIFICATION_UNKNOWN;
        std::optional<float>                    output_frequency;
        std::optional<TobiiResearchDisplayArea> display_area;
        std::optional<std::string>              errors_or_warnings;
    };


    //// calibration
    // replacements for some Tobii classes, so we don't have to deal with their C-arrays
    struct CalibrationPoint
    {
        CalibrationPoint() = default;
        CalibrationPoint(const TobiiResearchNormalizedPoint2D pos_, std::vector<TobiiResearchCalibrationSample> samples_) :
            position_on_display_area(pos_),
            calibration_samples(std::move(samples_))
        {}
        CalibrationPoint(const TobiiResearchCalibrationPoint in_)
        {
            position_on_display_area = in_.position_on_display_area;
            if (in_.calibration_samples)
                calibration_samples = std::vector<TobiiResearchCalibrationSample>(in_.calibration_samples, in_.calibration_samples + in_.calibration_sample_count);
        }

        TobiiResearchNormalizedPoint2D position_on_display_area;
        std::vector<TobiiResearchCalibrationSample> calibration_samples;
    };

    struct CalibrationResult
    {
        CalibrationResult() = default;
        CalibrationResult(std::vector<CalibrationPoint> points_, const TobiiResearchCalibrationStatus status_) :
            calibration_points(std::move(points_)),
            status(status_)
        {}
        CalibrationResult(const TobiiResearchCalibrationResult* in_)
        {
            if (in_)
            {
                status = in_->status;
                if (in_->calibration_points)
                    calibration_points.insert(calibration_points.end(), &in_->calibration_points[0], &in_->calibration_points[in_->calibration_point_count]);
            }
        }

        std::vector<CalibrationPoint> calibration_points;
        TobiiResearchCalibrationStatus status = TOBII_RESEARCH_CALIBRATION_FAILURE;
    };

    // enums and classes for my calibration machinery
    enum class CalibrationState
    {
        NotYetEntered,
        AwaitingCalPoint,
        CollectingData,
        DiscardingData,
        Computing,
        GettingCalibrationData,
        ApplyingCalibrationData,
        Left
    };

    enum class CalibrationAction
    {
        Nothing,
        Enter,
        CollectData,
        DiscardData,
        Compute,
        GetCalibrationData,
        ApplyCalibrationData,
        Exit
    };

    struct CalibrationWorkItem
    {
        CalibrationAction	                action = CalibrationAction::Nothing;
        // some actions need one or multiple of the below
        std::optional<std::array<float,2>>  coordinates;
        std::optional<std::string>          eye;
        std::optional<std::vector<uint8_t>> calibrationData;
    };

    struct CalibrationWorkResult
    {
        CalibrationWorkItem                 workItem;
        TobiiResearchStatus                 status;
        std::string                         statusString;
        // some results may have one of the below attached
        std::optional<CalibrationResult>    calibrationResult;
        std::optional<std::vector<uint8_t>> calibrationData;
    };
}
