// MEX wrapper for LSL_streamer.
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
#include <cstring>
#include <cinttypes>

#include "cpp_mex_helpers/include_matlab.h"

#include "cpp_mex_helpers/pack_utils.h"
#include "cpp_mex_helpers/get_field_nested.h"
#include "cpp_mex_helpers/mem_var_trait.h"
#include "tobii_elem_count.h"

#include "Titta/Titta.h"
#include "Titta/utils.h"

// converting data to matlab. First here user extensions, then include with generic code driving this
// extend set of function to convert C++ data to matlab
#include "cpp_mex_helpers/mex_type_utils_fwd.h"
#include "LSL_streamer/LSL_streamer.h"

namespace mxTypes
{
    // forward declarations
    template<typename Cont, typename... Fs>
    mxArray* TobiiFieldToMatlab(const Cont& data_, bool rowVectors_, Fs... fields);

    mxArray* ToMatlab(TobiiResearchSDKVersion                               data_);
    mxArray* ToMatlab(lsl::stream_info                                      data_);
    mxArray* ToMatlab(lsl::channel_format_t                                 data_);
    mxArray* ToMatlab(Titta::Stream                                         data_);

    mxArray* ToMatlab(std::vector<LSL_streamer::gaze           >            data_);
    mxArray* FieldToMatlab(const std::vector<LSL_streamer::gaze>&           data_, bool rowVector_, TobiiTypes::eyeData Titta::gaze::* field_);
    mxArray* ToMatlab(std::vector<LSL_streamer::eyeImage       >            data_);
    mxArray* ToMatlab(std::vector<LSL_streamer::extSignal      >            data_);
    mxArray* ToMatlab(std::vector<LSL_streamer::timeSync       >            data_);
    mxArray* ToMatlab(std::vector<LSL_streamer::positioning    >            data_);
    mxArray* FieldToMatlab(const std::vector<LSL_streamer::positioning>&    data_, bool rowVector_, TobiiResearchEyeUserPositionGuide TobiiResearchUserPositionGuide::* field_);
}
#include "cpp_mex_helpers/mex_type_utils.h"

namespace {
    using ClassType         = LSL_streamer;
    using HandleType        = unsigned int;
    using InstancePtrType   = std::shared_ptr<ClassType>;
    using InstanceMapType   = std::map<HandleType, InstancePtrType>;

    // List actions
    enum class Action
    {
        // MATLAB interface
        Touch,
        New,
        Delete,

        // global SDK functions
        GetTobiiSDKVersion,
        GetLSLVersion,
        GetRemoteStreams,

        // some functions that really just wrap Titta functions, for ease of use
        // check functions for dummy mode
        CheckStream,
        CheckBufferSide,
        // data stream info
        GetAllStreamsString,
        GetAllBufferSidesString,

        // outlets
        Connect,
        StartOutlet,
        SetIncludeEyeOpennessInGaze,
        IsStreaming,
        StopOutlet,

        // inlets
        CreateListener,
        GetInletInfo,
        GetInletType,
        StartListening,
        IsListening,
        ConsumeN,
        ConsumeTimeRange,
        PeekN,
        PeekTimeRange,
        Clear,
        ClearTimeRange,
        StopListening,
        DeleteListener
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        // MATLAB interface
        { "touch",                          Action::Touch },
        { "new",                            Action::New },
        { "delete",                         Action::Delete },

        // global SDK functions
        { "getTobiiSDKVersion",             Action::GetTobiiSDKVersion },
        { "getLSLVersion",                  Action::GetLSLVersion },
        { "getRemoteStreams",               Action::GetRemoteStreams },

        // some functions that really just wrap Titta functions, for ease of use
        // check functions for dummy mode
        { "checkStream",                    Action::CheckStream },
        { "checkBufferSide",                Action::CheckBufferSide },
        // data stream info
        { "getAllStreamsString",            Action::GetAllStreamsString },
        { "getAllBufferSidesString",        Action::GetAllBufferSidesString },

        // outlets
        { "connect",                        Action::Connect },
        { "startOutlet",                    Action::StartOutlet },
        { "setIncludeEyeOpennessInGaze",    Action::SetIncludeEyeOpennessInGaze },
        { "isStreaming",                    Action::IsStreaming },
        { "stopOutlet",                     Action::StopOutlet },

        // inlets
        { "createListener",                 Action::CreateListener },
        { "getInletInfo",                   Action::GetInletInfo },
        { "getInletType",                   Action::GetInletType },
        { "startListening",                 Action::StartListening },
        { "isListening",                    Action::IsListening },
        { "consumeN",                       Action::ConsumeN },
        { "consumeTimeRange",               Action::ConsumeTimeRange },
        { "peekN",                          Action::PeekN },
        { "peekTimeRange",                  Action::PeekTimeRange },
        { "clear",                          Action::Clear },
        { "clearTimeRange",                 Action::ClearTimeRange },
        { "stopListening",                  Action::StopListening },
        { "deleteListener",                 Action::DeleteListener },
    };


    // table mapping handles to instances
    InstanceMapType instanceTab;
    // for unique handles
    std::atomic<HandleType> handleVal = {0};

    // getHandle pulls the integer handle out of prhs[1]
    HandleType getHandle(int nrhs, const mxArray *prhs[])
    {
        static_assert(std::is_same_v<HandleType, unsigned int>);   // to check next line is valid (we didn't change the handle type)
        if (nrhs < 2 || !mxIsScalar(prhs[1]) || !mxIsUint32(prhs[1]))
            throw "Specify an instance with an integer (uint32) handle.";
        return *static_cast<HandleType*>(mxGetData(prhs[1]));
    }

    // checkHandle gets the position in the instance table
    InstanceMapType::const_iterator checkHandle(const InstanceMapType& m, HandleType h)
    {
        auto it = m.find(h);
        if (it == m.end())
        {
            std::stringstream ss; ss << "No instance corresponding to handle " << h << " found.";
            throw ss.str();
        }
        return it;
    }

    bool registeredAtExit = false;
    void atExitCleanUp()
    {
        instanceTab.clear();
    }
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    try
    {
        if (!registeredAtExit)
        {
            mexAtExit(&atExitCleanUp);
            registeredAtExit = true;
        }

        if (nrhs < 1 || !mxIsChar(prhs[0]))
            throw "First input must be an action string ('new', 'delete', or a method name).";

        // get action string
        char* actionCstr = mxArrayToString(prhs[0]);
        std::string actionStr(actionCstr);
        mxFree(actionCstr);

        // get corresponding action
        auto it = actionTypeMap.find(actionStr);
        if (it == actionTypeMap.end())
            throw "Unrecognized action (not in actionTypeMap): " + actionStr;
        Action action = it->second;

        // If action is not "new" or others that don't require a handle, try to locate an existing instance based on input handle
        InstanceMapType::const_iterator instIt;
        InstancePtrType instance;
        if (action != Action::Touch && action != Action::New &&
            action != Action::GetTobiiSDKVersion && action != Action::GetLSLVersion && action != Action::GetRemoteStreams &&
            action != Action::CheckStream && action != Action::CheckBufferSide &&
            action != Action::GetAllStreamsString && action != Action::GetAllBufferSidesString)
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
            std::optional<std::string> address;
            if (nrhs > 1 && !mxIsEmpty(prhs[1]))
            {
                if (!mxIsChar(prhs[1]))
                    throw "LSLMex: Second argument must be a string.";
                char* c_address = mxArrayToString(prhs[1]);
                address = c_address;
                mxFree(c_address);
            }

            auto handle = ++handleVal;
            bool inserted = false;
            if (address.has_value())
            {
                auto insResult = instanceTab.insert({ handle, std::make_shared<ClassType>(*address) });
                inserted = insResult.second;
            }
            else
            {
                auto insResult = instanceTab.insert({ handle, std::make_shared<ClassType>() });
                inserted = insResult.second;
            }

            if (!inserted) // sanity check
                throw "Oh, bad news. Tried to add an existing handle."; // shouldn't ever happen
            else
                mexLock(); // add to the lock count

            // return the handle
            plhs[0] = mxTypes::ToMatlab(handle);

            break;
        }
        case Action::Delete:
        {
            instanceTab.erase(instIt);      // erase from map
            instance.reset();               // decrement ref count of shared pointer, should cause it to delete instance itself
            mexUnlock();
            plhs[0] = mxCreateLogicalScalar(instanceTab.empty()); // info
            break;
        }

        case Action::GetTobiiSDKVersion:
        {
            plhs[0] = mxTypes::ToMatlab(LSL_streamer::getTobiiSDKVersion());
            break;
        }
        case Action::GetLSLVersion:
        {
            plhs[0] = mxTypes::ToMatlab(LSL_streamer::getLSLVersion());
            break;
        }
        case Action::GetRemoteStreams:
        {
            std::optional<std::string> stream;
            if (nrhs > 1 && !mxIsEmpty(prhs[1]))
            {
                if (!mxIsChar(prhs[1]))
                    throw "LSLMex::GetRemoteStreams: Second argument must be a string.";
                char* c_stream = mxArrayToString(prhs[1]);
                stream = c_stream;
                mxFree(c_stream);
            }
            plhs[0] = mxTypes::ToMatlab(LSL_streamer::getRemoteStreams(stream ? *stream :""));
            break;
        }

        // stream info
        case Action::CheckStream:
        {
            if (nrhs < 2 || !mxIsChar(prhs[1]))
            {
                std::string err = "checkStream: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").";
                throw err;
            }

            // get data stream identifier string, check if valid
            char* bufferCstr = mxArrayToString(prhs[1]);
            Titta::stringToStream(bufferCstr);
            mxFree(bufferCstr);
            plhs[0] = mxCreateLogicalScalar(true);
            return;
        }
        case Action::CheckBufferSide:
        {
            if (nrhs < 2 || !mxIsChar(prhs[1]))
            {
                std::string err = "checkBufferSide: First input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                throw err;
            }

            // get data stream identifier string, check if valid
            char* bufferCstr = mxArrayToString(prhs[1]);
            Titta::stringToBufferSide(bufferCstr);
            mxFree(bufferCstr);
            plhs[0] = mxCreateLogicalScalar(true);
            return;
        }
        case Action::GetAllStreamsString:
        {
            if (nrhs > 1)
            {
                if (!mxIsChar(prhs[1]) || mxIsComplex(prhs[1]) || (!mxIsScalar(prhs[1]) && !mxIsEmpty(prhs[1])))
                    throw "getAllStreamsString: Expected first argument to be a char scalar or empty char array.";

                char quoteChar[2] = { "\0" };
                if (!mxIsEmpty(prhs[1]))
                    quoteChar[0] = *static_cast<char*>(mxGetData(prhs[1]));

                if (nrhs > 2 && !mxIsEmpty(prhs[2]))
                {
                    if (!(mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2])) && !mxIsLogicalScalar(prhs[2]))
                        throw "getAllStreamsString: Expected second argument to be a logical scalar.";
                    bool snakeCase = mxIsLogicalScalarTrue(prhs[2]);

                    plhs[0] = mxTypes::ToMatlab(Titta::getAllStreamsString(quoteChar, snakeCase, true));
                }
                else
                    plhs[0] = mxTypes::ToMatlab(Titta::getAllStreamsString(quoteChar, false, true));
            }
            else
                plhs[0] = mxTypes::ToMatlab(Titta::getAllStreamsString("\"", false, true));
            return;
        }
        case Action::GetAllBufferSidesString:
        {
            if (nrhs > 1)
            {
                if (!mxIsChar(prhs[1]) || mxIsComplex(prhs[1]) || (!mxIsScalar(prhs[1]) && !mxIsEmpty(prhs[1])))
                    throw "getAllBufferSidesString: Expected first argument to be a char scalar or empty char array.";
                char quoteChar[2] = { "\0" };
                if (!mxIsEmpty(prhs[1]))
                    quoteChar[0] = *static_cast<char*>(mxGetData(prhs[1]));
                plhs[0] = mxTypes::ToMatlab(Titta::getAllBufferSidesString(quoteChar));
            }
            else
                plhs[0] = mxTypes::ToMatlab(Titta::getAllBufferSidesString());
            return;
        }

        // outlets
        case Action::Connect:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                throw "LSLMex:Connect: First argument must be a string.";
            char* address = mxArrayToString(prhs[1]);
            instance->connect(address);
            mxFree(address);
            break;
        }
        case Action::StartOutlet:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                throw std::string("startOutlet: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

            // get optional input arguments
            std::optional<bool> asGif;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!(mxIsDouble(prhs[3]) && !mxIsComplex(prhs[3]) && mxIsScalar(prhs[3])) && !mxIsLogicalScalar(prhs[3]))
                    throw "startOutlet: Expected second argument to be a logical scalar.";
                asGif = mxIsLogicalScalarTrue(prhs[3]);
            }

            char* bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->startOutlet(bufferCstr, asGif));
            mxFree(bufferCstr);
            return;
        }
        case Action::SetIncludeEyeOpennessInGaze:
        {
            if (nrhs < 3 || mxIsEmpty(prhs[2]) || !mxIsScalar(prhs[2]) || !mxIsLogicalScalar(prhs[2]))
                throw "setIncludeEyeOpennessInGaze: First argument must be a logical scalar.";

            bool include = mxIsLogicalScalarTrue(prhs[2]);
            instance->setIncludeEyeOpennessInGaze(include);
            break;
        }
        case Action::IsStreaming:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                throw std::string("isStreaming: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

            char* bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->isStreaming(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::StopOutlet:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                throw std::string("stopOutlet: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

            char* bufferCstr = mxArrayToString(prhs[2]);
            instance->stopOutlet(bufferCstr);
            mxFree(bufferCstr);
            return;
        }


        // inlets
        case Action::CreateListener:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                throw "createListener: First input must be a LSL stream source identifier string.";

            // get optional input arguments
            std::optional<size_t> bufSize;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsUint64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    throw "createListener: Expected second argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs[3]));
                bufSize = static_cast<size_t>(temp);
            }
            std::optional<bool> doStartListening;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!(mxIsDouble(prhs[4]) && !mxIsComplex(prhs[4]) && mxIsScalar(prhs[4])) && !mxIsLogicalScalar(prhs[4]))
                    throw "createListener: Expected third argument to be a logical scalar.";
                doStartListening = mxIsLogicalScalarTrue(prhs[4]);
            }

            char* bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->createListener(bufferCstr, bufSize, doStartListening));
            mxFree(bufferCstr);
            return;
        }
        case Action::GetInletInfo:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "getInletInfo: First input must be a uint32.";
            plhs[0] = mxTypes::ToMatlab(instance->getInletInfo(*static_cast<uint32_t*>(mxGetData(prhs[2]))));
            return;
        }
        case Action::GetInletType:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "getInletType: First input must be a uint32.";
            plhs[0] = mxTypes::ToMatlab(instance->getInletType(*static_cast<uint32_t*>(mxGetData(prhs[2]))));
            return;
        }
        case Action::StartListening:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "startListening: First input must be a uint32.";
            instance->startListening(*static_cast<uint32_t*>(mxGetData(prhs[2])));
            return;
        }
        case Action::IsListening:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "isListening: First input must be a uint32.";
            plhs[0] = mxCreateLogicalScalar(instance->isListening(*static_cast<uint32_t*>(mxGetData(prhs[2]))));
            return;
        }
        case Action::ConsumeN:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "consumeN: First input must be a uint32.";
            auto id = *static_cast<uint32_t*>(mxGetData(prhs[2]));

            // get optional input arguments
            std::optional<size_t> nSamp;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsUint64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    throw "consumeN: Expected second argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs[3]));
                if (temp > SIZE_MAX)
                    throw "consumeN: Requesting preallocated buffer of a larger size than is possible on a 32bit platform.";
                nSamp = static_cast<size_t>(temp);
            }
            std::optional<Titta::BufferSide> side;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsChar(prhs[4]))
                {
                    std::string err = "consumeN: Third input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                    throw err;
                }
                char* bufferCstr = mxArrayToString(prhs[4]);
                side = Titta::stringToBufferSide(bufferCstr);
                mxFree(bufferCstr);
            }

            switch (instance->getInletType(id))
            {
            case Titta::Stream::Gaze:
                plhs[0] = mxTypes::ToMatlab(instance->consumeN<LSL_streamer::gaze>(id, nSamp, side));
                return;
            case Titta::Stream::EyeImage:
                plhs[0] = mxTypes::ToMatlab(instance->consumeN<LSL_streamer::eyeImage>(id, nSamp, side));
                return;
            case Titta::Stream::ExtSignal:
                plhs[0] = mxTypes::ToMatlab(instance->consumeN<LSL_streamer::extSignal>(id, nSamp, side));
                return;
            case Titta::Stream::TimeSync:
                plhs[0] = mxTypes::ToMatlab(instance->consumeN<LSL_streamer::timeSync>(id, nSamp, side));
                return;
            case Titta::Stream::Positioning:
                plhs[0] = mxTypes::ToMatlab(instance->consumeN<LSL_streamer::positioning>(id, nSamp, side));
                return;
            }
        }
        case Action::ConsumeTimeRange:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "consumeTimeRange: First input must be a uint32.";
            auto id = *static_cast<uint32_t*>(mxGetData(prhs[2]));

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsInt64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    throw "consumeTimeRange: Expected second argument to be a int64 scalar.";
                timeStart = *static_cast<int64_t*>(mxGetData(prhs[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsInt64(prhs[4]) || mxIsComplex(prhs[4]) || !mxIsScalar(prhs[4]))
                    throw "consumeTimeRange: Expected third argument to be a int64 scalar.";
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs[4]));
            }

            switch (instance->getInletType(id))
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<LSL_streamer::gaze>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::EyeImage:
                plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<LSL_streamer::eyeImage>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::ExtSignal:
                plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<LSL_streamer::extSignal>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::TimeSync:
                plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<LSL_streamer::timeSync>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::Positioning:
                throw "consumeTimeRange: not supported for positioning stream.";
                return;
            }
        }
        case Action::PeekN:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "peekN: First input must be a uint32.";
            auto id = *static_cast<uint32_t*>(mxGetData(prhs[2]));

            // get optional input arguments
            std::optional<size_t> nSamp;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsUint64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    throw "peekN: Expected second argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs[3]));
                if (temp > SIZE_MAX)
                    throw "peekN: Requesting preallocated buffer of a larger size than is possible on a 32bit platform.";
                nSamp = static_cast<size_t>(temp);
            }
            std::optional<Titta::BufferSide> side;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsChar(prhs[4]))
                {
                    std::string err = "peekN: Third input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                    throw err;
                }
                char* bufferCstr = mxArrayToString(prhs[4]);
                side = Titta::stringToBufferSide(bufferCstr);
                mxFree(bufferCstr);
            }

            switch (instance->getInletType(id))
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs[0] = mxTypes::ToMatlab(instance->peekN<LSL_streamer::gaze>(id, nSamp, side));
                return;
            case Titta::Stream::EyeImage:
                plhs[0] = mxTypes::ToMatlab(instance->peekN<LSL_streamer::eyeImage>(id, nSamp, side));
                return;
            case Titta::Stream::ExtSignal:
                plhs[0] = mxTypes::ToMatlab(instance->peekN<LSL_streamer::extSignal>(id, nSamp, side));
                return;
            case Titta::Stream::TimeSync:
                plhs[0] = mxTypes::ToMatlab(instance->peekN<LSL_streamer::timeSync>(id, nSamp, side));
                return;
            case Titta::Stream::Positioning:
                plhs[0] = mxTypes::ToMatlab(instance->peekN<LSL_streamer::positioning>(id, nSamp, side));
                return;
            }
        }
        case Action::PeekTimeRange:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "peekTimeRange: First input must be a uint32.";
            auto id = *static_cast<uint32_t*>(mxGetData(prhs[2]));

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsInt64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    throw "peekTimeRange: Expected second argument to be a int64 scalar.";
                timeStart = *static_cast<int64_t*>(mxGetData(prhs[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsInt64(prhs[4]) || mxIsComplex(prhs[4]) || !mxIsScalar(prhs[4]))
                    throw "peekTimeRange: Expected third argument to be a int64 scalar.";
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs[4]));
            }

            switch (instance->getInletType(id))
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<LSL_streamer::gaze>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::EyeImage:
                plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<LSL_streamer::eyeImage>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::ExtSignal:
                plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<LSL_streamer::extSignal>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::TimeSync:
                plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<LSL_streamer::timeSync>(id, timeStart, timeEnd));
                return;
            case Titta::Stream::Positioning:
                throw "peekTimeRange: not supported for positioning stream.";
                return;
            }
        }
        case Action::Clear:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "clear: First input must be a uint32.";
            instance->clear(*static_cast<uint32_t*>(mxGetData(prhs[2])));
            break;
        }
        case Action::ClearTimeRange:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "clearTimeRange: First input must be a uint32.";
            auto id = *static_cast<uint32_t*>(mxGetData(prhs[2]));

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsInt64(prhs[3]) || mxIsComplex(prhs[3]) || !mxIsScalar(prhs[3]))
                    throw "clearTimeRange: Expected second argument to be a int64 scalar.";
                timeStart = *static_cast<int64_t*>(mxGetData(prhs[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs > 4 && !mxIsEmpty(prhs[4]))
            {
                if (!mxIsInt64(prhs[4]) || mxIsComplex(prhs[4]) || !mxIsScalar(prhs[4]))
                    throw "clearTimeRange: Expected third argument to be a int64 scalar.";
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs[4]));
            }

            // get data stream identifier string, clear buffer
            instance->clearTimeRange(id, timeStart, timeEnd);
            break;
        }
        case Action::StopListening:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "stopListening: First input must be a uint32.";
            auto id = *static_cast<uint32_t*>(mxGetData(prhs[2]));

            // get optional input argument
            std::optional<bool> clearBuffer;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!(mxIsDouble(prhs[3]) && !mxIsComplex(prhs[3]) && mxIsScalar(prhs[3])) && !mxIsLogicalScalar(prhs[3]))
                    throw "stopListening: Expected second argument to be a logical scalar.";
                clearBuffer = mxIsLogicalScalarTrue(prhs[3]);
            }

            // get data stream identifier string, stop buffering
            instance->stopListening(id, clearBuffer);
            break;
        }
        case Action::DeleteListener:
        {
            if (nrhs < 3 || !mxIsUint32(prhs[2]))
                throw "deleteListener: First input must be a uint32.";
            instance->deleteListener(*static_cast<uint32_t*>(mxGetData(prhs[2])));
            return;
        }

        default:
            throw "Unhandled action: " + actionStr;
            break;
        }
    }
    catch (const std::exception& e)
    {
        mexErrMsgTxt(e.what());
    }
    catch (const std::string& e)
    {
        mexErrMsgTxt(e.c_str());
    }
    catch (const char* e)
    {
        mexErrMsgTxt(e);
    }
    catch (...)
    {
        mexErrMsgTxt("LSL_streamer: Unknown exception occurred");
    }
}


// helpers
namespace
{
    template <typename S, typename T, typename SS, typename TT, typename R>
    bool allEquals(const std::vector<S>& data_, T S::* field_, TT SS::* field2_, const R& ref_)
    {
        for (auto &frame : data_)
            if (frame.*field_.*field2_ != ref_)
                return false;
        return true;
    }

    mxArray* eyeImagesToMatlab(const std::vector<LSL_streamer::eyeImage>& data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].eyeImageData.data_size;
        bool same = allEquals(data_, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::data_size, sz);
        // 2. then copy over the images to matlab
        mxArray* out;
        if (data_[0].eyeImageData.bits_per_pixel + data_[0].eyeImageData.padding_per_pixel != 8)
            throw "LSL_streamer: eyeImagesToMatlab: non-8bit images not implemented";
        if (same)
        {
            auto storage = static_cast<uint8_t*>(mxGetData(out = mxCreateUninitNumericMatrix(static_cast<size_t>(data_[0].eyeImageData.width)*data_[0].eyeImageData.height, data_.size(), mxUINT8_CLASS, mxREAL)));
            size_t i = 0;
            for (auto &frame : data_)
                std::memcpy(storage + (i++)*sz, frame.eyeImageData.data(), frame.eyeImageData.data_size);
        }
        else
        {
            out = mxCreateCellMatrix(1, static_cast<mwSize>(data_.size()));
            mwIndex i = 0;
            for (auto &frame : data_)
            {
                mxArray* temp;
                auto storage = static_cast<uint8_t*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, static_cast<size_t>(frame.eyeImageData.width)*frame.eyeImageData.height, mxUINT8_CLASS, mxREAL)));
                std::memcpy(storage, frame.eyeImageData.data(), frame.eyeImageData.data_size);
                mxSetCell(out, i++, temp);
            }
        }

        return out;
    }

    std::string TobiiResearchCalibrationEyeValidityToString(TobiiResearchCalibrationEyeValidity data_)
    {
        switch (data_)
        {
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_INVALID_AND_NOT_USED:
            return "invalidAndNotUsed";
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_BUT_NOT_USED:
            return "validButNotUsed";
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED:
            return "validAndUsed";
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_UNKNOWN:
            return "unknown";
        }

        return "unknown";
    }
}
namespace mxTypes
{
    // default output is storage type corresponding to the type of the member variable accessed through this function, but it can be overridden through type tag dispatch (see nested_field::getWrapper implementation)
    template<typename Cont, typename... Fs>
    mxArray* TobiiFieldToMatlab(const Cont& data_, bool rowVectors_, Fs... fields)
    {
        mxArray* temp;
        using V = typename Cont::value_type;
        // get type member variable accessed through the last pointer-to-member-variable in the parameter pack (this is not necessarily the last type in the parameter pack as that can also be the type tag if the user explicitly requested a return type)
        using memVar = std::conditional_t<std::is_member_object_pointer_v<last<0, V, Fs...>>, last<0, V, Fs...>, last<1, V, Fs...>>;
        using retT   = memVarType_t<memVar>;
        // based on type, get number of rows for output
        constexpr auto numElements = getNumElements<retT>();

        // this is one of the 2D/3D point types
        // determine what return type we get
        // NB: appending extra field to access leads to wrong order if type tag was provided by user. nested_field::getWrapper detects this and corrects for it
        using U = decltype(nested_field::getWrapper(std::declval<V>(), std::forward<Fs>(fields)..., &retT::x));
        mwSize rCount = numElements;
        mwSize cCount = data_.size();
        if (!rowVectors_)
        {
            DoExitWithMsg("Not supported, below code needs to walk over output with a different stride to output column vectors correctly");
            std::swap(rCount, cCount);
        }
        auto storage = static_cast<U*>(mxGetData(temp = mxCreateUninitNumericMatrix(rCount, cCount, typeToMxClass_v<U>, mxREAL)));
        for (auto&& samp : data_)
        {
            (*storage++) = nested_field::getWrapper(samp, std::forward<Fs>(fields)..., &retT::x);
            (*storage++) = nested_field::getWrapper(samp, std::forward<Fs>(fields)..., &retT::y);
            if constexpr (numElements == 3)
                (*storage++) = nested_field::getWrapper(samp, std::forward<Fs>(fields)..., &retT::z);
        }
        return temp;
    }

    mxArray* ToMatlab(TobiiResearchSDKVersion data_)
    {
        std::stringstream ss;
        ss << data_.major << "." << data_.minor << "." << data_.revision << "." << data_.build;
        return ToMatlab(ss.str());
    }

    mxArray* ToMatlab(lsl::stream_info data_)
    {
        const char* fieldNames[] = { "name","type","channel_count","nominal_srate","channel_format","source_id","version","created_at","uid","session_id","hostname","xml","channel_bytes","sample_bytes" };
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.name()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.type()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.channel_count()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.nominal_srate()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.channel_format()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.source_id()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.version()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.created_at()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.uid()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.session_id()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.hostname()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.channel_bytes()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.sample_bytes()));
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.as_xml()));

        return out;
    }
    mxArray* ToMatlab(lsl::channel_format_t data_)
    {
        switch (data_)
        {
        case lsl::cf_float32:
            return ToMatlab("float");
        case lsl::cf_double64:
            return ToMatlab("double");
        case lsl::cf_string:
            return ToMatlab("string");
        case lsl::cf_int32:
            return ToMatlab("int32");
        case lsl::cf_int16:
            return ToMatlab("int16");
        case lsl::cf_int8:
            return ToMatlab("int8");
        case lsl::cf_int64:
            return ToMatlab("int64");
        case lsl::cf_undefined:
            return ToMatlab("undefined");
        }
        return ToMatlab("unknown");
    }

    mxArray* ToMatlab(Titta::Stream data_)
    {
        return ToMatlab(Titta::streamToString(data_));
    }

    mxArray* ToMatlab(std::vector<LSL_streamer::gaze> data_)
    {
        const char* fieldNames[] = {"remote_system_time_stamp","local_system_time_stamp","deviceTimeStamp","systemTimeStamp","left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. all remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &LSL_streamer::gaze::remote_system_time_stamp));
        // 2. all local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &LSL_streamer::gaze::local_system_time_stamp));
        // 3. all device timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &LSL_streamer::gaze::gazeData, &Titta::gaze::device_time_stamp));
        // 4. all system timestamps
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &LSL_streamer::gaze::gazeData, &Titta::gaze::system_time_stamp));
        // 5. left  eye data
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &Titta::gaze::left_eye));
        // 6. right eye data
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &Titta::gaze::right_eye));

        return out;
    }
    mxArray* FieldToMatlab(const std::vector<LSL_streamer::gaze>& data_, bool rowVector_, TobiiTypes::eyeData Titta::gaze::* field_)
    {
        const char* fieldNamesEye[] = {"gazePoint","pupil","gazeOrigin","eyeOpenness"};
        const char* fieldNamesGP[] = {"onDisplayArea","inUserCoords","valid","available" };
        const char* fieldNamesPup[] = {"diameter","valid","available" };
        const char* fieldNamesGO[] = { "inUserCoords","inTrackBoxCoords","valid","available" };
        const char* fieldNamesEO[] = { "diameter","valid","available" };
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesEye)), fieldNamesEye);
        mxArray* temp;

        // 1. gazePoint
        mxSetFieldByNumber(out, 0, 0, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesGP)), fieldNamesGP));
        // 1.1 gazePoint.onDisplayArea
        mxSetFieldByNumber(temp, 0, 0, TobiiFieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_on_display_area, 0.));              // 0. causes values to be stored as double
        // 1.2 gazePoint.inUserCoords
        mxSetFieldByNumber(temp, 0, 1, TobiiFieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_in_user_coordinates, 0.));          // 0. causes values to be stored as double
        // 1.3 gazePoint.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 1.4 gazePoint.available
        mxSetFieldByNumber(temp, 0, 3, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::available));

        // 2. pupil
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesPup)), fieldNamesPup));
        // 2.1 pupil.diameter
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::diameter, 0.));                                   // 0. causes values to be stored as double
        // 2.2 pupil.validity
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 2.3 pupil.available
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::available));

        // 3. gazeOrigin
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesGO)), fieldNamesGO));
        // 3.1 gazeOrigin.inUserCoords
        mxSetFieldByNumber(temp, 0, 0, TobiiFieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_user_coordinates, 0.));        // 0. causes values to be stored as double
        // 3.2 gazeOrigin.inTrackBoxCoords
        mxSetFieldByNumber(temp, 0, 1, TobiiFieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_track_box_coordinates, 0.));   // 0. causes values to be stored as double
        // 3.3 gazeOrigin.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 3.4 gazeOrigin.available
        mxSetFieldByNumber(temp, 0, 3, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::available));

        // 4. eyeOpenness
        mxSetFieldByNumber(out, 0, 3, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesEO)), fieldNamesEO));
        // 4.1 eye_openness.diameter
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::diameter, 0.));                             // 0. causes values to be stored as double
        // 4.2 eye_openness.validity
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 4.3 eye_openness.available
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::available));

        return out;
    }

    mxArray* ToMatlab(std::vector<LSL_streamer::eyeImage> data_)
    {
        // check if all gif, then don't output unneeded fields
        bool allGif = allEquals(data_, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::is_gif, true);

        // fieldnames for all structs
        mxArray* out;
        if (allGif)
        {
            const char* fieldNames[] = {"remote_system_time_stamp","local_system_time_stamp","deviceTimeStamp","systemTimeStamp","regionID","regionTop","regionLeft","type","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }
        else
        {
            const char* fieldNames[] = {"remote_system_time_stamp","local_system_time_stamp","deviceTimeStamp","systemTimeStamp","regionID","regionTop","regionLeft","bitsPerPixel","paddingPerPixel","width","height","type","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }

        // all simple fields
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::remote_system_time_stamp));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::local_system_time_stamp));
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::device_time_stamp));
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::system_time_stamp));
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::region_id, 0.));             // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::region_top, 0.));            // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 6, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::region_left, 0.));           // 0. causes values to be stored as double
        if (!allGif)
        {
            mxSetFieldByNumber(out, 0,  7, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::bits_per_pixel, 0.));    // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0,  8, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::padding_per_pixel, 0.)); // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0,  9, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::width, 0.));             // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 10, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::height, 0.));            // 0. causes values to be stored as double
        }
        int off = 4 * (!allGif);
        mxSetFieldByNumber(out, 0,  7 + off, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::type, [](auto in_) {return TobiiResearchEyeImageToString(in_);}));
        mxSetFieldByNumber(out, 0,  8 + off, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::camera_id, 0.));       // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0,  9 + off, FieldToMatlab(data_, true, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::is_gif));
        mxSetFieldByNumber(out, 0, 10 + off, eyeImagesToMatlab(data_));

        return out;
    }

    mxArray* ToMatlab(std::vector<LSL_streamer::extSignal> data_)
    {
        const char* fieldNames[] = {"remote_system_time_stamp","local_system_time_stamp","deviceTimeStamp","systemTimeStamp","value","changeType"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &LSL_streamer::extSignal::remote_system_time_stamp));
        // 2. local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &LSL_streamer::extSignal::local_system_time_stamp));
        // 3. device timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &LSL_streamer::extSignal::extSignalData, &TobiiResearchExternalSignalData::device_time_stamp));
        // 4. system timestamps
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &LSL_streamer::extSignal::extSignalData, &TobiiResearchExternalSignalData::system_time_stamp));
        // 5. external signal values
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &LSL_streamer::extSignal::extSignalData, &TobiiResearchExternalSignalData::value));
        // 6. value change type
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &LSL_streamer::extSignal::extSignalData, &TobiiResearchExternalSignalData::change_type, uint8_t{}));      // cast enum values to uint8

        return out;
    }

    mxArray* ToMatlab(std::vector<LSL_streamer::timeSync> data_)
    {
        const char* fieldNames[] = {"remote_system_time_stamp","local_system_time_stamp","systemRequestTimeStamp","deviceTimeStamp","systemResponseTimeStamp"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &LSL_streamer::timeSync::remote_system_time_stamp));
        // 2. local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &LSL_streamer::timeSync::local_system_time_stamp));
        // 3. system request timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &LSL_streamer::timeSync::timeSyncData, &TobiiResearchTimeSynchronizationData::system_request_time_stamp));
        // 4. device timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &LSL_streamer::timeSync::timeSyncData, &TobiiResearchTimeSynchronizationData::device_time_stamp));
        // 5. system response timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &LSL_streamer::timeSync::timeSyncData, &TobiiResearchTimeSynchronizationData::system_response_time_stamp));

        return out;
    }

    mxArray* FieldToMatlab(const std::vector<LSL_streamer::positioning>& data_, bool rowVector_, TobiiResearchEyeUserPositionGuide TobiiResearchUserPositionGuide::* field_)
    {
        const char* fieldNames[] = {"user_position","valid"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1 user_position
        mxSetFieldByNumber(out, 0, 0, TobiiFieldToMatlab(data_, rowVector_, &LSL_streamer::positioning::positioningData, field_, &TobiiResearchEyeUserPositionGuide::user_position, 0.));    // 0. causes values to be stored as double
        // 2 validity
        mxSetFieldByNumber(out, 0, 1,      FieldToMatlab(data_, rowVector_, &LSL_streamer::positioning::positioningData, field_, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID));

        return out;
    }

    mxArray* ToMatlab(std::vector<LSL_streamer::positioning> data_)
    {
        const char* fieldNames[] = {"remote_system_time_stamp","local_system_time_stamp","left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &LSL_streamer::positioning::remote_system_time_stamp));
        // 2. local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &LSL_streamer::positioning::local_system_time_stamp));
        // 3. left  eye data
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TobiiResearchUserPositionGuide::left_eye));
        // 4. right eye data
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TobiiResearchUserPositionGuide::right_eye));

        return out;
    }
}


// function for handling errors generated by lib
[[ noreturn ]] void DoExitWithMsg(std::string errMsg_)
{
    // rethrow so we can catch in mexFunction and unwind stack there properly in the process
    throw errMsg_;
}
void RelayMsg(std::string msg_)
{
    mexPrintf("%s\n",msg_.c_str());
}
