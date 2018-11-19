#include "TobiiBuffer/TobiiBuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>
#include <string_view>
#include <sstream>
#include <map>

#include "TobiiBuffer/utils.h"

namespace {
    using mutex_type = std::shared_timed_mutex ;
    using read_lock  = std::shared_lock<mutex_type>;
    using write_lock = std::unique_lock<mutex_type>;

    mutex_type g_mSamp, g_mEyeImage, g_mExtSignal, g_mTimeSync, g_mLog;

    template <typename T>
    read_lock  lockForReading() { return  read_lock(getMutex<T>()); }
    template <typename T>
    write_lock lockForWriting() { return write_lock(getMutex<T>()); }

    template <typename T>
    mutex_type& getMutex()
    {
        if constexpr (std::is_same_v<T, TobiiBuffer::sample>)
            return g_mSamp;
        if constexpr (std::is_same_v<T, TobiiBuffer::eyeImage>)
            return g_mEyeImage;
        if constexpr (std::is_same_v<T, TobiiBuffer::extSignal>)
            return g_mExtSignal;
        if constexpr (std::is_same_v<T, TobiiBuffer::timeSync>)
            return g_mTimeSync;
        if constexpr (std::is_same_v<T, TobiiBuffer::logMessage>)
            return g_mLog;
    }

    // global log buffer
    std::unique_ptr<std::vector<TobiiBuffer::logMessage>> g_logMessages;

    // deal with error messages
    inline void ErrorExit(std::string_view errMsg_, TobiiResearchStatus errCode_)
    {
        std::stringstream os;
        os << "TobiiBuffer Error: " << errMsg_ << std::endl;
        os << "Error code: " << static_cast<int>(errCode_) << ": " << TobiiResearchStatusToString(errCode_) << " (" << TobiiResearchStatusToExplanation(errCode_) << ")" << std::endl;

        DoExitWithMsg(os.str());
    }

    // Map string to an Data Stream
    const std::map<std::string, TobiiBuffer::DataStream> dataStreamMap =
    {
        { "sample",    TobiiBuffer::DataStream::Sample },
        { "eyeImage",  TobiiBuffer::DataStream::EyeImage },
        { "extSignal", TobiiBuffer::DataStream::ExtSignal },
        { "timeSync",  TobiiBuffer::DataStream::TimeSync }
    };
}

namespace TobiiBuff
{
    TobiiBuffer::DataStream stringToDataStream(std::string dataStream_)
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
        auto l = lockForWriting<TobiiBuffer::sample>();
        static_cast<TobiiBuffer*>(user_data)->_samples.push_back(*gaze_data_);
    }
}
void TobiiEyeImageCallback(TobiiResearchEyeImage* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiBuffer::eyeImage>();
        static_cast<TobiiBuffer*>(user_data)->_eyeImages.emplace_back(eye_image_);
    }
}
void TobiiEyeImageGifCallback(TobiiResearchEyeImageGif* eye_image_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiBuffer::eyeImage>();
        static_cast<TobiiBuffer*>(user_data)->_eyeImages.emplace_back(eye_image_);
    }
}
void TobiiExtSignalCallback(TobiiResearchExternalSignalData* ext_signal_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiBuffer::extSignal>();
        static_cast<TobiiBuffer*>(user_data)->_extSignal.push_back(*ext_signal_);
    }
}
void TobiiTimeSyncCallback(TobiiResearchTimeSynchronizationData* time_sync_data_, void* user_data)
{
    if (user_data)
    {
        auto l = lockForWriting<TobiiBuffer::timeSync>();
        static_cast<TobiiBuffer*>(user_data)->_timeSync.push_back(*time_sync_data_);
    }
}
void TobiiLogCallback(int64_t system_time_stamp_, TobiiResearchLogSource source_, TobiiResearchLogLevel level_, const char* message_)
{
    if (g_logMessages)
    {
        auto l = lockForWriting<TobiiBuffer::logMessage>();
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
    stopImpl<TobiiBuffer::sample>(true);
    stopImpl<TobiiBuffer::eyeImage>(true);
    stopImpl<TobiiBuffer::extSignal>(true);
    stopImpl<TobiiBuffer::timeSync>(true);
    TobiiBuff::stopLogging();
}


// helpers to make the below generic
template <typename T>
std::vector<T>& TobiiBuffer::getBuffer()
{
    if constexpr (std::is_same_v<T, TobiiBuffer::sample>)
        return _samples;
    if constexpr (std::is_same_v<T, TobiiBuffer::eyeImage>)
        return _eyeImages;
    if constexpr (std::is_same_v<T, TobiiBuffer::extSignal>)
        return _extSignal;
    if constexpr (std::is_same_v<T, TobiiBuffer::timeSync>)
        return _timeSync;
}
template <typename T>
std::tuple<bool, typename std::vector<T>::iterator, typename std::vector<T>::iterator>
TobiiBuffer::getBufferTimeRange(int64_t timeStart_, int64_t timeEnd_)
{
    // !NB: appropriate locking is responsibility of caller!
    // find elements within given range of time stamps, both sides inclusive.
    // Since returns are iterators, what is returned is first matching element until one past last matching element
    // 1. get buffer to traverse, if empty, return
    auto& buf    = getBuffer<T>();
    auto startIt = buf.begin();
    auto   endIt = buf.end();
    if (buf.empty())
        return {true,startIt,endIt};

    // 2. see which member variable to access
    int64_t T::* field;
    if constexpr (std::is_same_v<T, TobiiBuffer::timeSync>)
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
    return {inclFirst&&inclLast,startIt,endIt};
}
// generic functions
template <typename T>
void TobiiBuffer::clearImpl(int64_t timeStart_, int64_t timeEnd_)
{
    auto l    = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer<T>();
    if (buf.empty())
        return;

    // find applicable range
    auto [whole, start, end] = getBufferTimeRange<T>(timeStart_, timeEnd_);
    // clear the flagged bit
    if (whole)
        buf.clear();
    else
        buf.erase(start, end);
}
template <typename T>
bool TobiiBuffer::stopImpl(bool emptyBuffer_)
{
    bool success = false;
    if constexpr (std::is_same_v<T, TobiiBuffer::sample>)
    {
        success = tobii_research_unsubscribe_from_gaze_data(_eyetracker, TobiiSampleCallback) == TOBII_RESEARCH_STATUS_OK;
    }
    if constexpr (std::is_same_v<T, TobiiBuffer::eyeImage>)
    {
        success = doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
        _recordingEyeImages = false;
    }
    if constexpr (std::is_same_v<T, TobiiBuffer::extSignal>)
    {
        success = tobii_research_unsubscribe_from_external_signal_data(_eyetracker, TobiiExtSignalCallback) == TOBII_RESEARCH_STATUS_OK;
    }
    if constexpr (std::is_same_v<T, TobiiBuffer::timeSync>)
    {
        success = tobii_research_unsubscribe_from_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback) == TOBII_RESEARCH_STATUS_OK;
    }

    if (emptyBuffer_)
        clearImpl<T>(TobiiBuff::g_clearTimeRangeStart, TobiiBuff::g_clearTimeRangeEnd);

    return success;
}
template <typename T>
std::vector<T> TobiiBuffer::consumeN(size_t firstN_ /*= TobiiBuff::g_consumeDefaultAmount*/)
{
    auto l    = lockForWriting<T>();
    auto& buf = getBuffer<T>();

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
template <typename T>
std::vector<T> TobiiBuffer::consumeTimeRange(int64_t timeStart_ /*= TobiiBuff::g_consumeTimeRangeStart*/, int64_t timeEnd_ /*= TobiiBuff::g_consumeTimeRangeEnd*/)
{
    auto l    = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer<T>();
    if (buf.empty())
        return std::vector<T>{};

    // find applicable range
    auto [whole, start, end] = getBufferTimeRange<T>(timeStart_, timeEnd_);
    // move out the indicated elements
    if (whole)
        return std::vector<T>(std::move(buf));
    else
    {
        std::vector<T> out;
        out.reserve(std::distance(start,end));
        out.insert(out.end(), std::make_move_iterator(start), std::make_move_iterator(end));
        buf.erase(start, end);
        return out;
    }
}
template <typename T>
std::vector<T> TobiiBuffer::peekN(size_t lastN_ /*= TobiiBuff::g_peekDefaultAmount*/)
{
    auto l    = lockForReading<T>();
    auto& buf = getBuffer<T>();
    // copy last N or whole vector if less than N elements available
    return std::vector<T>(buf.end() - std::min(buf.size(), lastN_), buf.end());
}
template <typename T>
std::vector<T> TobiiBuffer::peekTimeRange(int64_t timeStart_ /*= TobiiBuff::g_peekTimeRangeStart*/, int64_t timeEnd_ /*= TobiiBuff::g_peekTimeRangeEnd*/)
{
    auto l    = lockForReading<T>();
    auto& buf = getBuffer<T>();
    if (buf.empty())
        return std::vector<T>{};

    // find applicable range
    auto [whole, start, end] = getBufferTimeRange<T>(timeStart_, timeEnd_);
    // copy the indicated elements
    return std::vector<T>(start, end);
}

// functions taking buffer type as input
void TobiiBuffer::clear(std::string dataStream_)
{
    clearTimeRange(dataStream_,TobiiBuff::g_clearTimeRangeStart, TobiiBuff::g_clearTimeRangeEnd);
}
void TobiiBuffer::clearTimeRange(std::string dataStream_, int64_t timeStart_ /*= TobiiBuff::g_clearTimeRangeStart*/, int64_t timeEnd_ /*= TobiiBuff::g_clearTimeRangeEnd*/)
{
    // get corresponding data stream
    TobiiBuffer::DataStream stream = TobiiBuff::stringToDataStream(dataStream_);

    // now clear that buffer
    switch (stream)
    {
        case TobiiBuffer::DataStream::Sample:
            clearImpl<TobiiBuffer::sample>(timeStart_, timeEnd_);
            break;
        case TobiiBuffer::DataStream::EyeImage:
            clearImpl<TobiiBuffer::eyeImage>(timeStart_, timeEnd_);
            break;
        case TobiiBuffer::DataStream::ExtSignal:
            clearImpl<TobiiBuffer::extSignal>(timeStart_, timeEnd_);
            break;
        case TobiiBuffer::DataStream::TimeSync:
            clearImpl<TobiiBuffer::timeSync>(timeStart_, timeEnd_);
            break;
    }
}
bool TobiiBuffer::stop(std::string dataStream_, bool emptyBuffer_ /*= TobiiBuff::g_stopBufferEmptiesDefault*/)
{
    // get corresponding data stream
    TobiiBuffer::DataStream stream = TobiiBuff::stringToDataStream(dataStream_);

    // now clear that buffer
    bool out = false;
    switch (stream)
    {
        case TobiiBuffer::DataStream::Sample:
            out = stopImpl<TobiiBuffer::sample>(emptyBuffer_);
            break;
        case TobiiBuffer::DataStream::EyeImage:
            out = stopImpl<TobiiBuff::eyeImage>(emptyBuffer_);
            break;
        case TobiiBuffer::DataStream::ExtSignal:
            out = stopImpl<TobiiBuffer::extSignal>(emptyBuffer_);
            break;
        case TobiiBuffer::DataStream::TimeSync:
            out = stopImpl<TobiiBuffer::timeSync>(emptyBuffer_);
            break;
    }
    return out;
}

// gaze data
bool TobiiBuffer::startSample(size_t initialBufferSize_ /*= g_sampleBufDefaultSize*/)
{
    auto l = lockForWriting<TobiiBuffer::sample>();
    _samples.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_gaze_data(_eyetracker,TobiiSampleCallback,this) == TOBII_RESEARCH_STATUS_OK;
}
// instantiate templated functions
template std::vector<TobiiBuffer::sample> TobiiBuffer::consumeN(size_t lastN_);
template std::vector<TobiiBuffer::sample> TobiiBuffer::consumeTimeRange(int64_t timeStart_, int64_t timeEnd_);
template std::vector<TobiiBuffer::sample> TobiiBuffer::peekN(size_t lastN_);
template std::vector<TobiiBuffer::sample> TobiiBuffer::peekTimeRange(int64_t timeStart_, int64_t timeEnd_);



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
    auto l = lockForWriting<TobiiBuffer::eyeImage>();
    _eyeImages.reserve(initialBufferSize_);

    // if already recording and switching from gif to normal or other way, first stop old stream
    if (_recordingEyeImages)
        if (asGif_ != _eyeImIsGif)
            doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
        else
            // nothing to do
            return true;

    // subscribe to new stream
    _recordingEyeImages = doSubscribeEyeImage(_eyetracker, this, asGif_);
    _eyeImIsGif = _recordingEyeImages ? asGif_ : _eyeImIsGif;	// update type being recorded if subscription to stream was successful
    return _recordingEyeImages;
}
// instantiate templated functions
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::consumeN(size_t lastN_);
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::consumeTimeRange(int64_t timeStart_, int64_t timeEnd_);
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::peekN(size_t lastN_);
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::peekTimeRange(int64_t timeStart_, int64_t timeEnd_);


// external signals
bool TobiiBuffer::startExtSignal(size_t initialBufferSize_ /*= g_extSignalBufDefaultSize*/)
{
    auto l = lockForWriting<TobiiBuffer::extSignal>();
    _extSignal.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_external_signal_data(_eyetracker, TobiiExtSignalCallback, this) == TOBII_RESEARCH_STATUS_OK;
}
// instantiate templated functions
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::consumeN(size_t lastN_);
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::consumeTimeRange(int64_t timeStart_, int64_t timeEnd_);
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::peekN(size_t lastN_);
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::peekTimeRange(int64_t timeStart_, int64_t timeEnd_);


// time sync data
bool TobiiBuffer::startTimeSync(size_t initialBufferSize_ /*= g_timeSyncBufDefaultSize*/)
{
    auto l = lockForWriting<TobiiBuffer::timeSync>();
    _timeSync.reserve(initialBufferSize_);
    return tobii_research_subscribe_to_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback, this) == TOBII_RESEARCH_STATUS_OK;
}
// instantiate templated functions
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::consumeN(size_t lastN_);
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::consumeTimeRange(int64_t timeStart_, int64_t timeEnd_);
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::peekN(size_t lastN_);
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::peekTimeRange(int64_t timeStart_, int64_t timeEnd_);


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