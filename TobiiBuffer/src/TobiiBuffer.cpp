#include "TobiiBuffer/TobiiBuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>

namespace {
    typedef std::shared_timed_mutex mutex_type;
    typedef std::shared_lock<mutex_type> read_lock;
    typedef std::unique_lock<mutex_type> write_lock;

    mutex_type mSamp, mEyeImage, mExtSignal, mTimeSync;

    read_lock  lockForReading(mutex_type& m_) {return  read_lock(m_);}
    write_lock lockForWriting(mutex_type& m_) {return write_lock(m_);}
}


void TobiiSampleCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(mSamp);
        static_cast<TobiiBuffer*>(user_data)->getSampleBuffer().push_back(*gaze_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(mEyeImage);
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(mEyeImage);
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiExternalDataCallback(TobiiResearchExternalSignalData* ext_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(mExtSignal);
        //static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(mTimeSync);
        //static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}




TobiiBuffer::TobiiBuffer(std::string adress_)
{
    TobiiResearchStatus status = tobii_research_get_eyetracker(adress_.c_str(),&_eyetracker);
    // TODO: deal with failure to get eye tracker
}
TobiiBuffer::~TobiiBuffer()
{
    stopSampleBuffering();
}


bool TobiiBuffer::startSampleBuffering(size_t initialBufferSize_ /*= g_sampleBufDefaultSize*/)
{
    _samples.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_gaze_data(_eyetracker,TobiiSampleCallback,this) == TOBII_RESEARCH_STATUS_OK;
}
void TobiiBuffer::enableTempSampleBuffer(size_t initialBufferSize_ /*= g_sampleTempBufDefaultSize*/)
{
    if (!_samplesUseTempBuf)
    {
        _samplesTemp.reserve(initialBufferSize_);
        _samplesUseTempBuf = true;
    }
}
void TobiiBuffer::disableTempSampleBuffer()
{
    if (_samplesUseTempBuf)
    {
        _samplesUseTempBuf = false;
        _samplesTemp.clear();
    }
}
void TobiiBuffer::clearSampleBuffer()
{
    auto l = lockForWriting(mSamp);
    getSampleBuffer().clear();
}
bool TobiiBuffer::stopSampleBuffering(bool emptyBuffer /*= g_stopBufferEmptiesDefault*/)
{
    bool success = tobii_research_unsubscribe_from_gaze_data(_eyetracker,TobiiSampleCallback) == TOBII_RESEARCH_STATUS_OK;
    if (emptyBuffer)
        clearSampleBuffer();
    return success;
}
std::vector<TobiiResearchGazeData> TobiiBuffer::consumeSamples(size_t firstN/* = g_consumeDefaultAmount*/)
{
    auto l = lockForWriting(mSamp);
    auto& sampBuf = getSampleBuffer();
    if (firstN == -1 || firstN >= sampBuf.size())	// firstN=-1 overflows, so first check strictly not needed. Better keep code legible tho
        return std::vector<TobiiResearchGazeData>(std::move(sampBuf));
    else
    {
        std::vector<TobiiResearchGazeData> out;
        out.reserve(firstN);
        out.insert(out.end(), std::make_move_iterator(sampBuf.begin()), std::make_move_iterator(sampBuf.begin()+firstN));
        sampBuf.erase(sampBuf.begin(), sampBuf.begin()+firstN);
        return out;
    }
}
std::vector<TobiiResearchGazeData> TobiiBuffer::peekSamples(size_t lastN/* = g_peekDefaultAmount*/)
{
    auto l = lockForReading(mSamp);
    auto& sampBuf = getSampleBuffer();
    // copy last N or whole vector if less than N elements available
    return std::vector<TobiiResearchGazeData>(sampBuf.end() - std::min(sampBuf.size(),lastN), sampBuf.end());
}



namespace {
    // eye image helpers
    bool doSubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, TobiiBuffer* instance_, bool asGif_)
    {
        if (asGif_)
            return tobii_research_subscribe_to_eye_image_as_gif(eyetracker_, TobiiEyeImageGifCallback, instance_) == TOBII_RESEARCH_STATUS_OK;
        else
            return tobii_research_subscribe_to_eye_image	   (eyetracker_,    TobiiEyeImageCallback, instance_) == TOBII_RESEARCH_STATUS_OK;
    }
    bool doUnsubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, bool isGif_)
    {
        if (isGif_)
            return tobii_research_unsubscribe_from_eye_image_as_gif(eyetracker_, TobiiEyeImageGifCallback) == TOBII_RESEARCH_STATUS_OK;
        else
            return tobii_research_unsubscribe_from_eye_image       (eyetracker_,    TobiiEyeImageCallback) == TOBII_RESEARCH_STATUS_OK;
    }
}

bool TobiiBuffer::startEyeImageBuffering(size_t initialBufferSize_ /*= g_eyeImageBufDefaultSize*/, bool asGif_ /*= g_eyeImageAsGIFDefault*/)
{
    _eyeImages.reserve(initialBufferSize_);
    _eyeImIsGif = asGif_;
    return doSubscribeEyeImage(_eyetracker, this, asGif_);
}
void TobiiBuffer::enableTempEyeImageBuffer(size_t initialBufferSize_ /*= g_eyeImageTempBufDefaultSize*/)
{
    if (!_eyeImUseTempBuf)
    {
        _eyeImagesTemp.reserve(initialBufferSize_);
        _eyeImWasGif = _eyeImIsGif;
        // temp buffer always normal eye image, stop gif images, start normal
        if (_eyeImIsGif)
        {
            doUnsubscribeEyeImage(_eyetracker, true);
        }
        _eyeImUseTempBuf = true;
        if (_eyeImIsGif)
        {
            doSubscribeEyeImage(_eyetracker, this, false);
            _eyeImIsGif = false;
        }
    }
}
void TobiiBuffer::disableTempEyeImageBuffer()
{
    if (_eyeImUseTempBuf)
    {
        // if normal buffer was used for gifs before starting temp buffer, resubscribe to the gif stream
        if (_eyeImWasGif)
        {
            doUnsubscribeEyeImage(_eyetracker, false);
            doSubscribeEyeImage(_eyetracker, this, true);
            _eyeImIsGif = true;
        }
        _eyeImUseTempBuf = false;
        _eyeImagesTemp.clear();
    }
}
void TobiiBuffer::clearEyeImageBuffer()
{
    auto l = lockForWriting(mEyeImage);
    getEyeImageBuffer().clear();
}
bool TobiiBuffer::stopEyeImageBuffering(bool emptyBuffer /*= g_stopBufferEmptiesDefault*/)
{
    bool success = doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
    if (emptyBuffer)
        clearEyeImageBuffer();
    return success;
}
std::vector<TobiiBuff::eyeImage> TobiiBuffer::consumeEyeImages(size_t firstN/* = g_consumeDefaultAmount*/)
{
    auto l = lockForWriting(mEyeImage);
    auto& imBuf = getEyeImageBuffer();

    if (firstN==-1 || firstN>=imBuf.size())    // firstN=-1 overflows, so first check strictly not needed. Better keep code legible tho
        return std::vector<TobiiBuff::eyeImage>(std::move(imBuf));
    else
    {
        std::vector<TobiiBuff::eyeImage> out;
        out.reserve(firstN);
        out.insert(out.end(), std::make_move_iterator(imBuf.begin()), std::make_move_iterator(imBuf.begin()+firstN));
        imBuf.erase(imBuf.begin(), imBuf.begin()+firstN);
        return out;
    }
}
std::vector<TobiiBuff::eyeImage> TobiiBuffer::peekEyeImages(size_t lastN/* = g_peekDefaultAmount*/)
{
    auto l = lockForReading(mEyeImage);
    // copy last N or whole vector if less than N elements available
    auto& imBuf = getEyeImageBuffer();
    return std::vector<TobiiBuff::eyeImage>(imBuf.end() - std::min(imBuf.size(),lastN),imBuf.end());
}