#include "TobiiBuffer/TobiiBuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>

namespace {
    typedef std::shared_timed_mutex mutex_type;
    typedef std::shared_lock<mutex_type> read_lock;
    typedef std::unique_lock<mutex_type> write_lock;

    mutex_type mSamp, mEyeImage;

    read_lock  lockForReading(mutex_type& m_) {return  read_lock(m_);}
    write_lock lockForWriting(mutex_type& m_) {return write_lock(m_);}
}


void TobiiSampleCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(mSamp);
        static_cast<TobiiBuffer*>(user_data)->_samples.push_back(*gaze_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        // deep copy image data
        auto im = TobiiEyeImage(eye_image_);

        // append to vector
        auto l = lockForWriting(mEyeImage);
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().push_back(std::move(im));
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


bool TobiiBuffer::startSampleBuffering(size_t initialBufferSize_ /*= 1<<22*/)
{
    _samples.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_gaze_data(_eyetracker,TobiiSampleCallback,this) == TOBII_RESEARCH_STATUS_OK;
}
void TobiiBuffer::clearSampleBuffer()
{
    auto l = lockForWriting(mSamp);
    _samples.clear();
}
bool TobiiBuffer::stopSampleBuffering(bool emptyBuffer /*= false*/)
{
    bool success = tobii_research_unsubscribe_from_gaze_data(_eyetracker,TobiiSampleCallback) == TOBII_RESEARCH_STATUS_OK;
    if (emptyBuffer)
        clearSampleBuffer();
    return success;
}
std::vector<TobiiResearchGazeData> TobiiBuffer::consumeSamples(size_t firstN/* = -1*/)
{
    auto l = lockForWriting(mSamp);
    if (firstN>=_samples.size())
        return std::vector<TobiiResearchGazeData>(std::move(_samples));
    else
    {
        std::vector<TobiiResearchGazeData> out;
        out.insert(out.end(), std::make_move_iterator(_samples.begin()), std::make_move_iterator(_samples.begin()+firstN));
        _samples.erase(_samples.begin(), _samples.begin()+firstN);
        return out;
    }
}
std::vector<TobiiResearchGazeData> TobiiBuffer::peekSamples(size_t lastN/* = 1*/)
{
    auto l = lockForReading(mSamp);
    // copy last N or whole vector if less than N elements available
    return std::vector<TobiiResearchGazeData>(_samples.end() - std::min(_samples.size(),lastN),_samples.end());
}



bool TobiiBuffer::startEyeImageBuffering(size_t initialBufferSize_ /*= 1<<22*/)
{
    _eyeImages.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_eye_image(_eyetracker,TobiiEyeImageCallback,this) == TOBII_RESEARCH_STATUS_OK;
}
void TobiiBuffer::clearEyeImageBuffer()
{
    auto l = lockForWriting(mEyeImage);
    getEyeImageBuffer().clear();
}
void TobiiBuffer::enableTempEyeBuffer(size_t initialBufferSize_ /*= 1 << 10*/)
{
    if (!_eyeImUseTempBuf)
    {
        _eyeImagesTemp.reserve(initialBufferSize_);
    }
    _eyeImUseTempBuf = true;
}
void TobiiBuffer::disableTempEyeBuffer()
{
    if (_eyeImUseTempBuf)
    {
        _eyeImUseTempBuf = false;
        _eyeImagesTemp.clear();
    }
}
bool TobiiBuffer::stopEyeImageBuffering(bool emptyBuffer /*= false*/)
{
    bool success = tobii_research_unsubscribe_from_eye_image(_eyetracker,TobiiEyeImageCallback) == TOBII_RESEARCH_STATUS_OK;
    if (emptyBuffer)
        clearEyeImageBuffer();
    return success;
}
std::vector<TobiiEyeImage> TobiiBuffer::consumeEyeImages(size_t firstN/* = -1*/)
{
    auto l = lockForWriting(mEyeImage);
    auto& imVec = getEyeImageBuffer();

    if (firstN==-1 || firstN>=imVec.size())    // firstN=1 overflows, so first check strictly not needed. Better keep code legible tho
        return std::vector<TobiiEyeImage>(std::move(imVec));
    else
    {
        std::vector<TobiiEyeImage> out;
        out.reserve(firstN);
        out.insert(out.end(), std::make_move_iterator(imVec.begin()), std::make_move_iterator(imVec.begin()+firstN));
        imVec.erase(imVec.begin(), imVec.begin()+firstN);
        return out;
    }
}
std::vector<TobiiEyeImage> TobiiBuffer::peekEyeImages(size_t lastN/* = 1*/)
{
    auto l = lockForReading(mEyeImage);
    // copy last N or whole vector if less than N elements available
    auto& imVec = getEyeImageBuffer();
    return std::vector<TobiiEyeImage>(imVec.end() - std::min(imVec.size(),lastN),imVec.end());
}