#include "TobiiBuffer/TobiiBuffer.h"
#include <vector>
#include <shared_mutex>
#include <algorithm>
#include <string_view>
#include <sstream>
#include <map>

#include "TobiiBuffer/utils.h"

namespace
{
    using mutex_type = std::shared_timed_mutex;
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

    // default argument values
    namespace defaults
    {
        constexpr size_t  sampleBufSize = 1 << 20;     // about half an hour at 600Hz

        constexpr size_t  eyeImageBufSize = 1 << 12;   // about seven minutes at 2*5Hz
        constexpr bool    eyeImageAsGIF = false;

        constexpr size_t  extSignalBufSize = 1 << 10;

        constexpr size_t  timeSyncBufSize = 1 << 10;

        constexpr int64_t clearTimeRangeStart = 0;
        constexpr int64_t clearTimeRangeEnd = std::numeric_limits<int64_t>::max();

        constexpr bool    stopBufferEmpties = false;
        constexpr size_t  consumeAmount = -1;
        constexpr int64_t consumeTimeRangeStart = 0;
        constexpr int64_t consumeTimeRangeEnd = std::numeric_limits<int64_t>::max();
        constexpr size_t  peekAmount = 1;
        constexpr int64_t peekTimeRangeStart = 0;
        constexpr int64_t peekTimeRangeEnd = std::numeric_limits<int64_t>::max();

        constexpr size_t  logBufSize = 1 << 9;
        constexpr bool    logBufClear = true;
    }
}

TobiiBuffer::DataStream TobiiBuffer::stringToDataStream(std::string stream_)
{
    if (dataStreamMap.count(stream_) == 0)
    {
        std::stringstream os;
        os << "Unrecognized data stream (not in dataStreamMap): \"" << stream_ << "\"";
        DoExitWithMsg(os.str());
    }
    return dataStreamMap.at(stream_);
}

// logging static functions and member
std::unique_ptr<std::vector<TobiiBuffer::logMessage>> TobiiBuffer::_logMessages;
bool TobiiBuffer::startLogging(std::optional<size_t> initialBufferSize_)
{
    // deal with default arguments
    if (!initialBufferSize_)
        initialBufferSize_ = defaults::logBufSize;

    auto l = lockForWriting<logMessage>();
    _logMessages->reserve(*initialBufferSize_);
    return tobii_research_logging_subscribe(TobiiLogCallback) == TOBII_RESEARCH_STATUS_OK;
}
std::vector<TobiiBuffer::logMessage> TobiiBuffer::getLog(std::optional<bool> clearLog_)
{
    // deal with default arguments
    if (!clearLog_)
        clearLog_ = defaults::logBufClear;

    auto l = lockForWriting<logMessage>();
    if (*clearLog_)
        return std::vector<logMessage>(std::move(*_logMessages));
    else
        // provide a copy
        return std::vector<logMessage>(*_logMessages);
}
bool TobiiBuffer::stopLogging()
{
    return tobii_research_logging_unsubscribe() == TOBII_RESEARCH_STATUS_OK;
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
    auto l = lockForWriting<TobiiBuffer::logMessage>();
    TobiiBuffer::_logMessages->emplace_back(system_time_stamp_, source_, level_, message_);
}

namespace
{
    // eye image helpers
    bool doSubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, TobiiBuffer* instance_, bool asGif_)
    {
        if (asGif_)
            return tobii_research_subscribe_to_eye_image_as_gif(eyetracker_, TobiiEyeImageGifCallback, instance_) == TOBII_RESEARCH_STATUS_OK;
        else
            return tobii_research_subscribe_to_eye_image       (eyetracker_,    TobiiEyeImageCallback, instance_) == TOBII_RESEARCH_STATUS_OK;
    }
    bool doUnsubscribeEyeImage(TobiiResearchEyeTracker* eyetracker_, bool isGif_)
    {
        if (isGif_)
            return tobii_research_unsubscribe_from_eye_image_as_gif(eyetracker_, TobiiEyeImageGifCallback) == TOBII_RESEARCH_STATUS_OK;
        else
            return tobii_research_unsubscribe_from_eye_image       (eyetracker_,    TobiiEyeImageCallback) == TOBII_RESEARCH_STATUS_OK;
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
    stop(DataStream::Sample,    true);
    stop(DataStream::EyeImage,  true);
    stop(DataStream::ExtSignal, true);
    stop(DataStream::TimeSync,  true);
    stopLogging();
}


// helpers to make the below generic
template <typename T>
std::vector<T>& TobiiBuffer::getBuffer()
{
    if constexpr (std::is_same_v<T, sample>)
        return _samples;
    if constexpr (std::is_same_v<T, eyeImage>)
        return _eyeImages;
    if constexpr (std::is_same_v<T, extSignal>)
        return _extSignal;
    if constexpr (std::is_same_v<T, timeSync>)
        return _timeSync;
}
template <typename T>
std::tuple<typename std::vector<T>::iterator, typename std::vector<T>::iterator, bool>
TobiiBuffer::getIteratorsFromTimeRange(int64_t timeStart_, int64_t timeEnd_)
{
    // !NB: appropriate locking is responsibility of caller!
    // find elements within given range of time stamps, both sides inclusive.
    // Since returns are iterators, what is returned is first matching element until one past last matching element
    // 1. get buffer to traverse, if empty, return
    auto& buf    = getBuffer<T>();
    auto startIt = std::begin(buf);
    auto   endIt = std::end(buf);
    if (std::empty(buf))
        return {startIt,endIt, true};

    // 2. see which member variable to access
    int64_t T::* field;
    if constexpr (std::is_same_v<T, timeSync>)
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
    return {startIt,endIt, inclFirst&&inclLast};
}

bool TobiiBuffer::start(std::string stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
{
    return start(stringToDataStream(stream_), initialBufferSize_, asGif_);
}
bool TobiiBuffer::start(DataStream  stream_, std::optional<size_t> initialBufferSize_, std::optional<bool> asGif_)
{
    bool success = false;
    switch (stream_)
    {
        case DataStream::Sample:
        {
            // deal with default arguments
            if (!initialBufferSize_)
                initialBufferSize_ = defaults::sampleBufSize;
            // prepare and start buffer
            auto l = lockForWriting<sample>();
            _samples.reserve(*initialBufferSize_);
            success = tobii_research_subscribe_to_gaze_data(_eyetracker, TobiiSampleCallback, this) == TOBII_RESEARCH_STATUS_OK;
            break;
        }
        case DataStream::EyeImage:
        {
            // deal with default arguments
            if (!initialBufferSize_)
                initialBufferSize_ = defaults::eyeImageBufSize;
            if (!asGif_)
                asGif_ = defaults::eyeImageAsGIF;

            // prepare and start buffer
            auto l = lockForWriting<eyeImage>();
            _eyeImages.reserve(*initialBufferSize_);

            // if already recording and switching from gif to normal or other way, first stop old stream
            if (_recordingEyeImages)
                if (*asGif_ != _eyeImIsGif)
                    doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
                else
                    // nothing to do
                    return true;

            // subscribe to new stream
            _recordingEyeImages = doSubscribeEyeImage(_eyetracker, this, *asGif_);
            if (_recordingEyeImages)
                // update type being recorded if subscription to stream was successful
                _eyeImIsGif = *asGif_;
            success = _recordingEyeImages;
            break;
        }
        case DataStream::ExtSignal:
        {
            // deal with default arguments
            if (!initialBufferSize_)
                initialBufferSize_ = defaults::extSignalBufSize;
            // prepare and start buffer
            auto l = lockForWriting<extSignal>();
            _extSignal.reserve(*initialBufferSize_);
            success = tobii_research_subscribe_to_external_signal_data(_eyetracker, TobiiExtSignalCallback, this) == TOBII_RESEARCH_STATUS_OK;
            break;
        }
        case DataStream::TimeSync:
        {
            // deal with default arguments
            if (!initialBufferSize_)
                initialBufferSize_ = defaults::timeSyncBufSize;
            // prepare and start buffer
            auto l = lockForWriting<timeSync>();
            _timeSync.reserve(*initialBufferSize_);
            success = tobii_research_subscribe_to_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback, this) == TOBII_RESEARCH_STATUS_OK;
            break;
        }
    }

    return success;
}

template <typename T>
std::vector<T> consumeFromVec(std::vector<T>& buf_, typename std::vector<T>::iterator startIt_, typename std::vector<T>::iterator endIt_)
{
    if (std::empty(buf_))
        return std::vector<T>{};

    // move out the indicated elements
    bool whole = startIt_ == std::begin(buf_) && endIt_ == std::end(buf_);
    if (whole)
        return std::vector<T>(std::move(buf_));
    else
    {
        std::vector<T> out;
        out.reserve(std::distance(startIt_, endIt_));
        out.insert(std::end(out), std::make_move_iterator(startIt_), std::make_move_iterator(endIt_));
        buf_.erase(startIt_, endIt_);
        return out;
    }
}
template <typename T>
std::vector<T> TobiiBuffer::consumeN(std::optional<size_t> firstN_)
{
    // deal with default arguments
    if (!firstN_)
        firstN_ = defaults::peekAmount;

    auto l = lockForWriting<T>();

    auto& buf    = getBuffer<T>();
    auto startIt = std::begin(buf);
    auto   endIt = std::next(startIt, std::min(*firstN_, std::size(buf)));

    return consumeFromVec(buf, startIt, endIt);
}
template <typename T>
std::vector<T> TobiiBuffer::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    if (!timeStart_)
        timeStart_ = defaults::consumeTimeRangeStart;
    if (!timeEnd_)
        timeEnd_ = defaults::consumeTimeRangeEnd;

    auto l = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer<T>();

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<T>(*timeStart_, *timeEnd_);
    return consumeFromVec(buf, startIt, endIt);
}

template <typename T>
std::vector<T> peekFromVec(const std::vector<T>& buf_, typename const std::vector<T>::const_iterator startIt_, typename const std::vector<T>::const_iterator endIt_)
{
    if (std::empty(buf_))
        return std::vector<T>{};

    // copy the indicated elements
    return std::vector<T>(startIt_, endIt_);
}
template <typename T>
std::vector<T> TobiiBuffer::peekN(std::optional<size_t> lastN_)
{
    // deal with default arguments
    if (!lastN_)
        lastN_ = defaults::peekAmount;

    auto l = lockForReading<T>();

    auto& buf = getBuffer<T>();
    auto   endIt = std::end(buf);
    auto startIt = std::prev(endIt, std::min(*lastN_, std::size(buf)));

    return peekFromVec(buf, startIt,endIt);
}
template <typename T>
std::vector<T> TobiiBuffer::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    if (!timeStart_)
        timeStart_ = defaults::peekTimeRangeStart;
    if (!timeEnd_)
        timeEnd_ = defaults::peekTimeRangeEnd;

    auto l = lockForReading<T>();
    auto& buf = getBuffer<T>();

    auto [startIt, endIt, whole] = getIteratorsFromTimeRange<T>(*timeStart_, *timeEnd_);
    return peekFromVec(buf, startIt, endIt);
}

template <typename T>
void TobiiBuffer::clearImpl(int64_t timeStart_, int64_t timeEnd_)
{
    auto l = lockForWriting<T>(); // NB: if C++ std gains upgrade_lock, replace this with upgrade lock that is converted to unique lock only after range is determined
    auto& buf = getBuffer<T>();
    if (std::empty(buf))
        return;

    // find applicable range
    auto[start, end, whole] = getIteratorsFromTimeRange<T>(timeStart_, timeEnd_);
    // clear the flagged bit
    if (whole)
        buf.clear();
    else
        buf.erase(start, end);
}
void TobiiBuffer::clear(std::string stream_)
{
    clear(stringToDataStream(stream_));
}
void TobiiBuffer::clear(DataStream stream_)
{
    clearTimeRange(stream_);
}
void TobiiBuffer::clearTimeRange(std::string stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    clearTimeRange(stringToDataStream(stream_), timeStart_, timeEnd_);
}
void TobiiBuffer::clearTimeRange(DataStream stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
{
    // deal with default arguments
    if (!timeStart_)
        timeStart_ = defaults::clearTimeRangeStart;
    if (!timeEnd_)
        timeEnd_ = defaults::clearTimeRangeEnd;

    switch (stream_)
    {
        case DataStream::Sample:
            clearImpl<sample>(*timeStart_, *timeEnd_);
            break;
        case TobiiBuffer::DataStream::EyeImage:
            clearImpl<eyeImage>(*timeStart_, *timeEnd_);
            break;
        case TobiiBuffer::DataStream::ExtSignal:
            clearImpl<extSignal>(*timeStart_, *timeEnd_);
            break;
        case TobiiBuffer::DataStream::TimeSync:
            clearImpl<timeSync>(*timeStart_, *timeEnd_);
            break;
    }
}

bool TobiiBuffer::stop(std::string stream_, std::optional<bool> emptyBuffer_)
{
    return stop(stringToDataStream(stream_), emptyBuffer_);
}

bool TobiiBuffer::stop(DataStream  stream_, std::optional<bool> emptyBuffer_)
{
    // deal with default arguments
    if (!emptyBuffer_)
        emptyBuffer_ = defaults::stopBufferEmpties;

    bool success = false;
    switch (stream_)
    {
        case DataStream::Sample:
            success = tobii_research_unsubscribe_from_gaze_data(_eyetracker, TobiiSampleCallback) == TOBII_RESEARCH_STATUS_OK;
            break;
        case DataStream::EyeImage:
            success = doUnsubscribeEyeImage(_eyetracker, _eyeImIsGif);
            if (success)
                _recordingEyeImages = false;
            break;
        case DataStream::ExtSignal:
            success = tobii_research_unsubscribe_from_external_signal_data(_eyetracker, TobiiExtSignalCallback) == TOBII_RESEARCH_STATUS_OK;
            break;
        case DataStream::TimeSync:
            success = tobii_research_unsubscribe_from_time_synchronization_data(_eyetracker, TobiiTimeSyncCallback) == TOBII_RESEARCH_STATUS_OK;
            break;
    }

    if (*emptyBuffer_)
        clear(stream_);

    return success;
}

// gaze data, instantiate templated functions
template std::vector<TobiiBuffer::sample> TobiiBuffer::consumeN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::sample> TobiiBuffer::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiBuffer::sample> TobiiBuffer::peekN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::sample> TobiiBuffer::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);

// eye images, instantiate templated functions
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::consumeN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::peekN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::eyeImage> TobiiBuffer::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);


// external signals, instantiate templated functions
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::consumeN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::peekN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::extSignal> TobiiBuffer::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);


// time sync data, instantiate templated functions
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::consumeN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::consumeTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::peekN(std::optional<size_t> lastN_);
template std::vector<TobiiBuffer::timeSync> TobiiBuffer::peekTimeRange(std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_);
