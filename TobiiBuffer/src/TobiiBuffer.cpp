#include "TobiiBuffer/TobiiBuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>
#include <string_view>
#include <sstream>
#include <map>

#include "TobiiBuffer/utils.h"

namespace {
    typedef std::shared_timed_mutex mutex_type;
    typedef std::shared_lock<mutex_type> read_lock;
    typedef std::unique_lock<mutex_type> write_lock;

    mutex_type g_mSamp, g_mEyeImage, g_mExtSignal, g_mTimeSync, g_mLog;

    template <typename T>
    read_lock  lockForReading() { return  read_lock(getMutex<T>()); }
    template <typename T>
    write_lock lockForWriting() { return write_lock(getMutex<T>()); }

    template <typename T>
    mutex_type& getMutex()
    {
        if constexpr (std::is_same_v<T, TobiiResearchGazeData>)
            return g_mSamp;
        if constexpr (std::is_same_v<T, TobiiBuff::eyeImage>)
            return g_mEyeImage;
        if constexpr (std::is_same_v<T, TobiiResearchExternalSignalData>)
            return g_mExtSignal;
        if constexpr (std::is_same_v<T, TobiiResearchTimeSynchronizationData>)
            return g_mTimeSync;
        if constexpr (std::is_same_v<T, TobiiBuff::logMessage>)
            return g_mLog;
    }

    // global log buffer
    std::unique_ptr<std::vector<TobiiBuff::logMessage>> g_logMessages;

    // deal with error messages
    inline void ErrorExit(std::string_view errMsg_, TobiiResearchStatus errCode_)
    {
        std::stringstream os;
        os << "TobiiBuffer Error: " << errMsg_ << std::endl;
        os << "Error code: " << static_cast<int>(errCode_) << ": " << TobiiResearchStatusToString(errCode_) << " (" << TobiiResearchStatusToExplanation(errCode_) << ")" << std::endl;

        DoExitWithMsg(os.str());
    }

    // Map string to an Data Stream
    const std::map<std::string, TobiiBuff::DataStream> dataStreamMap =
    {
        { "sample",    TobiiBuff::DataStream::Sample },
        { "eyeImage",  TobiiBuff::DataStream::EyeImage },
        { "extSignal", TobiiBuff::DataStream::ExtSignal },
        { "timeSync",  TobiiBuff::DataStream::TimeSync }
    };
}

namespace TobiiBuff
{
    DataStream stringToDataStream(std::string dataStream_)
    {
        if (dataStreamMap.count(dataStream_) == 0)
        {
            std::stringstream os;
            os << "Unrecognized data stream (not in dataStreamMap): \"" << dataStream_ << "\"";
            DoExitWithMsg(os.str());
        }
        return dataStreamMap.at(dataStream_);
    }
}


void TobiiSampleCallback(TobiiResearchGazeData* gaze_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiResearchGazeData>();
        static_cast<TobiiBuffer*>(user_data)->getSampleBuffer().push_back(*gaze_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiBuff::eyeImage>();
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiBuff::eyeImage>();
        static_cast<TobiiBuffer*>(user_data)->getEyeImageBuffer().emplace_back(eye_image_);
    }
}
void TobiiExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiResearchExternalSignalData>();
        static_cast<TobiiBuffer*>(user_data)->getExtSignalBuffer().push_back(*ext_signal_);
    }
}
void TobiiTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiResearchTimeSynchronizationData>();
        static_cast<TobiiBuffer*>(user_data)->getTimeSyncBuffer().push_back(*time_sync_data_);
    }
}
void TobiiLogCallback(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_)
{
    if (g_logMessages)
    {
        auto l = lockForWriting<TobiiBuff::logMessage>();
        g_logMessages.get()->emplace_back(system_time_stamp_,source_,level_,message_);
    }
}




TobiiBuffer::TobiiBuffer(std::string address_)
{
    TobiiResearchStatus status = tobii_research_get_eyetracker(address_.c_str(),&_eyetracker);
    if (status != TOBII_RESEARCH_STATUS_OK)
    {
        std::stringstream os;
        os << "Cannot get eye tracker \"" << address_ << "\"";
        ErrorExit(os.str(), status);
    }
}
TobiiBuffer::TobiiBuffer(TobiiResearchEyeTracker* et_)
{
    _eyetracker = et_;
}
TobiiBuffer::~TobiiBuffer()
{
    stopImpl<TobiiResearchGazeData>(true);
    stopImpl<TobiiBuff::eyeImage>(true);
    stopImpl<TobiiResearchExternalSignalData>(true);
    stopImpl<TobiiResearchTimeSynchronizationData>(true);
    TobiiBuff::stopLogging();
}


// helpers to make the below generic
template <typename T>
std::vector<T>& TobiiBuffer::getCurrentBuffer()
{
    if constexpr (std::is_same_v<T, TobiiResearchGazeData>)
        return getSampleBuffer();
    if constexpr (std::is_same_v<T, TobiiBuff::eyeImage>)
        return getEyeImageBuffer();
    if constexpr (std::is_same_v<T, TobiiResearchExternalSignalData>)
        return getExtSignalBuffer();
    if constexpr (std::is_same_v<T, TobiiResearchTimeSynchronizationData>)
        return getTimeSyncBuffer();
}
template <typename T>
std::vector<T>& TobiiBuffer::getTempBuffer()
{
    if constexpr (std::is_same_v<T, TobiiResearchGazeData>)
        return _samplesTemp;
    if constexpr (std::is_same_v<T, TobiiBuff::eyeImage>)
        return _eyeImagesTemp;
    if constexpr (std::is_same_v<T, TobiiResearchExternalSignalData>)
        return _extSignalTemp;
    if constexpr (std::is_same_v<T, TobiiResearchTimeSynchronizationData>)
        return _timeSyncTemp;
}
template <typename T>
void TobiiBuffer::enableTempBuffer(size_t initialBufferSize_)
{
    if constexpr (std::is_same_v<T, TobiiResearchGazeData>)
        enableTempBufferGeneric<T>(initialBufferSize_, _samplesUseTempBuf);
    if constexpr (std::is_same_v<T, TobiiResearchExternalSignalData>)
        enableTempBufferGeneric<T>(initialBufferSize_, _extSignalUseTempBuf);
    if constexpr (std::is_same_v<T, TobiiResearchTimeSynchronizationData>)
        enableTempBufferGeneric<T>(initialBufferSize_, _timeSyncUseTempBuf);
}
template <typename T>
void TobiiBuffer::disableTempBuffer()
{
    if constexpr (std::is_same_v<T, TobiiResearchGazeData>)
        disableTempBufferGeneric<T>(_samplesUseTempBuf);
    if constexpr (std::is_same_v<T, TobiiResearchExternalSignalData>)
        disableTempBufferGeneric<T>(_extSignalUseTempBuf);
    if constexpr (std::is_same_v<T, TobiiResearchTimeSynchronizationData>)
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
void TobiiBuffer::clearImpl()
{
    auto l = lockForWriting<T>();
    getCurrentBuffer<T>().clear();
}
template <typename T>
bool TobiiBuffer::stopImpl(bool emptyBuffer_)
{
    bool success = false;
    if constexpr (std::is_same_v<T, TobiiResearchGazeData>)
    {
        success = tobii_research_unsubscribe_from_gaze_data(_eyetracker, TobiiSampleCallback) == TOBII_RESEARCH_STATUS_OK;
    }
    if constexpr (std::is_same_v<T, TobiiBuff::eyeImage>)
    {
        success = doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
        _recordingEyeImages = false;
    }
    if constexpr (std::is_same_v<T, TobiiResearchExternalSignalData>)
    {
        success = tobii_research_unsubscribe_from_external_signal_data(_eyetracker, TobiiExtSignalCallback) == TOBII_RESEARCH_STATUS_OK;
    }
    if constexpr (std::is_same_v<T, TobiiResearchTimeSynchronizationData>)
    {
        success = tobii_research_unsubscribe_from_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback) == TOBII_RESEARCH_STATUS_OK;
    }

    disableTempBuffer<T>();
    if (emptyBuffer_)
        clearImpl<T>();

    return success;
}
template <typename T>
std::vector<T> TobiiBuffer::peek(size_t lastN_)
{
    auto l = lockForReading<T>();
    auto& buf = getCurrentBuffer<T>();
    // copy last N or whole vector if less than N elements available
    return std::vector<T>(buf.end() - std::min(buf.size(), lastN_), buf.end());
}
template <typename T>
std::vector<T> TobiiBuffer::consume(size_t firstN_)
{
    auto l = lockForWriting<T>();
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

// functions taking buffer type as input
void TobiiBuffer::clear(std::string dataStream_)
{
    // get corresponding data stream
    TobiiBuff::DataStream stream = TobiiBuff::stringToDataStream(dataStream_);
    
    // now clear that buffer
    switch (stream)
    {
        case TobiiBuff::DataStream::Sample:
            clearImpl<TobiiResearchGazeData>();
            break;
        case TobiiBuff::DataStream::EyeImage:
            clearImpl<TobiiBuff::eyeImage>();
            break;
        case TobiiBuff::DataStream::ExtSignal:
            clearImpl<TobiiResearchExternalSignalData>();
            break;
        case TobiiBuff::DataStream::TimeSync:
            clearImpl<TobiiResearchTimeSynchronizationData>();
            break;
    }
}
bool TobiiBuffer::stop(std::string dataStream_, bool emptyBuffer_ /*= TobiiBuff::g_stopBufferEmptiesDefault*/)
{
    // get corresponding data stream
    TobiiBuff::DataStream stream = TobiiBuff::stringToDataStream(dataStream_);

    // now clear that buffer
    bool out = false;
    switch (stream)
    {
        case TobiiBuff::DataStream::Sample:
            out = stopImpl<TobiiResearchGazeData>(emptyBuffer_);
            break;
        case TobiiBuff::DataStream::EyeImage:
            out = stopImpl<TobiiBuff::eyeImage>(emptyBuffer_);
            break;
        case TobiiBuff::DataStream::ExtSignal:
            out = stopImpl<TobiiResearchExternalSignalData>(emptyBuffer_);
            break;
        case TobiiBuff::DataStream::TimeSync:
            out = stopImpl<TobiiResearchTimeSynchronizationData>(emptyBuffer_);
            break;
    }
    return out;
}

// gaze data
bool TobiiBuffer::startSample(size_t initialBufferSize_ /*= g_sampleBufDefaultSize*/)
{
    auto l = lockForWriting<TobiiResearchGazeData>();
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

bool TobiiBuffer::startEyeImage(size_t initialBufferSize_ /*= g_eyeImageBufDefaultSize*/, bool asGif_ /*= g_eyeImageAsGIFDefault*/)
{
    auto l = lockForWriting<TobiiBuff::eyeImage>();
    _eyeImages.reserve(initialBufferSize_);

    // if temp buffer selected, always record normal images, not gif
    if (_eyeImUseTempBuf)
        asGif_ = false;

    // if already recording and switching from gif to normal or other way, first stop old stream
    if (_recordingEyeImages)
        if (asGif_ != _eyeImIsGif)
            doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
        else
            // nothing to do
            return true;

    // subscribe to new stream
    _recordingEyeImages = doSubscribeEyeImage(_eyetracker, this, asGif_);
    _eyeImIsGif = _recordingEyeImages ? asGif_ : _eyeImIsGif;	// update type being recorded if subscription to stream was succesful
    return _recordingEyeImages;
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
std::vector<TobiiBuff::eyeImage> TobiiBuffer::consumeEyeImages(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiBuff::eyeImage>(firstN_);
}
std::vector<TobiiBuff::eyeImage> TobiiBuffer::peekEyeImages(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiBuff::eyeImage>(lastN_);
}


// external signals
bool TobiiBuffer::startExtSignal(size_t initialBufferSize_ /*= g_extSignalBufDefaultSize*/)
{
    auto l = lockForWriting<TobiiResearchExternalSignalData>();
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
std::vector<TobiiResearchExternalSignalData> TobiiBuffer::consumeExtSignals(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiResearchExternalSignalData>(firstN_);
}
std::vector<TobiiResearchExternalSignalData> TobiiBuffer::peekExtSignals(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiResearchExternalSignalData>(lastN_);
}


// time sync data
bool TobiiBuffer::startTimeSync(size_t initialBufferSize_ /*= g_timeSyncBufDefaultSize*/)
{
    auto l = lockForWriting<TobiiResearchTimeSynchronizationData>();
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
std::vector<TobiiResearchTimeSynchronizationData> TobiiBuffer::consumeTimeSyncs(size_t firstN_/* = g_consumeDefaultAmount*/)
{
    return consume<TobiiResearchTimeSynchronizationData>(firstN_);
}
std::vector<TobiiResearchTimeSynchronizationData> TobiiBuffer::peekTimeSyncs(size_t lastN_/* = g_peekDefaultAmount*/)
{
    return peek<TobiiResearchTimeSynchronizationData>(lastN_);
}


// logging
namespace TobiiBuff
{
    bool startLogging(size_t initialBufferSize_ /*= g_logBufDefaultSize*/)
    {
        if (!g_logMessages)
            g_logMessages = std::make_unique<std::vector<TobiiBuff::logMessage>>();
        
        auto l = lockForWriting<TobiiBuff::logMessage>();
        g_logMessages.get()->reserve(initialBufferSize_);
        return tobii_research_logging_subscribe(TobiiLogCallback) == TOBII_RESEARCH_STATUS_OK;
    }
    std::vector<TobiiBuff::logMessage> getLog(bool clearLog_ /*= g_logBufClearDefault*/)
    {
        auto l = lockForWriting<TobiiBuff::logMessage>();
        if (clearLog_)
            return std::vector<TobiiBuff::logMessage>(std::move(*g_logMessages.get()));
        else
            // provide a copy
            return std::vector<TobiiBuff::logMessage>(*g_logMessages.get());
    }
    bool stopLogging()
    {
        return tobii_research_logging_unsubscribe() == TOBII_RESEARCH_STATUS_OK;
    }
}