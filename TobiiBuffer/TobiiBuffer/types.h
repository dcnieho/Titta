#pragma once
#include <string>
#include <memory>
#include <tobii_research_streams.h>

namespace TobiiTypes
{
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
            memcpy(_eyeIm.get(), e_->data, e_->data_size);
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
            memcpy(_eyeIm.get(), e_->image_data, e_->image_size);
        }
        eyeImage(eyeImage&&) = default;
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
            memcpy(_eyeIm.get(), other_.data(), other_.data_size);
        }
        eyeImage& operator= (eyeImage other_)
        {
            swap(*this, other_);
            return *this;
        }
        ~eyeImage() = default;

        // get eye image data
        void* data() const { return _eyeIm.get(); }

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
        logMessage() {}
        logMessage(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, std::string message_) :
            system_time_stamp(system_time_stamp_),
            source(source_),
            level(level_),
            message(message_)
        {}

    public:
        int64_t                system_time_stamp = 0;
        TobiiResearchLogSource source = TOBII_RESEARCH_LOG_SOURCE_STREAM_ENGINE;
        TobiiResearchLogLevel  level = TOBII_RESEARCH_LOG_LEVEL_ERROR;
        std::string            message;
    };
}