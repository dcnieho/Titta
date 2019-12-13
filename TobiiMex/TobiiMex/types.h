#pragma once
#include <string>
#include <memory>
#include <array>
#include <vector>
#include <cstring>

#include <tobii_research_streams.h>
#include <tobii_research_calibration.h>

namespace TobiiTypes
{
    class eyeTracker
    {
    public:
        eyeTracker() = default;
        eyeTracker(TobiiResearchEyeTracker* et_);
        eyeTracker(std::string deviceName_, std::string serialNumber_, std::string model_, std::string firmwareVersion_, std::string runtimeVersion_, std::string address_,
            TobiiResearchCapabilities capabilities_, std::vector<float> supportedFrequencies_, std::vector<std::string> supportedModes_);

        void refreshInfo();

    public:
        TobiiResearchEyeTracker*    et = nullptr;
        std::string                 deviceName, serialNumber, model, firmwareVersion, runtimeVersion, address;
        TobiiResearchCapabilities   capabilities = TOBII_RESEARCH_CAPABILITIES_NONE;
        std::vector<float>          supportedFrequencies;
        std::vector<std::string>    supportedModes;
    };

    // My own almost POD class for Tobii eye images, for safe resource management
    // of the data heap array member
    class eyeImage
    {
    public:
        eyeImage() :
            isGif(false),
            device_time_stamp(0),
            system_time_stamp(0),
            bits_per_pixel(0),
            padding_per_pixel(0),
            width(0),
            height(0),
            type(TOBII_RESEARCH_EYE_IMAGE_TYPE_UNKNOWN),
            camera_id(0),
            data_size(0),
            _eyeIm({nullptr,std::free})
        {}
        eyeImage(TobiiResearchEyeImage* e_) :
            isGif(false),
            device_time_stamp(e_->device_time_stamp),
            system_time_stamp(e_->system_time_stamp),
            bits_per_pixel(e_->bits_per_pixel),
            padding_per_pixel(e_->padding_per_pixel),
            width(e_->width),
            height(e_->height),
            type(e_->type),
            camera_id(e_->camera_id),
            data_size(e_->data_size),
            _eyeIm({malloc(e_->data_size),std::free})
        {
            std::memcpy(_eyeIm.get(), e_->data, e_->data_size);
        }
        eyeImage(TobiiResearchEyeImageGif* e_) :
            isGif(true),
            device_time_stamp(e_->device_time_stamp),
            system_time_stamp(e_->system_time_stamp),
            bits_per_pixel(0),
            padding_per_pixel(0),
            width(0),
            height(0),
            type(e_->type),
            camera_id(e_->camera_id),
            data_size(e_->image_size),
            _eyeIm({malloc(e_->image_size),std::free})
        {
            std::memcpy(_eyeIm.get(), e_->image_data, e_->image_size);
        }
        eyeImage(eyeImage&&) noexcept = default;
        eyeImage(const eyeImage& other_) :
            isGif(other_.isGif),
            device_time_stamp(other_.device_time_stamp),
            system_time_stamp(other_.system_time_stamp),
            bits_per_pixel(other_.bits_per_pixel),
            padding_per_pixel(other_.padding_per_pixel),
            width(other_.width),
            height(other_.height),
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
        void setData(const uint8_t* data_, size_t nBytes_)
        {
            if (nBytes_)
            {
                _eyeIm.reset(malloc(nBytes_));
                std::memcpy(_eyeIm.get(), data_, nBytes_);
                data_size = nBytes_;
            }
        }

        friend void swap(eyeImage& first, eyeImage& second)
        {
            using std::swap;

            swap(first.isGif, second.isGif);
            swap(first.device_time_stamp, second.device_time_stamp);
            swap(first.system_time_stamp, second.system_time_stamp);
            swap(first.bits_per_pixel, second.bits_per_pixel);
            swap(first.padding_per_pixel, second.padding_per_pixel);
            swap(first.width, second.width);
            swap(first.height, second.height);
            swap(first.type, second.type);
            swap(first.camera_id, second.camera_id);
            swap(first.data_size, second.data_size);
            swap(first._eyeIm, second._eyeIm);
        }

    public:
        bool						isGif;
        int64_t                     device_time_stamp;
        int64_t                     system_time_stamp;
        int                         bits_per_pixel;
        int                         padding_per_pixel;
        int                         width;
        int                         height;
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
        logMessage(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, std::string message_) :
            system_time_stamp(system_time_stamp_),
            source(source_),
            level(level_),
            message(message_)
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
        streamErrorMessage(std::string serial_, int64_t system_time_stamp_, TobiiResearchStreamError error_, TobiiResearchStreamErrorSource source_, std::string message_) :
            machineSerial(serial_),
            system_time_stamp(system_time_stamp_),
            error(error_),
            source(source_),
            message(message_)
        {}

    public:
        std::string                     machineSerial;
        int64_t                         system_time_stamp = 0;
        TobiiResearchStreamError        error  = TOBII_RESEARCH_STREAM_ERROR_CONNECTION_LOST;
        TobiiResearchStreamErrorSource  source = TOBII_RESEARCH_STREAM_ERROR_SOURCE_USER;
        std::string                     message;
    };


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
        CalibrationAction	action = CalibrationAction::Nothing;
        // some actions need one or both of the below
        std::vector<double> coordinates;
        std::string         eye;
        std::vector<uint8_t>calData;
    };

    struct CalibrationWorkResult
    {
        CalibrationWorkItem                             workItem;
        TobiiResearchStatus                             status;
        std::string                                     statusString;
        std::shared_ptr<TobiiResearchCalibrationResult> calibrationResult;
        std::shared_ptr<TobiiResearchCalibrationData>   calibrationData;
    };
}