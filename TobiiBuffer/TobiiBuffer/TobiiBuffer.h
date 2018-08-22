#pragma once
#include <vector>
#include <string>
#include <memory>
#include <tobii_research.h>
#include <tobii_research_eyetracker.h>
#include <tobii_research_streams.h>
#pragma comment(lib, "tobii_research.lib")


namespace TobiiBuff
{
    // default argument values
    constexpr size_t g_sampleBufDefaultSize = 1 << 22;
    constexpr size_t g_sampleTempBufDefaultSize = 1 << 16;
    constexpr size_t g_eyeImageBufDefaultSize = 1 << 14;
    constexpr bool   g_eyeImageAsGIFDefault = false;
    constexpr size_t g_eyeImageTempBufDefaultSize = 1 << 10;
    constexpr bool   g_stopBufferEmptiesDefault = false;
    constexpr size_t g_consumeDefaultAmount = -1;
    constexpr size_t g_peekDefaultAmount = 1;


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
}


class TobiiBuffer
{
public:
    TobiiBuffer(std::string adress_);
    ~TobiiBuffer();

    //// Samples ////
    bool startSampleBuffering(size_t initialBufferSize_ = TobiiBuff::g_sampleBufDefaultSize);
    // switch to recording to a temp buffer
    void enableTempSampleBuffer(size_t initialBufferSize_ = TobiiBuff::g_sampleTempBufDefaultSize);
    // switch back to main buffer, discarding temp buffer
    void disableTempSampleBuffer();
    // clear all buffer contents
    void clearSampleBuffer();
    // stop optionally deletes the buffer
    bool stopSampleBuffering(bool emptyBuffer = TobiiBuff::g_stopBufferEmptiesDefault);
    // consume samples (by default all)
    std::vector<TobiiResearchGazeData> consumeSamples(size_t firstN = TobiiBuff::g_consumeDefaultAmount);
    // peek samples (by default only last one, can specify how many from end to peek)
    std::vector<TobiiResearchGazeData> peekSamples(size_t lastN = TobiiBuff::g_peekDefaultAmount);

    //// eyeImages ////
    bool startEyeImageBuffering(size_t initialBufferSize_ = TobiiBuff::g_eyeImageBufDefaultSize, bool asGif_ = TobiiBuff::g_eyeImageAsGIFDefault);
    // switch to recording to a temp buffer
    void enableTempEyeImageBuffer(size_t initialBufferSize_ = TobiiBuff::g_eyeImageTempBufDefaultSize);
    // switch back to main buffer, discarding temp buffer
    void disableTempEyeImageBuffer();
    // clear all buffer contents
    void clearEyeImageBuffer();
    // stop optionally deletes the buffer
    bool stopEyeImageBuffering(bool emptyBuffer = TobiiBuff::g_stopBufferEmptiesDefault);
    // consume samples (by default all)
    std::vector<TobiiBuff::eyeImage> consumeEyeImages(size_t firstN = TobiiBuff::g_consumeDefaultAmount);
    // peek samples (by default only last one, can specify how many from end to peek)
    std::vector<TobiiBuff::eyeImage> peekEyeImages(size_t lastN = TobiiBuff::g_peekDefaultAmount);

private:
    // Tobii callbacks needs to be friends
    friend void TobiiSampleCallback     (   TobiiResearchGazeData* gaze_data_, void* user_data);
    friend void TobiiEyeImageCallback   (   TobiiResearchEyeImage* eye_image_, void* user_data);
    friend void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data);

    std::vector<TobiiResearchGazeData   >& getSampleBuffer()   {return _samplesUseTempBuf ? _samplesTemp   : _samples;}
    std::vector<TobiiBuff::eyeImage>& getEyeImageBuffer() {return _eyeImUseTempBuf   ? _eyeImagesTemp : _eyeImages;}

private:

    TobiiResearchEyeTracker*				_eyetracker         = nullptr;

    std::vector<TobiiResearchGazeData>		_samples;
    std::vector<TobiiResearchGazeData>		_samplesTemp;
    bool									_samplesUseTempBuf	= false;

    std::vector<TobiiBuff::eyeImage>		_eyeImages;
    std::vector<TobiiBuff::eyeImage>		_eyeImagesTemp;
    bool									_eyeImUseTempBuf	= false;
    bool									_eyeImIsGif			= false;
    bool									_eyeImWasGif		= false;
};