// MEX wrapper for Tobii Pro SDK callbacks.
// based on class_wrapper_template.cpp
// "Example of using a C++ class via a MEX-file"
// by Jonathan Chappelow (chappjc)
// https://github.com/chappjc/MATLAB/
//
// chappjc notes:
// Design goals:
//   1. Manage multiple persistent instances of a C++ class
//   2. Small consecutive integer handles used in MATLAB (not cast pointers)
//   3. Transparently handle resource management (i.e. MATLAB never
//      responsible for memory allocated for C++ classes)
//       a. No memory leaked if MATLAB fails to issue "delete" action
//       b. Automatic deallocation if MEX-file prematurely unloaded
//   4. Guard against premature module unloading
//   5. Validity of handles implicitly verified without checking a magic number
//   6. No wrapper class or functions mimicking mexFunction, just an intuitive
//      switch-case block in mexFunction.
//
// Note that these goals should be acheved without regard to any MATLAB class,
// but which can also help address memory management issues.  As such, the
// resulting MEX-file can safely be used directly (but not too elegantly).
//
// Use:
//   1. Enumerate the different actions (e.g. New, Delete, Insert, etc.) in the
//      Actions enum.  For each enumerated action, specify a string (e.g.
//      "new", "delete", "insert", etc.) to be passed as the first argument to
//      the MEX function in MATLAB.
//   2. Customize the handling for each action in the switch statement in the
//      body of mexFunction (e.g. call the relevant C++ class method).
//
// Implementation:
//
// For your C++ class, class_type, mexFunction uses static data storage to hold
// a persistent (between calls to mexFunction) table of integer handles and
// smart pointers to dynamically allocated class instances.  A std::map is used
// for this purpose, which facilitates locating known handles, for which only
// valid instances of your class are guaranteed to exist:
//
//    typedef unsigned int handle_type;
//    std::map<handle_type, std::shared_ptr<class_type>>
//
// A std::shared_ptr takes care of deallocation when either (1) a table element
// is erased via the "delete" action or (2) the MEX-file is unloaded.
//
// To prevent the MEX-file from unloading while a MATLAB class instances exist,
// mexLock is called each time a new C++ class instance is created, adding to
// the MEX-file's lock count.  Each time a C++ instance is deleted mexUnlock is
// called, removing one lock from the lock count.

#include <vector>
#include <map>
#include <memory>
#include <string>
#include <sstream>
#include <atomic>

#define DLL_EXPORT_SYM __declspec(dllexport)
#include <mex.h>
#include "mex_type_utils.h"

#include "pack_utils.h"
#include "tobii_to_matlab.h"

#include "TobiiBuffer/TobiiBuffer.h"
#include "TobiiBuffer/utils.h"


namespace {
    using ClassType         = TobiiBuffer;
    using HandleType        = unsigned int;
    using InstancePtrType   = std::shared_ptr<ClassType>;
    using InstanceMapType   = std::map<HandleType, InstancePtrType>;

    // List actions
    enum class Action
    {
        Touch,
        New,
        Delete,

        HasStream,
        Start,
        IsBuffering,
        Clear,
        ClearTimeRange,
        Stop,
        ConsumeN,
        ConsumeTimeRange,
        PeekN,
        PeekTimeRange,

        StartLogging,
        GetLog,
        StopLogging
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "touch",				Action::Touch },
        { "new",				Action::New },
        { "delete",				Action::Delete },

        { "hasStream",          Action::HasStream },
        { "start",		        Action::Start },
        { "isBuffering",        Action::IsBuffering },
        { "clear",				Action::Clear },
        { "clearTimeRange",		Action::ClearTimeRange },
        { "stop",		        Action::Stop },
        { "consumeN",			Action::ConsumeN },
        { "consumeTimeRange",   Action::ConsumeTimeRange },
        { "peekN",				Action::PeekN },
        { "peekTimeRange",		Action::PeekTimeRange },

        { "startLogging",		Action::StartLogging },
        { "getLog",				Action::GetLog },
        { "stopLogging",		Action::StopLogging },
    };


    // table mapping handles to instances
    static InstanceMapType instanceTab;
    // for unique handles
    std::atomic<HandleType> handleVal = {0};

    // getHandle pulls the integer handle out of prhs[1]
    HandleType getHandle(int nrhs, const mxArray *prhs[])
    {
        if (nrhs < 2 || !mxIsScalar(prhs[1]))
            mexErrMsgTxt("Specify an instance with an integer handle.");
        return static_cast<HandleType>(mxGetScalar(prhs[1]));
    }

    // checkHandle gets the position in the instance table
    InstanceMapType::const_iterator checkHandle(const InstanceMapType& m, HandleType h)
    {
        auto it = m.find(h);
        if (it == m.end())
        {
            std::stringstream ss; ss << "No instance corresponding to handle " << h << " found.";
            mexErrMsgTxt(ss.str().c_str());
        }
        return it;
    }
}

// extend set of function to convert C++ data to matlab
namespace mxTypes
{
    // forward declare
    template<typename Cont, typename... Fs>
    typename std::enable_if_t<is_container_v<Cont>, mxArray*>
        FieldToMatlab(const Cont& data_, Fs... fields);
    mxArray* FieldToMatlab(const std::vector<TobiiResearchGazeData>& data_, TobiiResearchEyeData TobiiResearchGazeData::* field_);
    mxArray* ToMatlab(std::vector<TobiiResearchGazeData               > data_);
    mxArray* ToMatlab(std::vector<TobiiBuffer::eyeImage               > data_);
    mxArray* ToMatlab(std::vector<TobiiResearchExternalSignalData     > data_);
    mxArray* ToMatlab(std::vector<TobiiResearchTimeSynchronizationData> data_);
    mxArray* ToMatlab(std::vector<TobiiBuffer::logMessage             > data_);
}

MEXFUNCTION_LINKAGE void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs < 1 || !mxIsChar(prhs[0]))
        mexErrMsgTxt("First input must be an action string ('new', 'delete', or a method name).");

    // get action string
    char *actionCstr = mxArrayToString(prhs[0]);
    std::string actionStr(actionCstr);
    mxFree(actionCstr);

    // get corresponding action
    auto it = actionTypeMap.find(actionStr);
    if (it == actionTypeMap.end())
        mexErrMsgTxt(("Unrecognized action (not in actionTypeMap): " + actionStr).c_str());
    Action action = it->second;

    // If action is not "new" or others that don't require a handle, try to locate an existing instance based on input handle
    InstanceMapType::const_iterator instIt;
    InstancePtrType instance;
    if (action != Action::Touch && action != Action::New && action != Action::StartLogging && action != Action::GetLog && action != Action::StopLogging)
    {
        instIt = checkHandle(instanceTab, getHandle(nrhs, prhs));
        instance = instIt->second;
    }

    // execute action
    switch (action)
    {
        case Action::Touch:
            // no-op
            break;
        case Action::New:
        {
            if (nrhs < 2 || !mxIsChar(prhs[1]))
                mexErrMsgTxt("TobiiBuffer: Second argument must be a string.");

            char* address = mxArrayToString(prhs[1]);
            auto insResult = instanceTab.insert({++handleVal, std::make_shared<ClassType>(address)});
            mxFree(address);

            if (!insResult.second) // sanity check
                mexPrintf("Oh, bad news. Tried to add an existing handle."); // shouldn't ever happen
            else
                mexLock(); // add to the lock count

            // return the handle
            plhs[0] = mxCreateDoubleScalar(insResult.first->first);

            break;
        }
        case Action::Delete:
        {
            instanceTab.erase(instIt);
            mexUnlock();
            plhs[0] = mxCreateLogicalScalar(instanceTab.empty()); // info
            break;
        }

        case Action::HasStream:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("hasStream: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string, call hasStream() on instance
            char *bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->hasStream(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::Start:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("start: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get optional input arguments
            std::optional<uint64_t> bufSize;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsUint64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("start: Expected second argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[3]));
            }
            std::optional<bool> asGif;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!(mxIsDouble(prhs[4]) && !mxIsComplex(prhs[4]) && mxIsScalar(prhs[4])) && !mxIsLogicalScalar(prhs[4]))
                    mexErrMsgTxt("start: Expected third argument to be a logical scalar.");
                asGif = mxIsLogicalScalarTrue(prhs[4]);
            }

            // get data stream identifier string, call start() on instance
            char *bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->start(bufferCstr,bufSize,asGif));
            mxFree(bufferCstr);
            return;
        }
        case Action::IsBuffering:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("isBuffering: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string, call isBuffering() on instance
            char *bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->isBuffering(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::Clear:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("clear: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string, clear buffer
            char *bufferCstr = mxArrayToString(prhs[2]);
            instance->clear(bufferCstr);
            mxFree(bufferCstr);
            break;
        }
        case Action::ClearTimeRange:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("clearTimeRange: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsInt64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("clearTimeRange: Expected second argument to be a int64 scalar.");
                timeStart = *static_cast<int64_t*>(mxGetData(prhs[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsInt64(prhs[4]) || mxIsComplex(prhs[4]) || !mxIsScalar(prhs[4]))
                    mexErrMsgTxt("clearTimeRange: Expected third argument to be a int64 scalar.");
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs[4]));
            }

            // get data stream identifier string, clear buffer
            char *bufferCstr = mxArrayToString(prhs[2]);
            instance->clearTimeRange(bufferCstr,timeStart,timeEnd);
            mxFree(bufferCstr);
            break;
        }
        case Action::Stop:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("stop: first input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get optional input argument
            std::optional<bool> deleteBuffer;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!(mxIsDouble(prhs[3]) && !mxIsComplex(prhs[3]) && mxIsScalar(prhs[3])) && !mxIsLogicalScalar(prhs[3]))
                    mexErrMsgTxt("stop: Expected second argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[3]);
            }

            // get data stream identifier string, stop buffering
            char *bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->stop(bufferCstr,deleteBuffer));
            mxFree(bufferCstr);
            break;
        }
        case Action::ConsumeN:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("consumeN: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiBuffer::DataStream dataStream = instance->stringToDataStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input argument
            std::optional<uint64_t> nSamp;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsUint64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("consumeN: Expected second argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[3]));
            }

            switch (dataStream)
            {
                case TobiiBuffer::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiBuffer::gaze>(nSamp));
                    return;
                case TobiiBuffer::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiBuffer::eyeImage>(nSamp));
                    return;
                case TobiiBuffer::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiBuffer::extSignal>(nSamp));
                    return;
                case TobiiBuffer::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiBuffer::timeSync>(nSamp));
                    return;
            }
        }
        case Action::ConsumeTimeRange:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("consumeTimeRange: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiBuffer::DataStream dataStream = instance->stringToDataStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsInt64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("consumeTimeRange: Expected second argument to be a int64 scalar.");
                timeStart = *static_cast<int64_t*>(mxGetData(prhs[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsInt64(prhs[4]) || mxIsComplex(prhs[4]) || !mxIsScalar(prhs[4]))
                    mexErrMsgTxt("consumeTimeRange: Expected third argument to be a int64 scalar.");
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs[4]));
            }

            switch (dataStream)
            {
                case TobiiBuffer::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiBuffer::gaze>(timeStart, timeEnd));
                    return;
                case TobiiBuffer::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiBuffer::eyeImage>(timeStart, timeEnd));
                    return;
                case TobiiBuffer::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiBuffer::extSignal>(timeStart, timeEnd));
                    return;
                case TobiiBuffer::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiBuffer::timeSync>(timeStart, timeEnd));
                    return;
            }
        }
        case Action::PeekN:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("peekN: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiBuffer::DataStream dataStream = instance->stringToDataStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input argument
            std::optional<uint64_t> nSamp;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsUint64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("peekN: Expected second argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[3]));
            }

            switch (dataStream)
            {
                case TobiiBuffer::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiBuffer::gaze>(nSamp));
                    return;
                case TobiiBuffer::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiBuffer::eyeImage>(nSamp));
                    return;
                case TobiiBuffer::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiBuffer::extSignal>(nSamp));
                    return;
                case TobiiBuffer::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiBuffer::timeSync>(nSamp));
                    return;
            }
        }

        case Action::PeekTimeRange:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("peekTimeRange: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiBuffer::DataStream dataStream = instance->stringToDataStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsInt64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("peekTimeRange: Expected second argument to be a int64 scalar.");
                timeStart = *static_cast<int64_t*>(mxGetData(prhs[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsInt64(prhs[4]) || mxIsComplex(prhs[4]) || !mxIsScalar(prhs[4]))
                    mexErrMsgTxt("peekTimeRange: Expected third argument to be a int64 scalar.");
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs[4]));
            }

            switch (dataStream)
            {
                case TobiiBuffer::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiBuffer::gaze>(timeStart, timeEnd));
                    return;
                case TobiiBuffer::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiBuffer::eyeImage>(timeStart, timeEnd));
                    return;
                case TobiiBuffer::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiBuffer::extSignal>(timeStart, timeEnd));
                    return;
                case TobiiBuffer::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiBuffer::timeSync>(timeStart, timeEnd));
                    return;
            }
        }

        case Action::StartLogging:
        {
            // get optional input argument
            std::optional<uint64_t> bufSize;
            if (nrhs > 1 && !mxIsEmpty(prhs[1]))
            {
                if (!mxIsUint64(prhs[1]) || mxIsComplex(prhs[1]) || !mxIsScalar(prhs[1]))
                    mexErrMsgTxt("startLogging: Expected first argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[1]));
            }

            plhs[0] = mxCreateLogicalScalar(TobiiBuffer::startLogging(bufSize));
            return;
        }
        case Action::GetLog:
        {
            // get optional input argument
            std::optional<bool> clearBuffer;
            if (nrhs > 1 && !mxIsEmpty(prhs[1]))
            {
                if (!(mxIsDouble(prhs[1]) && !mxIsComplex(prhs[1]) && mxIsScalar(prhs[1])) && !mxIsLogicalScalar(prhs[1]))
                    mexErrMsgTxt("getLog: Expected first argument to be a logical scalar.");
                clearBuffer = mxIsLogicalScalarTrue(prhs[1]);
            }

            plhs[0] = mxTypes::ToMatlab(TobiiBuffer::getLog(clearBuffer));
            return;
        }
        case Action::StopLogging:
            plhs[0] = mxCreateLogicalScalar(TobiiBuffer::stopLogging());
            return;

        default:
            mexErrMsgTxt(("Unhandled action: " + actionStr).c_str());
            break;
    }
}


// helpers
namespace
{
    template <typename S, typename T, typename R>
    bool allEquals(const std::vector<S>& data_, T S::* field_, const R& ref_)
    {
        for (auto &frame : data_)
            if (frame.*field_ != ref_)
                return false;
        return true;
    }

    mxArray* eyeImagesToMatlab(const std::vector<TobiiBuffer::eyeImage>& data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].data_size;
        bool same = allEquals(data_, &TobiiBuffer::eyeImage::data_size, sz);
        // 2. then copy over the images to matlab
        mxArray* out;
        if (data_[0].bits_per_pixel + data_[0].padding_per_pixel != 8)
            mexErrMsgTxt("eyeImagesToMatlab: non-8bit images not yet implemented");
        if (same)
        {
            auto storage = static_cast<uint8_t*>(mxGetData(out = mxCreateUninitNumericMatrix(data_[0].width*data_[0].height, data_.size(), mxUINT8_CLASS, mxREAL)));
            size_t i = 0;
            for (auto &frame : data_)
                memcpy(storage + (i++)*sz, frame.data(), frame.data_size);
        }
        else
        {
            out = mxCreateCellMatrix(1, data_.size());
            size_t i = 0;
            for (auto &frame : data_)
            {
                mxArray* temp;
                auto storage = static_cast<uint8_t*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, frame.width*frame.height, mxUINT8_CLASS, mxREAL)));
                memcpy(storage, frame.data(), frame.data_size);
                mxSetCell(out, i++, temp);
            }
        }

        return out;
    }
}
namespace mxTypes
{
    // default output is storage type corresponding to the type of the member variable accessed through this function, but it can be overridden through type tag dispatch (see getFieldWrapper implementation)
    template<typename Cont, typename... Fs>
    typename std::enable_if_t<is_container_v<Cont>, mxArray*>
        FieldToMatlab(const Cont& data_, Fs... fields)
    {
        mxArray* temp;
        using V = typename Cont::value_type;
        // get type member variable accessed through the last pointer-to-member-variable in the parameter pack (this is not necessarily the last type in the parameter pack as that can also be the type tag if the user explicitly requested a return type)
        using retT = memVarType_t<std::conditional_t<std::is_member_object_pointer_v<last<V, Fs...>>, last<V, Fs...>, last<V, Fs..., 1>>>;
        // based on type, get number of rows for output
        constexpr auto numRows = getNumRows<retT>();

        size_t i = 0;
        if constexpr (numRows > 1)
        {
            // this is one of the 2D/3D point types
            // determine what return type we get
            // NB: appending extra field to access leads to wrong order if type tag was provided by user. getFieldWrapper detects this and corrects for it
            using U = decltype(mxTypes::getFieldWrapper(std::declval<V>(), fields..., &retT::x));
            auto storage = static_cast<U*>(mxGetData(temp = mxCreateUninitNumericMatrix(numRows, data_.size(), typeToMxClass<U>(), mxREAL)));
            for (auto &samp : data_)
            {
                storage[i++] = mxTypes::getFieldWrapper(samp, fields..., &retT::x);
                storage[i++] = mxTypes::getFieldWrapper(samp, fields..., &retT::y);
                if constexpr (numRows == 3)
                    storage[i++] = mxTypes::getFieldWrapper(samp, fields..., &retT::z);
            }
        }
        else
        {
            using U = decltype(mxTypes::getFieldWrapper(std::declval<V>(), fields...));
            auto storage = static_cast<U*>(mxGetData(temp = mxCreateUninitNumericMatrix(numRows, data_.size(), typeToMxClass<U>(), mxREAL)));
            for (auto &samp : data_)
                storage[i++] = mxTypes::getFieldWrapper(samp, fields...);
        }
        return temp;
    }

    mxArray* FieldToMatlab(const std::vector<TobiiResearchGazeData>& data_, TobiiResearchEyeData TobiiResearchGazeData::* field_)
    {
        const char* fieldNamesEye[] = {"gazePoint","pupil","gazeOrigin"};
        const char* fieldNamesGP[] = {"onDisplayArea","inUserCoords","valid"};
        const char* fieldNamesPup[] = {"diameter","valid"};
        const char* fieldNamesGO[] = {"inUserCoords","inTrackBoxCoords","valid"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNamesEye) / sizeof(*fieldNamesEye), fieldNamesEye);
        mxArray* temp;

        // 1. gazePoint
        mxSetFieldByNumber(out, 0, 0, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesGP) / sizeof(*fieldNamesGP), fieldNamesGP));
        // 1.1 gazePoint.onDisplayArea
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_point, &TobiiResearchGazePoint::position_on_display_area, 0.));					// 0. causes values to be stored as double
        // 1.2 gazePoint.inUserCoords
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_point, &TobiiResearchGazePoint::position_in_user_coordinates, 0.));				// 0. causes values to be stored as double
        // 1.3 gazePoint.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_point, &TobiiResearchGazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID));

        // 2. pupil
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesPup) / sizeof(*fieldNamesPup), fieldNamesPup));
        // 2.1 pupil.diameter
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeData::pupil_data, &TobiiResearchPupilData::diameter, 0.));									// 0. causes values to be stored as double
        // 2.2 pupil.validity
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, field_, &TobiiResearchEyeData::pupil_data, &TobiiResearchPupilData::validity, TOBII_RESEARCH_VALIDITY_VALID));

        // 3. gazePoint
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesGO) / sizeof(*fieldNamesGO), fieldNamesGO));
        // 3.1 gazeOrigin.inUserCoords
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_origin, &TobiiResearchGazeOrigin::position_in_user_coordinates, 0.));			// 0. causes values to be stored as double
        // 3.2 gazeOrigin.inTrackBoxCoords
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_origin, &TobiiResearchGazeOrigin::position_in_track_box_coordinates, 0.));		// 0. causes values to be stored as double
        // 3.3 gazeOrigin.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_origin, &TobiiResearchGazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID));

        return out;
    }

    mxArray* ToMatlab(std::vector<TobiiResearchGazeData> data_)
    {
        const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. all device timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchGazeData::device_time_stamp));
        // 2. all system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchGazeData::system_time_stamp));
        // 3. left  eye data
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiResearchGazeData::left_eye));
        // 4. right eye data
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, &TobiiResearchGazeData::right_eye));

        return out;
    }

    mxArray* ToMatlab(std::vector<TobiiBuffer::eyeImage> data_)
    {
        // check if all gif, then don't output unneeded fields
        bool allGif = allEquals(data_, &TobiiBuffer::eyeImage::isGif, true);

        // fieldnames for all structs
        mxArray* out;
        if (allGif)
        {
            const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","isCropped","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        }
        else
        {
            const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","bitsPerPixel","paddingPerPixel","width","height","isCropped","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        }

        // all simple fields
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiBuffer::eyeImage::device_time_stamp));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiBuffer::eyeImage::system_time_stamp));
        if (!allGif)
        {
            mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiBuffer::eyeImage::bits_per_pixel));
            mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, &TobiiBuffer::eyeImage::padding_per_pixel));
            mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, &TobiiBuffer::eyeImage::width, 0.));		// 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, &TobiiBuffer::eyeImage::height, 0.));		// 0. causes values to be stored as double
        }
        int off = 4 * (!allGif);
        mxSetFieldByNumber(out, 0, 2 + off, FieldToMatlab(data_, &TobiiBuffer::eyeImage::type, TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED));
        mxSetFieldByNumber(out, 0, 3 + off, FieldToMatlab(data_, &TobiiBuffer::eyeImage::camera_id));
        mxSetFieldByNumber(out, 0, 4 + off, FieldToMatlab(data_, &TobiiBuffer::eyeImage::isGif));
        mxSetFieldByNumber(out, 0, 5 + off, eyeImagesToMatlab(data_));

        return out;
    }


    mxArray* ToMatlab(std::vector<TobiiResearchExternalSignalData     > data_)
    {
        const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","value","changeType"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. device timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchExternalSignalData::device_time_stamp));
        // 2. system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchExternalSignalData::system_time_stamp));
        // 3. external signal values
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiResearchExternalSignalData::value));
        // 4. value change type
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, &TobiiResearchExternalSignalData::change_type, uint8_t{}));	// cast enum values

        return out;
    }
    mxArray* ToMatlab(std::vector<TobiiResearchTimeSynchronizationData> data_)
    {
        const char* fieldNames[] = {"systemRequestTimeStamp","deviceTimeStamp","systemResponseTimeStamp"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. system request timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchTimeSynchronizationData::system_request_time_stamp));
        // 2. device timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchTimeSynchronizationData::device_time_stamp));
        // 3. system response timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiResearchTimeSynchronizationData::system_response_time_stamp));

        return out;
    }

    mxArray* ToMatlab(std::vector<TobiiBuffer::logMessage> data_)
    {
        const char* fieldNames[] = {"systemTimeStamp","source","level","message"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);
        mxArray* temp;
        size_t i = 0;

        // 1. system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiBuffer::logMessage::system_time_stamp));
        // 2. log source
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateCellMatrix(data_.size(), 1));
        i = 0;
        for (auto &msg : data_)
            mxSetCell(temp, i++, mxCreateString(TobiiResearchLogSourceToString(msg.source).c_str()));
        // 3. log level
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateCellMatrix(data_.size(), 1));
        i = 0;
        for (auto &msg : data_)
            mxSetCell(temp, i++, mxCreateString(TobiiResearchLogLevelToString(msg.level).c_str()));
        // 4. log messages
        mxSetFieldByNumber(out, 0, 3, temp = mxCreateCellMatrix(data_.size(), 1));
        i = 0;
        for (auto &msg : data_)
            mxSetCell(temp, i++, mxCreateString(msg.message.c_str()));

        return out;
    }
}


// function for handling errors generated by lib
void DoExitWithMsg(std::string errMsg_)
{
    mexErrMsgTxt(errMsg_.c_str());
}