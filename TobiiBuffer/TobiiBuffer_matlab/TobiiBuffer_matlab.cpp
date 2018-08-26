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
#include <tuple>
#include <type_traits>

#define DLL_EXPORT_SYM __declspec(dllexport)
#include "mex.h"


// The class to wrap
#include "TobiiBuffer/TobiiBuffer.h"
#pragma comment(lib, "TobiiBuffer.lib")


namespace {
    typedef TobiiBuffer class_type;
    typedef unsigned int handle_type;
    typedef std::pair<handle_type, std::shared_ptr<class_type>> indPtrPair_type;
    typedef std::map<indPtrPair_type::first_type, indPtrPair_type::second_type> instanceMap_type;
    typedef indPtrPair_type::second_type instPtr_t;

    // List actions
    enum class Action
    {
        New,
        Delete,

        StartSampleBuffering,
        EnableTempSampleBuffer,
        DisableTempSampleBuffer,
        ClearSampleBuffer,
        StopSampleBuffering,
        ConsumeSamples,
        PeekSamples,

        StartEyeImageBuffering,
        EnableTempEyeImageBuffer,
        DisableTempEyeImageBuffer,
        ClearEyeImageBuffer,
        StopEyeImageBuffering,
        ConsumeEyeImages,
        PeekEyeImages,

        StartExtSignalBuffering,
        EnableTempExtSignalBuffer,
        DisableTempExtSignalBuffer,
        ClearExtSignalBuffer,
        StopExtSignalBuffering,
        ConsumeExtSignals,
        PeekExtSignals,

        StartTimeSyncBuffering,
        EnableTempTimeSyncBuffer,
        DisableTempTimeSyncBuffer,
        ClearTimeSyncBuffer,
        StopTimeSyncBuffering,
        ConsumeTimeSyncs,
        PeekTimeSyncs
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "new",						Action::New },
        { "delete",						Action::Delete },

        { "startSampleBuffering",		Action::StartSampleBuffering },
        { "enableTempSampleBuffer",		Action::EnableTempSampleBuffer },
        { "disableTempSampleBuffer",	Action::DisableTempSampleBuffer },
        { "clearSampleBuffer",			Action::ClearSampleBuffer },
        { "stopSampleBuffering",		Action::StopSampleBuffering },
        { "consumeSamples",				Action::ConsumeSamples },
        { "peekSamples",				Action::PeekSamples },

        { "startEyeImageBuffering",		Action::StartEyeImageBuffering },
        { "enableTempEyeImageBuffer",	Action::EnableTempEyeImageBuffer },
        { "disableTempEyeImageBuffer",	Action::DisableTempEyeImageBuffer },
        { "clearEyeImageBuffer",		Action::ClearEyeImageBuffer },
        { "stopEyeImageBuffering",		Action::StopEyeImageBuffering },
        { "consumeEyeImages",			Action::ConsumeEyeImages },
        { "peekEyeImages",				Action::PeekEyeImages },

        { "startExtSignalBuffering",	Action::StartExtSignalBuffering },
        { "enableTempExtSignalBuffer",	Action::EnableTempExtSignalBuffer },
        { "disableTempExtSignalBuffer",	Action::DisableTempExtSignalBuffer },
        { "clearExtSignalBuffer",		Action::ClearExtSignalBuffer },
        { "stopExtSignalBuffering",		Action::StopExtSignalBuffering },
        { "consumeExtSignals",			Action::ConsumeExtSignals },
        { "peekExtSignals",				Action::PeekExtSignals },

        { "startTimeSyncBuffering",		Action::StartTimeSyncBuffering },
        { "enableTempTimeSyncBuffer",	Action::EnableTempTimeSyncBuffer },
        { "disableTempTimeSyncBuffer",	Action::DisableTempTimeSyncBuffer },
        { "clearTimeSyncBuffer",		Action::ClearTimeSyncBuffer },
        { "stopTimeSyncBuffering",		Action::StopTimeSyncBuffering },
        { "consumeTimeSyncs",			Action::ConsumeTimeSyncs },
        { "peekTimeSyncs",				Action::PeekTimeSyncs },
    };



    // table mapping handles to instances
    static instanceMap_type instanceTab;
    // for unique handles
    std::atomic<handle_type> handleVal = {0};

    // getHandle pulls the integer handle out of prhs[1]
    handle_type getHandle(int nrhs, const mxArray *prhs[])
    {
        if (nrhs < 2 || !mxIsScalar(prhs[1]))
            mexErrMsgTxt("Specify an instance with an integer handle.");
        return static_cast<handle_type>(mxGetScalar(prhs[1]));
    }

    // checkHandle gets the position in the instance table
    instanceMap_type::const_iterator checkHandle(const instanceMap_type& m, handle_type h)
    {
        auto it = m.find(h);
        if (it == m.end())
        {
            std::stringstream ss; ss << "No instance corresponding to handle " << h << " found.";
            mexErrMsgTxt(ss.str().c_str());
        }
        return it;
    }

    // forward declare
    mxArray*    SampleVectorToMatlab(std::vector<TobiiResearchGazeData               > data_);
    mxArray*  EyeImageVectorToMatlab(std::vector<TobiiBuff::eyeImage                 > data_);
    mxArray* ExtSignalVectorToMatlab(std::vector<TobiiResearchExternalSignalData     > data_);
    mxArray*  TimeSyncVectorToMatlab(std::vector<TobiiResearchTimeSynchronizationData> data_);
}

void DLL_EXPORT_SYM mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs < 1 || !mxIsChar(prhs[0]))
        mexErrMsgTxt("First input must be an action string ('new', 'delete', or a method name).");

    // get action string
    char *actionCstr = mxArrayToString(prhs[0]); // convert char16_t to char
    std::string actionStr(actionCstr);
    mxFree(actionCstr);

    // get corresponding action
    if (actionTypeMap.count(actionStr) == 0)
        mexErrMsgTxt(("Unrecognized action (not in actionTypeMap): " + actionStr).c_str());
    Action action = actionTypeMap.at(actionStr);

    // If action is not "new" or "delete", try to locate an existing instance based on input handle
    instPtr_t instance;
    if (action != Action::New && action != Action::Delete)
    {
        auto instIt = checkHandle(instanceTab, getHandle(nrhs, prhs));
        instance = instIt->second;
    }

    // execute action
    switch (action)
    {
        case Action::New:
        {
            if (nrhs < 2 || !mxIsChar(prhs[1]))
                mexErrMsgTxt("TobiiBuffer: Second argument must be a string.");

            char* address = mxArrayToString(prhs[1]);
            auto insResult = instanceTab.insert(indPtrPair_type(++handleVal, std::make_shared<class_type>(address)));
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
            auto instIt = checkHandle(instanceTab, getHandle(nrhs, prhs));
            instanceTab.erase(instIt);
            mexUnlock();
            plhs[0] = mxCreateLogicalScalar(instanceTab.empty()); // info
            break;
        }

        case Action::StartSampleBuffering:
        {
            uint64_t bufSize = TobiiBuff::g_sampleBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startSampleBuffering: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = mxCreateLogicalScalar(instance->startSampleBuffering(bufSize));
            return;
        }
        case Action::EnableTempSampleBuffer:
        {
            uint64_t bufSize = TobiiBuff::g_sampleTempBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("enableTempSampleBuffer: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            instance->startSampleBuffering(bufSize);
            return;
        }
        case Action::DisableTempSampleBuffer:
            instance->disableTempSampleBuffer();
            return;
        case Action::ClearSampleBuffer:
            instance->clearSampleBuffer();
            return;
        case Action::StopSampleBuffering:
        {
            bool deleteBuffer = TobiiBuff::g_stopBufferEmptiesDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                    mexErrMsgTxt("stopSampleBuffering: Expected argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            }

            instance->stopSampleBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeSamples:
        {
            uint64_t nSamp = TobiiBuff::g_consumeDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("consumeSamples: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = SampleVectorToMatlab(instance->consumeSamples(nSamp));
            return;
        }
        case Action::PeekSamples:
        {
            uint64_t nSamp = TobiiBuff::g_peekDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("peekSamples: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = SampleVectorToMatlab(instance->peekSamples(nSamp));
            return;
        }

        case Action::StartEyeImageBuffering:
        {
            uint64_t bufSize = TobiiBuff::g_eyeImageBufDefaultSize;
            bool asGif = TobiiBuff::g_eyeImageAsGIFDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startEyeImageBuffering: Expected first argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsLogical(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    mexErrMsgTxt("startEyeImageBuffering: Expected second argument to be a logical scalar.");
                asGif = mxIsLogicalScalarTrue(prhs[2]);
            }
            plhs[0] = mxCreateLogicalScalar(instance->startEyeImageBuffering(bufSize, asGif));
            return;
        }
        case Action::EnableTempEyeImageBuffer:
        {
            uint64_t bufSize = TobiiBuff::g_eyeImageTempBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("enableTempEyeImageBuffer: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            instance->enableTempEyeImageBuffer(bufSize);
            return;
        }
        case Action::DisableTempEyeImageBuffer:
            instance->disableTempEyeImageBuffer();
            return;
        case Action::ClearEyeImageBuffer:
            instance->clearEyeImageBuffer();
            return;
        case Action::StopEyeImageBuffering:
        {
            bool deleteBuffer = TobiiBuff::g_stopBufferEmptiesDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                    mexErrMsgTxt("stopEyeImageBuffering: Expected argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            }

            instance->stopEyeImageBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeEyeImages:
        {
            uint64_t nSamp = TobiiBuff::g_consumeDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("consumeEyeImages: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = EyeImageVectorToMatlab(instance->consumeEyeImages(nSamp));
            return;
        }
        case Action::PeekEyeImages:
        {
            uint64_t nSamp = TobiiBuff::g_peekDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("peekEyeImages: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = EyeImageVectorToMatlab(instance->peekEyeImages(nSamp));
            return;
        }

        case Action::StartExtSignalBuffering:
        {
            uint64_t bufSize = TobiiBuff::g_extSignalBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startExtSignalBuffering: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = mxCreateLogicalScalar(instance->startExtSignalBuffering(bufSize));
            return;
        }
        case Action::EnableTempExtSignalBuffer:
        {
            uint64_t bufSize = TobiiBuff::g_extSignalTempBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("enableTempExtSignalBuffer: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            instance->startExtSignalBuffering(bufSize);
            return;
        }
        case Action::DisableTempExtSignalBuffer:
            instance->disableTempExtSignalBuffer();
            return;
        case Action::ClearExtSignalBuffer:
            instance->clearExtSignalBuffer();
            return;
        case Action::StopExtSignalBuffering:
        {
            bool deleteBuffer = TobiiBuff::g_stopBufferEmptiesDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                    mexErrMsgTxt("stopExtSignalBuffering: Expected argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            }

            instance->stopExtSignalBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeExtSignals:
        {
            uint64_t nSamp = TobiiBuff::g_consumeDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("consumeExtSignals: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = ExtSignalVectorToMatlab(instance->consumeExtSignals(nSamp));
            return;
        }
        case Action::PeekExtSignals:
        {
            uint64_t nSamp = TobiiBuff::g_peekDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("peekExtSignals: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = ExtSignalVectorToMatlab(instance->peekExtSignals(nSamp));
            return;
        }

        case Action::StartTimeSyncBuffering:
        {
            uint64_t bufSize = TobiiBuff::g_timeSyncBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("startTimeSyncBuffering: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = mxCreateLogicalScalar(instance->startTimeSyncBuffering(bufSize));
            return;
        }
        case Action::EnableTempTimeSyncBuffer:
        {
            uint64_t bufSize = TobiiBuff::g_timeSyncTempBufDefaultSize;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("enableTempTimeSyncBuffer: Expected argument to be a uint64 scalar.");
                bufSize = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            instance->startTimeSyncBuffering(bufSize);
            return;
        }
        case Action::DisableTempTimeSyncBuffer:
            instance->disableTempTimeSyncBuffer();
            return;
        case Action::ClearTimeSyncBuffer:
            instance->clearTimeSyncBuffer();
            return;
        case Action::StopTimeSyncBuffering:
        {
            bool deleteBuffer = TobiiBuff::g_stopBufferEmptiesDefault;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                    mexErrMsgTxt("stopTimeSyncBuffering: Expected argument to be a logical scalar.");
                deleteBuffer = mxIsLogicalScalarTrue(prhs[2]);
            }

            instance->stopTimeSyncBuffering(deleteBuffer);
            return;
        }
        case Action::ConsumeTimeSyncs:
        {
            uint64_t nSamp = TobiiBuff::g_consumeDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("consumeTimeSyncs: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = TimeSyncVectorToMatlab(instance->consumeTimeSyncs(nSamp));
            return;
        }
        case Action::PeekTimeSyncs:
        {
            uint64_t nSamp = TobiiBuff::g_peekDefaultAmount;
            if (nrhs > 2 && !mxIsEmpty(prhs[2]))
            {
                if (!mxIsUint64(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                    mexErrMsgTxt("peekTimeSyncs: Expected argument to be a uint64 scalar.");
                nSamp = *static_cast<uint64_t*>(mxGetData(prhs[2]));
            }
            plhs[0] = TimeSyncVectorToMatlab(instance->peekTimeSyncs(nSamp));
            return;
        }

        default:
            mexErrMsgTxt(("Unhandled action: " + actionStr).c_str());
            break;
    }
}


// helpers
namespace
{
    template <typename T>
    constexpr mxClassID typeToMxClass()
    {
        if      constexpr (std::is_same_v<T, double>)
            return mxDOUBLE_CLASS;
        else if constexpr (std::is_same_v<T, float>)
            return mxSINGLE_CLASS;
        else if constexpr (std::is_same_v<T, bool>)
            return mxLOGICAL_CLASS;
        else if constexpr (std::is_same_v<T, uint64_t>)
            return mxUINT64_CLASS;
        else if constexpr (std::is_same_v<T, int64_t>)
            return mxINT64_CLASS;
        else if constexpr (std::is_same_v<T, uint32_t>)
            return mxUINT32_CLASS;
        else if constexpr (std::is_same_v<T, int32_t>)
            return mxINT32_CLASS;
        else if constexpr (std::is_same_v<T, uint16_t>)
            return mxUINT16_CLASS;
        else if constexpr (std::is_same_v<T, int16_t>)
            return mxINT16_CLASS;
        else if constexpr (std::is_same_v<T, uint8_t>)
            return mxUINT8_CLASS;
        else if constexpr (std::is_same_v<T, int8_t>)
            return mxINT8_CLASS;
    }

    // get field indicated by list of pointers-to-member-variable in fields
    template <typename T, typename S, typename... Fs>
    constexpr auto inline getField(const T& obj, S field1, Fs... fields)
    {
        if constexpr (!sizeof...(fields))
            return obj.*field1;
        else
            return getField(obj.*field1, fields...);
    }

    // get field indicated by list of pointers-to-member-variable in fields, cast return value to user specified type
    template <typename Obj, typename Out, typename... Fs>
    constexpr auto inline getFieldCast(const Obj& obj, Out, Fs... fields)
    {
        return static_cast<Out>(getField(obj, fields...));
    }

    // get last type (or optionally 2nd last when N=2, 3rd last when N=3, etc) in variadic template
    template<class T> struct tag_t { using type = T; };
    template<class...Ts, size_t N = 1>
    using last = typename std::tuple_element_t< sizeof...(Ts) - N, std::tuple<tag_t<Ts>...> >::type;

    // higher order function to forward an index sequence
    template <typename F, size_t... Is>
    constexpr auto indices_impl(F f, std::index_sequence<Is...>)
    {
        return f(std::integral_constant<size_t, Is>()...);
    }
    template <size_t N, typename F>
    constexpr auto indices(F f)
    {
        return indices_impl(f, std::make_index_sequence<N>());
    }

    // Given f and some args t0, t1, ..., tn, calls f(tn, t0, t1, ..., tn-1)
    template <typename F, typename... Ts>
    constexpr auto rotate_right(F f, Ts... ts)
    {
        auto tuple = std::make_tuple(ts...);
        return indices<sizeof...(Ts) - 1>([&](auto... Is) constexpr	// pass elements 1 to N-1 as input to lambda
        {
            return f(												// call user's function with:
                std::get<sizeof...(Ts) - 1>(tuple),					// last element of tuple
                std::get<Is>(tuple)...);							// all inputs to lambda (elements 1 to N-1)
        });
    }
    // Given f and some args t0, t1, ..., tn, calls f(t0, t1, ..., tn, tn-1)
    template <typename F, typename... Ts>
    constexpr auto swap_last_2(F f, Ts... ts)
    {
        auto tuple = std::make_tuple(ts...);
        return indices<sizeof...(Ts) - 2>([&](auto... Is) constexpr	// pass elements 1 to N-2 as input to lambda
        {
            return f(												// call user's function with:
                std::get<Is>(tuple)...,								// all inputs to lambda (elements 1 to N-1)
                std::get<sizeof...(Ts) - 1>(tuple),					// last element
                std::get<sizeof...(Ts) - 2>(tuple)					// element N-1
                );
        });
    }

    template <typename Obj, typename... Fs>
    constexpr auto inline getFieldWrapper(const Obj& obj, Fs... fields)
    {
        // if last is pointer-to-member-variable, but previous is not (this would be a type tag then), swap the last two to put the type tag last
        if      constexpr (sizeof...(Fs)>1 && std::is_member_object_pointer_v<last<Obj, Fs...>> && !std::is_member_object_pointer_v<last<Obj, Fs..., 2>>)
            return swap_last_2(
            [&](auto... elems)
            {
                return getFieldWrapper(obj, elems...);
            }, fields...);
        // if last is pointer-to-member-variable, no casting of return value requested through type tag, call getField
        else if constexpr (std::is_member_object_pointer_v<last<Obj, Fs...>>)
            return getField(obj, fields...);
        // if last is not pointer-to-member-variable, casting of return value requested, call getFieldCast with correct order of arguments
        else
            return rotate_right(
            [&](auto... elems)
            {
                return getFieldCast(obj, elems...);
            }, fields...);
    }

    template <typename T>
    constexpr size_t getNumRows()
    {
        if      constexpr (std::is_same_v<T, TobiiResearchPoint3D>) // also matches TobiiResearchNormalizedPoint3D, as that's typedeffed to TobiiResearchPoint3D
            return 3;
        else if constexpr (std::is_same_v<T, TobiiResearchNormalizedPoint2D>)
            return 2;
        else
            return 1;
    }

    // function declaration to extract member variable type from a pointer-to-member-variable through declval (no implementation needed, because this function is never actually called)
    template <class C, typename T>
    T getPointerType(T C::*v) {}

    // default output is storage type corresponding to the type of the member variable accessed through this function, but it can be overridden through type tag dispatch (see getFieldWrapper implementation)
    template <typename S, typename... Fs>
    mxArray* FieldToMatlab(const std::vector<S>& data_, Fs... fields)
    {
        mxArray* temp;
        // get type member variable accessed through the last pointer-to-member-variable in the parameter pack (this is not necessecarily the last type in the parameter pack as that can also be the type tag if the user explicitly requested a return type)
        using retT = decltype(getPointerType(std::conditional_t<std::is_member_object_pointer_v<last<S, Fs...>>, last<S, Fs...>, last<S, Fs..., 2>>{}));
        // based on type, get number of rows for output
        constexpr auto numRows = getNumRows<retT>();

        size_t i = 0;
        if constexpr (numRows > 1)
        {
            // this is one of the 2D/3D point types
            // determine what return type we get
            // NB: appending extra field to access leads to wrong order if type tag was provided by user. getFieldWrapper detects this and corrects for it
            using U = decltype(getFieldWrapper(S{}, fields..., &retT::x));
            auto storage = static_cast<U*>(mxGetData(temp = mxCreateUninitNumericMatrix(numRows, data_.size(), typeToMxClass<U>(), mxREAL)));
            for (auto &samp : data_)
            {
                storage[i++] = getFieldWrapper(samp, fields..., &retT::x);
                storage[i++] = getFieldWrapper(samp, fields..., &retT::y);
                if constexpr (numRows == 3)
                    storage[i++] = getFieldWrapper(samp, fields..., &retT::z);
            }
        }
        else
        {
            using U = decltype(getFieldWrapper(S{}, fields...));
            auto storage = static_cast<U*>(mxGetData(temp = mxCreateUninitNumericMatrix(numRows, data_.size(), typeToMxClass<U>(), mxREAL)));
            for (auto &samp : data_)
                storage[i++] = getFieldWrapper(samp, fields...);
        }
        return temp;
    }

    // function to turn enum fields into a boolean given reference enum value for which true should be returned
    // (multiple functions because FieldToMatlabRef names as FieldToMatlab would be ambiguous due to unconstrained R)
    template <typename S, typename R, typename... Fs>
    auto FieldToMatlabRef(const std::vector<S>& data_, R ref_, Fs... fields)
    {
        mxArray* temp;
        auto storage = static_cast<bool*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, data_.size(), mxLOGICAL_CLASS, mxREAL)));
        size_t i = 0;
        for (auto &samp : data_)
            storage[i++] = getFieldWrapper(samp, fields...) == ref_;
        return temp;
    }
    template <typename S, typename... Fs>
    auto FieldToMatlab(const std::vector<S>& data_, TobiiResearchValidity ref_, Fs... fields)
    {
        return FieldToMatlabRef(data_, ref_, fields...);
    }
    template <typename S, typename... Fs>
    auto FieldToMatlab(const std::vector<S>& data_, TobiiResearchEyeImageType ref_, Fs... fields)
    {
        return FieldToMatlabRef(data_, ref_, fields...);
    }


    mxArray* FieldToMatlab(const std::vector<TobiiResearchGazeData>& data_, TobiiResearchEyeData TobiiResearchGazeData::* field_)
    {
        const char* fieldNamesEye[] = {"gazePoint","pupil","gazeOrigin"};
        const char* fieldNamesGP[] = {"onDisplayArea","inUserCoords","validity"};
        const char* fieldNamesPup[] = {"diameter","validity"};
        const char* fieldNamesGO[] = {"inUserCoords","inTrackBoxCoords","validity"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNamesEye) / sizeof(*fieldNamesEye), fieldNamesEye);
        mxArray* temp;

        // 1. gazePoint
        mxSetFieldByNumber(out, 0, 0, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesGP) / sizeof(*fieldNamesGP), fieldNamesGP));
        // 1.1 gazePoint.onDisplayArea
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_point, &TobiiResearchGazePoint::position_on_display_area, 0.));
        // 1.2 gazePoint.inUserCoords
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_point, &TobiiResearchGazePoint::position_in_user_coordinates, 0.));
        // 1.3 gazePoint.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, TOBII_RESEARCH_VALIDITY_VALID, field_, &TobiiResearchEyeData::gaze_point, &TobiiResearchGazePoint::validity));

        // 2. pupil
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesPup) / sizeof(*fieldNamesPup), fieldNamesPup));
        // 2.1 pupil.diameter
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeData::pupil_data, &TobiiResearchPupilData::diameter));
        // 2.2 pupil.validity
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, TOBII_RESEARCH_VALIDITY_VALID, field_, &TobiiResearchEyeData::pupil_data, &TobiiResearchPupilData::validity));

        // 3. gazePoint
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesGO) / sizeof(*fieldNamesGO), fieldNamesGO));
        // 3.1 gazeOrigin.inUserCoords
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_origin, &TobiiResearchGazeOrigin::position_in_user_coordinates, 0.));
        // 3.2 gazeOrigin.inTrackBoxCoords
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, field_, &TobiiResearchEyeData::gaze_origin, &TobiiResearchGazeOrigin::position_in_track_box_coordinates, 0.));
        // 3.3 gazeOrigin.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, TOBII_RESEARCH_VALIDITY_VALID, field_, &TobiiResearchEyeData::gaze_origin, &TobiiResearchGazeOrigin::validity));

        return out;
    }

    mxArray* SampleVectorToMatlab(std::vector<TobiiResearchGazeData> data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

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

    template <typename S, typename T, typename R>
    bool allEquals(const std::vector<S>& data_, T S::* field_, const R& ref_)
    {
        for (auto &frame : data_)
            if (frame.*field_ != ref_)
                return false;
        return true;
    }

    mxArray* eyeImagesToMatlab(const std::vector<TobiiBuff::eyeImage>& data_)
    {
        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].data_size;
        bool same = allEquals(data_, &TobiiBuff::eyeImage::data_size, sz);
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
            out = mxCreateCellMatrix(data_.size(), 1);
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

    mxArray* EyeImageVectorToMatlab(std::vector<TobiiBuff::eyeImage> data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // check if all gif, then don't output unneeded fields
        bool allGif = allEquals(data_, &TobiiBuff::eyeImage::isGif, true);

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
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiBuff::eyeImage::device_time_stamp));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiBuff::eyeImage::system_time_stamp));
        if (!allGif)
        {
            mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiBuff::eyeImage::bits_per_pixel));
            mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, &TobiiBuff::eyeImage::padding_per_pixel));
            mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, &TobiiBuff::eyeImage::width, 0.));		// 0. to force storing as double
            mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, &TobiiBuff::eyeImage::height, 0.));		// 0. to force storing as double
        }
        int off = 4 * (!allGif);
        mxSetFieldByNumber(out, 0, 2 + off, FieldToMatlab(data_, TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED, &TobiiBuff::eyeImage::type));
        mxSetFieldByNumber(out, 0, 3 + off, FieldToMatlab(data_, &TobiiBuff::eyeImage::camera_id));
        mxSetFieldByNumber(out, 0, 4 + off, FieldToMatlab(data_, &TobiiBuff::eyeImage::isGif));
        mxSetFieldByNumber(out, 0, 5 + off, eyeImagesToMatlab(data_));

        return out;
    }


    mxArray* ExtSignalVectorToMatlab(std::vector<TobiiResearchExternalSignalData     > data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","value","changeType"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. all device timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchExternalSignalData::device_time_stamp));
        // 2. all system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchExternalSignalData::system_time_stamp));
        // 3. external signal values
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiResearchExternalSignalData::value));
        // 3. value change type
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, &TobiiResearchExternalSignalData::change_type, uint8_t{}));	// cast enum values

        return out;
    }
    mxArray*  TimeSyncVectorToMatlab(std::vector<TobiiResearchTimeSynchronizationData> data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        const char* fieldNames[] = {"systemRequestTimeStamp","deviceTimeStamp","systemResponseTimeStamp"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. all system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchTimeSynchronizationData::system_request_time_stamp));
        // 2. all device timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchTimeSynchronizationData::device_time_stamp));
        // 3. external signal values
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiResearchTimeSynchronizationData::system_response_time_stamp));

        return out;
    }
}


// function for handling errors generated by lib
void DoExitWithMsg(std::string errMsg_)
{
    mexErrMsgTxt(errMsg_.c_str());
}