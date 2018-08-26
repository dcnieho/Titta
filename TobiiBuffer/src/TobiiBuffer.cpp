#include "TobiiBuffer/TobiiBuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>
#include <string_view>
#include <sstream>

#include "TobiiBuffer/utils.h"

namespace {
    typedef std::shared_timed_mutex mutex_type;
    typedef std::shared_lock<mutex_type> read_lock;
    typedef std::unique_lock<mutex_type> write_lock;

    mutex_type g_mSamp, g_mEyeImage, g_mExtSignal, g_mTimeSync;

    read_lock  lockForReading(mutex_type& m_) {return  read_lock(m_);}
    write_lock lockForWriting(mutex_type& m_) {return write_lock(m_);}

    template <typename T>
    mutex_type& getMutex()
    {
        if constexpr (std::is_same<T, TobiiResearchGazeData>::value)
            return g_mSamp;
        if constexpr (std::is_same<T, TobiiBuff::eyeImage>::value)
            return g_mEyeImage;
        if constexpr (std::is_same<T, TobiiResearchExternalSignalData>::value)
            return g_mExtSignal;
        if constexpr (std::is_same<T, TobiiResearchTimeSynchronizationData>::value)
            return g_mTimeSync;
    }
}

// deal with error messages
namespace
{
    inline void ErrorExit(std::string_view errMsg_, TobiiResearchStatus errCode_)
    {
        std::stringstream os;
        os << "TobiBuffer Error: \"" << errMsg_ << "\""<< std::endl;
        os << "Error code: " << static_cast<int>(errCode_) << ": " << TobiiResearchStatusToString(errCode_) << std::endl;

        DoExitWithMsg(os.str());
    }
}


void TobiiSampleCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(getMutex<TobiiResearchGazeData>());
        static_cast<TobiiBuffer*>(user_data)->getSampleBuffer().push_back(*gaze_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(getMutex<TobiiBuff::eyeImage>());
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(getMutex<TobiiBuff::eyeImage>());
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(getMutex<TobiiResearchExternalSignalData>());
        static_cast<TobiiBuffer*>(user_data)->getExtSignalBuffer().push_back(*ext_signal_);
    }
}
void TobiiTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting(getMutex<TobiiResearchTimeSynchronizationData>());
        static_cast<TobiiBuffer*>(user_data)->getTimeSyncBuffer().push_back(*time_sync_data_);
    }
}




TobiiBuffer::TobiiBuffer(std::string adress_)
{
    TobiiResearchStatus status = tobii_research_get_eyetracker(adress_.c_str(),&_eyetracker);
    if (status != TOBII_RESEARCH_STATUS_OK)
        ErrorExit("Cannot get eye tracker", status);
}
TobiiBuffer::~TobiiBuffer()
{
    stopSampleBuffering();
    stopEyeImageBuffering();
}


// helpers to make the below generic
template <typename T>
std::vector<T>& TobiiBuffer::getCurrentBuffer()
{
    if constexpr (std::is_same<T, TobiiResearchGazeData>::value)
        return getSampleBuffer();
    if constexpr (std::is_same<T, TobiiBuff::eyeImage>::value)
        return getEyeImageBuffer();
    if constexpr (std::is_same<T, TobiiResearchExternalSignalData>::value)
        return getExtSignalBuffer();
    if constexpr (std::is_same<T, TobiiResearchTimeSynchronizationData>::value)
        return getTimeSyncBuffer();
}
template <typename T>
std::vector<T>& TobiiBuffer::getTempBuffer()
{
    if constexpr (std::is_same<T, TobiiResearchGazeData>::value)
        return _samplesTemp;
    if constexpr (std::is_same<T, TobiiBuff::eyeImage>::value)
        return _eyeImagesTemp;
    if constexpr (std::is_same<T, TobiiResearchExternalSignalData>::value)
        return _extSignalTemp;
    if constexpr (std::is_same<T, TobiiResearchTimeSynchronizationData>::value)
        return _timeSyncTemp;
}
template <typename T>
void TobiiBuffer::enableTempBuffer(size_t initialBufferSize_)
{
    if constexpr (std::is_same<T, TobiiResearchGazeData>::value)
        enableTempBufferGeneric<T>(initialBufferSize_, _samplesUseTempBuf);
    if constexpr (std::is_same<T, TobiiResearchExternalSignalData>::value)
        enableTempBufferGeneric<T>(initialBufferSize_, _extSignalUseTempBuf);
    if constexpr (std::is_same<T, TobiiResearchTimeSynchronizationData>::value)
        enableTempBufferGeneric<T>(initialBufferSize_, _timeSyncUseTempBuf);
}
template <typename T>
void TobiiBuffer::disableTempBuffer()
{
    if constexpr (std::is_same<T, TobiiResearchGazeData>::value)
        disableTempBufferGeneric<T>(_samplesUseTempBuf);
    if constexpr (std::is_same<T, TobiiResearchExternalSignalData>::value)
        disableTempBufferGeneric<T>(_extSignalUseTempBuf);
    if constexpr (std::is_same<T, TobiiResearchTimeSynchronizationData>::value)
        disableTempBufferGeneric<T>(_timeSyncUseTempBuf);
}

// generic functions
template <typename T>
void TobiiBuffer::enableTempBufferGeneric(size_t initialBufferSize_, bool& usingTempBuf_)
{
    if (!usingTempBuf_)
    {
        getTempBuffer<T>().reserve(initialBufferSize_);
        usingTempBuf_ = true;
    }
}
template <typename T>
void TobiiBuffer::disableTempBufferGeneric(bool& usingTempBuf_)
{
    if (usingTempBuf_)
    {
        usingTempBuf_ = false;
        getTempBuffer<T>().clear();
    }
}
template <typename T>
void TobiiBuffer::clearBuffer()
{
    auto l = lockForWriting(getMutex<T>());
    getCurrentBuffer<T>().clear();
}
template <typename T>
void TobiiBuffer::stopBufferingGenericPart(bool emptyBuffer_)
{
    disableTempBuffer<T>();
    if (emptyBuffer_)
        clearBuffer<T>();
}
template <typename T>
std::vector<T> TobiiBuffer::peek(size_t lastN_)
{
    auto l = lockForReading(getMutex<T>());
    auto& buf = getCurrentBuffer<T>();
    // copy last N or whole vector if less than N elements available
    return std::vector<T>(buf.end() - std::min(buf.size(), lastN_), buf.end());
}
template <typename T>
std::vector<T> TobiiBuffer::consume(size_t firstN_)
{
    auto l = lockForWriting(getMutex<T>());
    auto& buf = getCurrentBuffer<T>();

    if (firstN_ == -1 || firstN_ >= buf.size())		// firstN_=-1 overflows, so first check strictly not needed. Better keep code legible tho
        return std::vector<T>(std::move(buf));
    else
    {
        std::vector<T> out;
        out.reserve(firstN_);
        out.insert(out.end(), std::make_move_iterator(buf.begin()), std::make_move_iterator(buf.begin() + firstN_));
        buf.erase(buf.begin(), buf.begin() + firstN_);
        return out;
    }
}


// gaze data
bool TobiiBuffer::startSampleBuffering(size_t initialBufferSize_ /*= g_sampleBufDefaultSize*/)
{
    _samples.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_gaze_data(_eyetracker,TobiiSampleCallback,this) == TOBII_RESEARCH_STATUS_OK;
}
void TobiiBuffer::enableTempSampleBuffer(size_t initialBufferSize_ /*= g_sampleTempBufDefaultSize*/)
{
    enableTempBuffer<TobiiResearchGazeData>(initialBufferSize_);
}
void TobiiBuffer::disableTempSampleBuffer()
{
    disableTempBuffer<TobiiResearchGazeData>();
}
void TobiiBuffer::clearSampleBuffer()
{
    clearBuffer<TobiiResearchGazeData>();
}
bool TobiiBuffer::stopSampleBuffering(bool emptyBuffer_ /*= g_stopBufferEmptiesDefault*/)
{
    bool success = tobii_research_unsubscribe_from_gaze_data(_eyetracker,TobiiSampleCallback) == TOBII_RESEARCH_STATUS_OK;
    stopBufferingGenericPart<TobiiResearchGazeData>(emptyBuffer_);
    return success;
}
std::vector<TobiiResearchGazeData> TobiiBuffer::consumeSamples(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiResearchGazeData>(firstN_);
}
std::vector<TobiiResearchGazeData> TobiiBuffer::peekSamples(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiResearchGazeData>(lastN_);
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
    clearBuffer<TobiiBuff::eyeImage>();
}
bool TobiiBuffer::stopEyeImageBuffering(bool emptyBuffer_ /*= g_stopBufferEmptiesDefault*/)
{
    bool success = doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
    stopBufferingGenericPart<TobiiBuff::eyeImage>(emptyBuffer_);
    return success;
}
std::vector<TobiiBuff::eyeImage> TobiiBuffer::consumeEyeImages(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiBuff::eyeImage>(firstN_);
}
std::vector<TobiiBuff::eyeImage> TobiiBuffer::peekEyeImages(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiBuff::eyeImage>(lastN_);
}


// external signals
bool TobiiBuffer::startExtSignalBuffering(size_t initialBufferSize_ /*= g_extSignalBufDefaultSize*/)
{
    _extSignal.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_external_signal_data(_eyetracker, TobiiExtSignalCallback, this) == TOBII_RESEARCH_STATUS_OK;
}
void TobiiBuffer::enableTempExtSignalBuffer(size_t initialBufferSize_ /*= g_extSignalTempBufDefaultSize*/)
{
    enableTempBuffer<TobiiResearchExternalSignalData>(initialBufferSize_);
}
void TobiiBuffer::disableTempExtSignalBuffer()
{
    disableTempBuffer<TobiiResearchExternalSignalData>();
}
void TobiiBuffer::clearExtSignalBuffer()
{
    clearBuffer<TobiiResearchExternalSignalData>();
}
bool TobiiBuffer::stopExtSignalBuffering(bool emptyBuffer_ /*= g_stopBufferEmptiesDefault*/)
{
    bool success = tobii_research_unsubscribe_from_external_signal_data(_eyetracker, TobiiExtSignalCallback) == TOBII_RESEARCH_STATUS_OK;
    stopBufferingGenericPart<TobiiResearchExternalSignalData>(emptyBuffer_);
    return success;
}
std::vector<TobiiResearchExternalSignalData> TobiiBuffer::consumeExtSignals(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiResearchExternalSignalData>(firstN_);
}
std::vector<TobiiResearchExternalSignalData> TobiiBuffer::peekExtSignals(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiResearchExternalSignalData>(lastN_);
}


// time sync data
bool TobiiBuffer::startTimeSyncBuffering(size_t initialBufferSize_ /*= g_timeSyncBufDefaultSize*/)
{
    _timeSync.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback, this) == TOBII_RESEARCH_STATUS_OK;
}
void TobiiBuffer::enableTempTimeSyncBuffer(size_t initialBufferSize_ /*= g_timeSyncTempBufDefaultSize*/)
{
    enableTempBuffer<TobiiResearchTimeSynchronizationData>(initialBufferSize_);
}
void TobiiBuffer::disableTempTimeSyncBuffer()
{
    disableTempBuffer<TobiiResearchTimeSynchronizationData>();
}
void TobiiBuffer::clearTimeSyncBuffer()
{
    clearBuffer<TobiiResearchTimeSynchronizationData>();
}
bool TobiiBuffer::stopTimeSyncBuffering(bool emptyBuffer_ /*= g_stopBufferEmptiesDefault*/)
{
    bool success = tobii_research_unsubscribe_from_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback) == TOBII_RESEARCH_STATUS_OK;
    stopBufferingGenericPart<TobiiResearchTimeSynchronizationData>(emptyBuffer_);
    return success;
}
std::vector<TobiiResearchTimeSynchronizationData> TobiiBuffer::consumeTimeSyncs(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiResearchTimeSynchronizationData>(firstN_);
}
std::vector<TobiiResearchTimeSynchronizationData> TobiiBuffer::peekTimeSyncs(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiResearchTimeSynchronizationData>(lastN_);
}