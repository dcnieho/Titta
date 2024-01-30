// MEX wrapper for TittaLSL.
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
// Note that these goals should be achieved without regard to any MATLAB class,
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
#include "TittaLSL/TittaLSL.h"

namespace mxTypes
{
    // template specializations
    // NB: to get types output as a struct, specialize typeToMxClass for them (set mxClassID value = mxSTRUCT_CLASS)
    // NB: if a vector of such types with typeToMxClass is passed, a cell-array with the structs in them will be produced
    // NB: if you want an array-of-structs instead, also specialize typeNeedsMxCellStorage for the type (set bool value = false)
    template <>
    struct typeToMxClass<TobiiTypes::eyeTracker> { static constexpr mxClassID value = mxSTRUCT_CLASS; };
    template <>
    struct typeToMxClass<lsl::stream_info> { static constexpr mxClassID value = mxSTRUCT_CLASS; };

    template <>
    struct typeNeedsMxCellStorage<TobiiTypes::eyeTracker> { static constexpr bool value = false; };
    template <>
    struct typeNeedsMxCellStorage<lsl::stream_info> { static constexpr bool value = false; };

    // forward declarations
    template<typename Cont, typename... Fs>
    mxArray* TobiiFieldToMatlab(const Cont& data_, bool rowVectors_, Fs... fields);

    mxArray* ToMatlab(TobiiResearchSDKVersion                                   data_);
    mxArray* ToMatlab(TobiiTypes::eyeTracker data_, mwIndex idx_ = 0, mwSize size_ = 1, mxArray* storage_ = nullptr);
    mxArray* ToMatlab(lsl::stream_info       data_, mwIndex idx_ = 0, mwSize size_ = 1, mxArray* storage_ = nullptr);
    mxArray* ToMatlab(TobiiResearchCapabilities                                 data_);
    mxArray* ToMatlab(lsl::channel_format_t                                     data_);
    mxArray* ToMatlab(Titta::Stream                                             data_);

    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::gaze           >          data_);
    mxArray* FieldToMatlab(const std::vector<TittaLSL::Receiver::gaze>&         data_, bool rowVector_, TobiiTypes::eyeData Titta::gaze::* field_);
    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::eyeImage       >          data_);
    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::extSignal      >          data_);
    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::timeSync       >          data_);
    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::positioning    >          data_);
    mxArray* FieldToMatlab(const std::vector<TittaLSL::Receiver::positioning>&  data_, bool rowVector_, TobiiResearchEyeUserPositionGuide TobiiResearchUserPositionGuide::* field_);
}
#include "cpp_mex_helpers/mex_type_utils.h"

namespace {
    enum class ExportedType
    {
        Unknown,
        Sender,
        Receiver
    };
    const std::map<std::string, ExportedType> exportedTypesMap =
    {
        { "Sender",     ExportedType::Sender },
        { "Receiver",   ExportedType::Receiver },
    };

    template <class...> constexpr std::false_type always_false_t{};
    template <auto...> constexpr std::false_type always_false_nt{};
    template <ExportedType T> struct ExportedTypesEnumToClassType { static_assert(always_false_nt<T>, "ExportedTypesEnumToClassType not implemented for this enum value"); };
    template <>                struct ExportedTypesEnumToClassType<ExportedType::Sender>   { using type = TittaLSL::Sender; };
    template <>                struct ExportedTypesEnumToClassType<ExportedType::Receiver> { using type = TittaLSL::Receiver; };
    template <ExportedType T>
    using ExportedTypesEnumToClassType_t = typename ExportedTypesEnumToClassType<T>::type;

    template <typename T> struct classToExportedTypeEnum { static_assert(always_false_t<T>, "typeToMxClass not implemented for this type"); static constexpr ExportedType value = ExportedType::Unknown; };
    template <>           struct classToExportedTypeEnum<TittaLSL::Sender>   { static constexpr ExportedType value = ExportedType::Sender; };
    template <>           struct classToExportedTypeEnum<TittaLSL::Receiver> { static constexpr ExportedType value = ExportedType::Receiver; };
    template <typename T>
    constexpr ExportedType classToExportedTypeEnum_v = classToExportedTypeEnum<T>::value;

    std::string exportedTypeToString(const ExportedType type_)
    {
        auto v = std::find_if(exportedTypesMap.begin(), exportedTypesMap.end(), [&type_](auto p_) {return p_.second == type_; });
        if (v == exportedTypesMap.end())
            return "unknown";
        return v->first;
    }

    using handle_type = uint32_t;
    using instPtr_t = std::shared_ptr<void>;
    struct Instance
    {
        ExportedType type;
        instPtr_t   instance;
    };
    using instanceMap_type = std::map<handle_type, Instance>;   // alternative to Instance as value in the map is to have a variant over the various shared_ptr types. That is more unwieldy later when getting instances out of the map than what i have to do now, bunch of static_pointer_casts

    // List actions
    enum class Action
    {
        //// wrapper actions
        Touch,
        New,
        Delete,

        //// static functions
        GetTobiiSDKVersion,
        GetLSLVersion,


        //// convenience wrappers for Titta functions
        GetAllStreamsString,

        //// outlets
        GetEyeTracker,
        GetStreamSourceID,
        Start,
        SetIncludeEyeOpennessInGaze,
        IsStreaming,
        Stop,

        //// inlets
        GetStreams,
        GetInfo,
        GetType,
        // Start,
        IsRecording,
        ConsumeN,
        ConsumeTimeRange,
        PeekN,
        PeekTimeRange,
        Clear,
        ClearTimeRange,
        // Stop,
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        //// wrapper actions
        { "touch",                          Action::Touch },
        { "new",                            Action::New },
        { "delete",                         Action::Delete },

        //// static functions
        { "GetTobiiSDKVersion",             Action::GetTobiiSDKVersion },
        { "GetLSLVersion",                  Action::GetLSLVersion },

        //// convenience wrappers for Titta functions
        { "GetAllStreamsString",            Action::GetAllStreamsString },

        //// outlets
        { "getEyeTracker",                  Action::GetEyeTracker },
        { "getStreamSourceID",              Action::GetStreamSourceID },
        { "start",                          Action::Start },
        { "setIncludeEyeOpennessInGaze",    Action::SetIncludeEyeOpennessInGaze },
        { "isStreaming",                    Action::IsStreaming },
        { "stop",                           Action::Stop },

        //// inlets
        { "GetStreams",                     Action::GetStreams },
        { "getInfo",                        Action::GetInfo },
        { "getType",                        Action::GetType },
        { "start",                          Action::Start },
        { "isRecording",                    Action::IsRecording },
        { "consumeN",                       Action::ConsumeN },
        { "consumeTimeRange",               Action::ConsumeTimeRange },
        { "peekN",                          Action::PeekN },
        { "peekTimeRange",                  Action::PeekTimeRange },
        { "clear",                          Action::Clear },
        { "clearTimeRange",                 Action::ClearTimeRange },
        { "stop",                           Action::Stop },
    };


    // table mapping handles to instances
    static instanceMap_type instanceTable;
    // for unique handles
    std::atomic<handle_type> lastHandleVal = { 0 };

    // checkHandle gets the position in the instance table
    instanceMap_type::const_iterator checkHandle(const instanceMap_type& m_, const handle_type h_)
    {
        const auto it = m_.find(h_);
        if (it == m_.end())
            throw "TittaLSL::mex: No instance corresponding to handle " + std::to_string(h_) + " found.";
        return it;
    }

    template <typename T>
    handle_type registerHandle(std::shared_ptr<T> newInstance_, const ExportedType type_)
    {
        auto [iter, inserted] = instanceTable.emplace(++lastHandleVal, Instance{ type_, newInstance_ });

        if (!inserted) // sanity check
            throw "Oh, bad news. Tried to add an existing handle."; // shouldn't ever happen

        // add to the lock count
        mexLock();

        // return the handle
        return iter->first;
    }

    bool registeredAtExit = false;
    void atExitCleanUp()
    {
        instanceTable.clear();
    }
}

void mexFunction(int nlhs_, mxArray *plhs_[], int nrhs_, const mxArray *prhs_[])
{
    try
    {
        if (!registeredAtExit)
        {
            mexAtExit(&atExitCleanUp);
            registeredAtExit = true;
        }

        if (nrhs_ < 1 || !mxIsChar(prhs_[0]))
            throw "First input must be an action string ('touch', 'new', 'delete', or a method name).";

        // get action
        // get action string
        if (nrhs_ < 1 || !mxIsChar(prhs_[0]))
            throw "First input must be an action string ('touch', 'new', 'delete', 'parameterInterface', or a method name).";
        char* actionCstr = mxArrayToString(prhs_[0]);
        std::string actionStr(actionCstr);
        mxFree(actionCstr);

        // get corresponding action
        Action action;
        {
            auto it = actionTypeMap.find(actionStr);
            if (it == actionTypeMap.end())
                throw "Unrecognized action (not in actionTypeMap): " + std::string{ actionStr };
            action = it->second;
        }

        // below when we get an instance from the map, we cast it to one of the below
        std::shared_ptr<ExportedTypesEnumToClassType_t<ExportedType::Sender>>   senderInstance;
        std::shared_ptr<ExportedTypesEnumToClassType_t<ExportedType::Receiver>> receiverInstance;


        // If action is not "new" or others that don't require a handle, try to locate an existing instance based on input handle
        // for static class members, set the type only
        instanceMap_type::const_iterator instIt;
        auto type = ExportedType::Unknown;
        if (action == Action::Touch || action == Action::New || action == Action::GetTobiiSDKVersion || action == Action::GetLSLVersion || action == Action::GetAllStreamsString)
        {
            // no handle needed
        }
        else if (action == Action::GetStreams)
            type = ExportedType::Receiver;
        else
        {
            // All the below code that deals with passing instances around assumes the handle_type is unsigned int
            // check that assumption is valid (we didn't change the handle type)
            static_assert(std::is_same_v<handle_type, uint32_t>);

            if (nrhs_ < 2 || !mxIsScalar(prhs_[1]) || !mxIsUint32(prhs_[1]))
                throw "Specify an instance with an integer (uint32) handle.";
            auto handle = *static_cast<handle_type*>(mxGetData(prhs_[1]));
            instIt = checkHandle(instanceTable, handle);
            auto instance = instIt->second.instance;
            type = instIt->second.type;

            // now retrieve the original instance pointer
            switch (type)
            {
            case ExportedType::Sender:
                senderInstance = std::static_pointer_cast<ExportedTypesEnumToClassType_t<ExportedType::Sender>>(instance);
                break;
            case ExportedType::Receiver:
                receiverInstance = std::static_pointer_cast<ExportedTypesEnumToClassType_t<ExportedType::Receiver>>(instance);
                break;
            default:
                throw "Programmer error getting the shared_ptr: logic not implemented for type '" + exportedTypeToString(type) + "'";
            }
        }

        // execute action
        switch (action)
        {
        case Action::Touch:
            // no-op
            break;
        case Action::New:
            {
                if (nrhs_ < 2 || !mxIsChar(prhs_[1]))
                    throw "SWAG:new: argument indicating class type to construct (second argument) must be a string.";
                // NB: further inputs depend on which class we'll construct, and are thus checked later
                // NB: further inputs are numbered in the error message according to the position in the user-facing
                // MATLAB API, so as to not confuse user. So subtract two everywhere. This MEX file is not supposed
                // to be used directly without the wrapper MATLAB classes

                // get type to construct
                char* typeCstr = mxArrayToString(prhs_[1]);
                std::string typeStr(typeCstr);
                mxFree(typeCstr);

                // get corresponding type
                {
                    auto it = exportedTypesMap.find(typeStr);
                    if (it == exportedTypesMap.end())
                        throw "Unrecognized type (not in exportedTypesMap): " + typeStr;
                    type = it->second;
                }

                instPtr_t newInstance = nullptr;
                switch (type)
                {
                case ExportedType::Sender:
                    {
                        if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
                            throw "TittaLSL::Sender::constructor: First argument must be a string.";
                        char* address = mxArrayToString(prhs_[2]);
                        newInstance = std::make_shared<ExportedTypesEnumToClassType_t<ExportedType::Sender>>(address);
                        mxFree(address);
                        break;
                    }
                case ExportedType::Receiver:
                    {
                        if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
                            throw "TittaLSL::Receiver::constructor: First argument must be an LSL stream source identifier string.";

                        // get optional input arguments
                        std::optional<size_t> bufSize;
                        if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                        {
                            if (!mxIsUint64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                                throw "TittaLSL::Receiver::constructor: Expected second argument to be a uint64 scalar.";
                            auto temp = *static_cast<uint64_t*>(mxGetData(prhs_[3]));
                            bufSize = static_cast<size_t>(temp);
                        }
                        std::optional<bool> doStartRecording;
                        if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
                        {
                            if (!(mxIsDouble(prhs_[4]) && !mxIsComplex(prhs_[4]) && mxIsScalar(prhs_[4])) && !mxIsLogicalScalar(prhs_[4]))
                                throw "TittaLSL::Receiver::constructor: Expected third argument to be a logical scalar.";
                            doStartRecording = mxIsLogicalScalarTrue(prhs_[4]);
                        }

                        char* bufferCstr = mxArrayToString(prhs_[2]);
                        newInstance = std::make_shared<ExportedTypesEnumToClassType_t<ExportedType::Receiver>>(bufferCstr, bufSize, doStartRecording);
                        mxFree(bufferCstr);
                        break;
                    }
                default:
                    throw "Unhandled type";
                    break;
                }

                // store the new instance in our instance map and return it to matlab
                plhs_[0] = mxTypes::ToMatlab(registerHandle(newInstance, type));
                break;
            }
        case Action::Delete:
            {
                instanceTable.erase(instIt);    // erase from map
                // instance still held by one of the shared_ptrs at this stage.
                // this ref counter will be decremented at function end, and
                // should cause the instance itself to finally be deleted as no
                // more strong refs held (or soon after in case of camera,
                // since some other instance might still hold a locked weak_ptr)

                mexUnlock();
                plhs_[0] = mxTypes::ToMatlab(instanceTable.empty()); // info
                break;
            }

        case Action::GetTobiiSDKVersion:
            {
                plhs_[0] = mxTypes::ToMatlab(TittaLSL::getTobiiSDKVersion());
                break;
            }
        case Action::GetLSLVersion:
            {
                plhs_[0] = mxTypes::ToMatlab(TittaLSL::getLSLVersion());
                break;
            }

        case Action::GetAllStreamsString:
            {
                if (nrhs_ > 1)
                {
                    if (!mxIsChar(prhs_[1]) || mxIsComplex(prhs_[1]) || (!mxIsScalar(prhs_[1]) && !mxIsEmpty(prhs_[1])))
                        throw "getAllStreamsString: Expected first argument to be a char scalar or empty char array.";

                    char quoteChar[2] = { "\0" };
                    if (!mxIsEmpty(prhs_[1]))
                        quoteChar[0] = *static_cast<char*>(mxGetData(prhs_[1]));

                    if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                    {
                        if (!(mxIsDouble(prhs_[2]) && !mxIsComplex(prhs_[2]) && mxIsScalar(prhs_[2])) && !mxIsLogicalScalar(prhs_[2]))
                            throw "getAllStreamsString: Expected second argument to be a logical scalar.";
                        bool snakeCase = mxIsLogicalScalarTrue(prhs_[2]);

                        plhs_[0] = mxTypes::ToMatlab(Titta::getAllStreamsString(quoteChar, snakeCase, true));
                    }
                    else
                        plhs_[0] = mxTypes::ToMatlab(Titta::getAllStreamsString(quoteChar, false, true));
                }
                else
                    plhs_[0] = mxTypes::ToMatlab(Titta::getAllStreamsString("\"", false, true));
                return;
            }
        default:
            {
                // all other Actions are executed per class (NB: some actions exist for multiple classes, such as start/stop)
                switch (type)
                {
                    case ExportedType::Sender:
                        {
                            switch (action)
                            {
                            case Action::GetEyeTracker:
                            {
                                plhs_[0] = mxTypes::ToMatlab(senderInstance->getEyeTracker());
                                return;
                            }
                            case Action::GetStreamSourceID:
                            {
                                if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
                                    throw std::string("getStreamSourceID: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

                                char* bufferCstr = mxArrayToString(prhs_[2]);
                                plhs_[0] = mxTypes::ToMatlab(senderInstance->getStreamSourceID(bufferCstr));
                                mxFree(bufferCstr);
                                return;
                            }
                            case Action::Start:
                            {
                                if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
                                    throw std::string("start: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

                                // get optional input arguments
                                std::optional<bool> asGif;
                                if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                                {
                                    if (!(mxIsDouble(prhs_[3]) && !mxIsComplex(prhs_[3]) && mxIsScalar(prhs_[3])) && !mxIsLogicalScalar(prhs_[3]))
                                        throw "start: Expected second argument to be a logical scalar.";
                                    asGif = mxIsLogicalScalarTrue(prhs_[3]);
                                }

                                char* bufferCstr = mxArrayToString(prhs_[2]);
                                plhs_[0] = mxCreateLogicalScalar(senderInstance->start(bufferCstr, asGif));
                                mxFree(bufferCstr);
                                return;
                            }
                            case Action::SetIncludeEyeOpennessInGaze:
                            {
                                if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsScalar(prhs_[2]) || !mxIsLogicalScalar(prhs_[2]))
                                    throw "setIncludeEyeOpennessInGaze: First argument must be a logical scalar.";

                                bool include = mxIsLogicalScalarTrue(prhs_[2]);
                                senderInstance->setIncludeEyeOpennessInGaze(include);
                                break;
                            }
                            case Action::IsStreaming:
                            {
                                if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
                                    throw std::string("isStreaming: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

                                char* bufferCstr = mxArrayToString(prhs_[2]);
                                plhs_[0] = mxCreateLogicalScalar(senderInstance->isStreaming(bufferCstr));
                                mxFree(bufferCstr);
                                return;
                            }
                            case Action::Stop:
                            {
                                if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
                                    throw std::string("stop: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'", false, true) + ").");

                                char* bufferCstr = mxArrayToString(prhs_[2]);
                                senderInstance->stop(bufferCstr);
                                mxFree(bufferCstr);
                                return;
                            }
                                default:
                                    throw "Unhandled TittaLSL::Sender action: " + actionStr;
                                    break;
                            }
                        }
                    case ExportedType::Receiver:
                        {
                            switch (action)
                            {
                            case Action::GetStreams:
                            {
                                std::optional<std::string> stream;
                                if (nrhs_ > 1 && !mxIsEmpty(prhs_[1]))
                                {
                                    if (!mxIsChar(prhs_[1]))
                                        throw "TittaLSL::Receiver::GetStreams: Second argument must be a string.";
                                    char* c_stream = mxArrayToString(prhs_[1]);
                                    stream = c_stream;
                                    mxFree(c_stream);
                                }
                                plhs_[0] = mxTypes::ToMatlab(TittaLSL::Receiver::GetStreams(stream ? *stream : ""));
                                break;
                            }
                            case Action::GetInfo:
                            {
                                plhs_[0] = mxTypes::ToMatlab(receiverInstance->getInfo());
                                return;
                            }
                            case Action::GetType:
                            {
                                plhs_[0] = mxTypes::ToMatlab(receiverInstance->getType());
                                return;
                            }
                            case Action::Start:
                            {
                                receiverInstance->start();
                                return;
                            }
                            case Action::IsRecording:
                            {
                                plhs_[0] = mxCreateLogicalScalar(receiverInstance->isRecording());
                                return;
                            }
                            case Action::ConsumeN:
                            {
                                std::optional<size_t> nSamp;
                                if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                                {
                                    if (!mxIsUint64(prhs_[2]) || mxIsComplex(prhs_[2]) || !mxIsScalar(prhs_[2]))
                                        throw "consumeN: Expected second argument to be a uint64 scalar.";
                                    nSamp = *static_cast<size_t*>(mxGetData(prhs_[2]));
                                }
                                std::optional<Titta::BufferSide> side;
                                if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                                {
                                    if (!mxIsChar(prhs_[3]))
                                        throw "consumeN: Third input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                                    char* bufferCstr = mxArrayToString(prhs_[3]);
                                    side = Titta::stringToBufferSide(bufferCstr);
                                    mxFree(bufferCstr);
                                }

                                switch (receiverInstance->getType())
                                {
                                case Titta::Stream::Gaze:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeN<TittaLSL::Receiver::gaze>(nSamp, side));
                                    return;
                                case Titta::Stream::EyeImage:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeN<TittaLSL::Receiver::eyeImage>(nSamp, side));
                                    return;
                                case Titta::Stream::ExtSignal:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeN<TittaLSL::Receiver::extSignal>(nSamp, side));
                                    return;
                                case Titta::Stream::TimeSync:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeN<TittaLSL::Receiver::timeSync>(nSamp, side));
                                    return;
                                case Titta::Stream::Positioning:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeN<TittaLSL::Receiver::positioning>(nSamp, side));
                                    return;
                                }
                                return;
                            }
                            case Action::ConsumeTimeRange:
                            {
                                // get optional input arguments
                                std::optional<int64_t> timeStart;
                                if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                                {
                                    if (!mxIsInt64(prhs_[2]) || mxIsComplex(prhs_[2]) || !mxIsScalar(prhs_[2]))
                                        throw "clearTimeRange: Expected second argument to be a int64 scalar.";
                                    timeStart = *static_cast<int64_t*>(mxGetData(prhs_[2]));
                                }
                                std::optional<int64_t> timeEnd;
                                if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                                {
                                    if (!mxIsInt64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                                        throw "clearTimeRange: Expected third argument to be a int64 scalar.";
                                    timeEnd = *static_cast<int64_t*>(mxGetData(prhs_[3]));
                                }
                                std::optional<bool> timeIsLocalTime;
                                if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
                                {
                                    if (!(mxIsDouble(prhs_[4]) && !mxIsComplex(prhs_[4]) && mxIsScalar(prhs_[4])) && !mxIsLogicalScalar(prhs_[4]))
                                        throw "stop: Expected fourth argument to be a logical scalar.";
                                    timeIsLocalTime = mxIsLogicalScalarTrue(prhs_[4]);
                                }

                                switch (receiverInstance->getType())
                                {
                                case Titta::Stream::Gaze:
                                case Titta::Stream::EyeOpenness:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeTimeRange<TittaLSL::Receiver::gaze>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::EyeImage:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeTimeRange<TittaLSL::Receiver::eyeImage>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::ExtSignal:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeTimeRange<TittaLSL::Receiver::extSignal>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::TimeSync:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->consumeTimeRange<TittaLSL::Receiver::timeSync>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::Positioning:
                                    throw "consumeTimeRange: not supported for positioning stream.";
                                }
                                return;
                            }
                            case Action::PeekN:
                            {
                                // get optional input arguments
                                std::optional<size_t> nSamp;
                                if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                                {
                                    if (!mxIsUint64(prhs_[2]) || mxIsComplex(prhs_[2]) || !mxIsScalar(prhs_[2]))
                                        throw "peekN: Expected second argument to be a uint64 scalar.";
                                    nSamp = *static_cast<size_t*>(mxGetData(prhs_[2]));
                                }
                                std::optional<Titta::BufferSide> side;
                                if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                                {
                                    if (!mxIsChar(prhs_[3]))
                                        throw "peekN: Third input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                                    char* bufferCstr = mxArrayToString(prhs_[3]);
                                    side = Titta::stringToBufferSide(bufferCstr);
                                    mxFree(bufferCstr);
                                }

                                switch (receiverInstance->getType())
                                {
                                case Titta::Stream::Gaze:
                                case Titta::Stream::EyeOpenness:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekN<TittaLSL::Receiver::gaze>(nSamp, side));
                                    return;
                                case Titta::Stream::EyeImage:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekN<TittaLSL::Receiver::eyeImage>(nSamp, side));
                                    return;
                                case Titta::Stream::ExtSignal:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekN<TittaLSL::Receiver::extSignal>(nSamp, side));
                                    return;
                                case Titta::Stream::TimeSync:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekN<TittaLSL::Receiver::timeSync>(nSamp, side));
                                    return;
                                case Titta::Stream::Positioning:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekN<TittaLSL::Receiver::positioning>(nSamp, side));
                                    return;
                                }
                                return;
                            }
                            case Action::PeekTimeRange:
                            {
                                // get optional input arguments
                                std::optional<int64_t> timeStart;
                                if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                                {
                                    if (!mxIsInt64(prhs_[2]) || mxIsComplex(prhs_[2]) || !mxIsScalar(prhs_[2]))
                                        throw "clearTimeRange: Expected second argument to be a int64 scalar.";
                                    timeStart = *static_cast<int64_t*>(mxGetData(prhs_[2]));
                                }
                                std::optional<int64_t> timeEnd;
                                if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                                {
                                    if (!mxIsInt64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                                        throw "clearTimeRange: Expected third argument to be a int64 scalar.";
                                    timeEnd = *static_cast<int64_t*>(mxGetData(prhs_[3]));
                                }
                                std::optional<bool> timeIsLocalTime;
                                if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
                                {
                                    if (!(mxIsDouble(prhs_[4]) && !mxIsComplex(prhs_[4]) && mxIsScalar(prhs_[4])) && !mxIsLogicalScalar(prhs_[4]))
                                        throw "stop: Expected fourth argument to be a logical scalar.";
                                    timeIsLocalTime = mxIsLogicalScalarTrue(prhs_[4]);
                                }

                                switch (receiverInstance->getType())
                                {
                                case Titta::Stream::Gaze:
                                case Titta::Stream::EyeOpenness:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekTimeRange<TittaLSL::Receiver::gaze>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::EyeImage:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekTimeRange<TittaLSL::Receiver::eyeImage>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::ExtSignal:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekTimeRange<TittaLSL::Receiver::extSignal>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::TimeSync:
                                    plhs_[0] = mxTypes::ToMatlab(receiverInstance->peekTimeRange<TittaLSL::Receiver::timeSync>(timeStart, timeEnd, timeIsLocalTime));
                                    return;
                                case Titta::Stream::Positioning:
                                    throw "peekTimeRange: not supported for positioning stream.";
                                }
                                return;
                            }
                            case Action::Clear:
                            {
                                receiverInstance->clear();
                                break;
                            }
                            case Action::ClearTimeRange:
                            {
                                // get optional input arguments
                                std::optional<int64_t> timeStart;
                                if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                                {
                                    if (!mxIsInt64(prhs_[2]) || mxIsComplex(prhs_[2]) || !mxIsScalar(prhs_[2]))
                                        throw "clearTimeRange: Expected second argument to be a int64 scalar.";
                                    timeStart = *static_cast<int64_t*>(mxGetData(prhs_[2]));
                                }
                                std::optional<int64_t> timeEnd;
                                if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
                                {
                                    if (!mxIsInt64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                                        throw "clearTimeRange: Expected third argument to be a int64 scalar.";
                                    timeEnd = *static_cast<int64_t*>(mxGetData(prhs_[3]));
                                }
                                std::optional<bool> timeIsLocalTime;
                                if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
                                {
                                    if (!(mxIsDouble(prhs_[4]) && !mxIsComplex(prhs_[4]) && mxIsScalar(prhs_[4])) && !mxIsLogicalScalar(prhs_[4]))
                                        throw "stop: Expected fourth argument to be a logical scalar.";
                                    timeIsLocalTime = mxIsLogicalScalarTrue(prhs_[4]);
                                }

                                // get data stream identifier string, clear buffer
                                receiverInstance->clearTimeRange(timeStart, timeEnd, timeIsLocalTime);
                                break;
                            }
                            case Action::Stop:
                            {
                                // get optional input argument
                                std::optional<bool> clearBuffer;
                                if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
                                {
                                    if (!(mxIsDouble(prhs_[2]) && !mxIsComplex(prhs_[2]) && mxIsScalar(prhs_[2])) && !mxIsLogicalScalar(prhs_[2]))
                                        throw "stop: Expected second argument to be a logical scalar.";
                                    clearBuffer = mxIsLogicalScalarTrue(prhs_[2]);
                                }

                                // get data stream identifier string, stop buffering
                                receiverInstance->stop(clearBuffer);
                                break;
                            }
                                default:
                                    throw "Unhandled TittaLSL::Receiver action: " + actionStr;
                                    break;
                            }
                            break;
                        }
                    default:
                        throw "Unhandled type";
                        break;
                }
                break;
            }
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
        mexErrMsgTxt("TittaLSL: Unknown exception occurred");
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

    mxArray* eyeImagesToMatlab(const std::vector<TittaLSL::Receiver::eyeImage>& data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].eyeImageData.data_size;
        bool same = allEquals(data_, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::data_size, sz);
        // 2. then copy over the images to matlab
        mxArray* out;
        if (data_[0].eyeImageData.bits_per_pixel + data_[0].eyeImageData.padding_per_pixel != 8)
            throw "TittaLSL: eyeImagesToMatlab: non-8bit images not implemented";
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
        return ToMatlab(string_format("%d.%d.%d.%d", data_.major, data_.minor, data_.revision, data_.build));
    }

    mxArray* ToMatlab(TobiiResearchCapabilities data_)
    {
        std::vector<std::string> out;

        if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_SET_DISPLAY_AREA)
            out.emplace_back("CanSetDisplayArea");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL)
            out.emplace_back("HasExternalSignal");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES)
            out.emplace_back("HasEyeImages");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA)
            out.emplace_back("HasGazeData");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_HMD_GAZE_DATA)
            out.emplace_back("HasHMDGazeData");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_SCREEN_BASED_CALIBRATION)
            out.emplace_back("CanDoScreenBasedCalibration");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_HMD_BASED_CALIBRATION)
            out.emplace_back("CanDoHMDBasedCalibration");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_HMD_LENS_CONFIG)
            out.emplace_back("HasHMDLensConfig");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_MONOCULAR_CALIBRATION)
            out.emplace_back("CanDoMonocularCalibration");
        if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA)
            out.emplace_back("HasEyeOpennessData");

        return ToMatlab(out);
    }

    mxArray* ToMatlab(TobiiTypes::eyeTracker data_, mwIndex idx_/*=0*/, mwSize size_/*=1*/, mxArray* storage_/*=nullptr*/)
    {
        if (idx_ == 0)
        {
            const char* fieldNames[] = { "deviceName","serialNumber","model","firmwareVersion","runtimeVersion","address","frequency","trackingMode","capabilities","supportedFrequencies","supportedModes" };
            storage_ = mxCreateStructMatrix(size_, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            if (size_ == 0)
                return storage_;
        }

        mxSetFieldByNumber(storage_, idx_, 0, ToMatlab(data_.deviceName));
        mxSetFieldByNumber(storage_, idx_, 1, ToMatlab(data_.serialNumber));
        mxSetFieldByNumber(storage_, idx_, 2, ToMatlab(data_.model));
        mxSetFieldByNumber(storage_, idx_, 3, ToMatlab(data_.firmwareVersion));
        mxSetFieldByNumber(storage_, idx_, 4, ToMatlab(data_.runtimeVersion));
        mxSetFieldByNumber(storage_, idx_, 5, ToMatlab(data_.address));
        mxSetFieldByNumber(storage_, idx_, 6, ToMatlab(static_cast<double>(data_.frequency)));    // output as double, not single
        mxSetFieldByNumber(storage_, idx_, 7, ToMatlab(data_.trackingMode));
        mxSetFieldByNumber(storage_, idx_, 8, ToMatlab(data_.capabilities));
        mxSetFieldByNumber(storage_, idx_, 9, ToMatlab(std::vector<double>(data_.supportedFrequencies.begin(), data_.supportedFrequencies.end()))); // return frequencies as double, not single, precision
        mxSetFieldByNumber(storage_, idx_, 10, ToMatlab(data_.supportedModes));

        return storage_;
    }

    mxArray* ToMatlab(lsl::stream_info data_, mwIndex idx_/*=0*/, mwSize size_/*=1*/, mxArray* storage_/*=nullptr*/)
    {
        if (idx_ == 0)
        {
            const char* fieldNames[] = { "name","type","channel_count","nominal_srate","channel_format","source_id","version","created_at","uid","session_id","hostname","xml","channel_bytes","sample_bytes" };
            storage_ = mxCreateStructMatrix(size_, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            if (size_ == 0)
                return storage_;
        }

        mxSetFieldByNumber(storage_, idx_, 0, ToMatlab(data_.name()));
        mxSetFieldByNumber(storage_, idx_, 1, ToMatlab(data_.type()));
        mxSetFieldByNumber(storage_, idx_, 2, ToMatlab(data_.channel_count()));
        mxSetFieldByNumber(storage_, idx_, 3, ToMatlab(data_.nominal_srate()));
        mxSetFieldByNumber(storage_, idx_, 4, ToMatlab(data_.channel_format()));
        mxSetFieldByNumber(storage_, idx_, 5, ToMatlab(data_.source_id()));
        mxSetFieldByNumber(storage_, idx_, 6, ToMatlab(data_.version()));
        mxSetFieldByNumber(storage_, idx_, 7, ToMatlab(data_.created_at()));
        mxSetFieldByNumber(storage_, idx_, 8, ToMatlab(data_.uid()));
        mxSetFieldByNumber(storage_, idx_, 9, ToMatlab(data_.session_id()));
        mxSetFieldByNumber(storage_, idx_, 10, ToMatlab(data_.hostname()));
        mxSetFieldByNumber(storage_, idx_, 11, ToMatlab(data_.channel_bytes()));
        mxSetFieldByNumber(storage_, idx_, 12, ToMatlab(data_.sample_bytes()));
        mxSetFieldByNumber(storage_, idx_, 13, ToMatlab(data_.as_xml()));

        return storage_;
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

    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::gaze> data_)
    {
        const char* fieldNames[] = {"remoteSystemTimeStamp","localSystemTimeStamp","deviceTimeStamp","systemTimeStamp","left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. all remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TittaLSL::Receiver::gaze::remoteSystemTimeStamp));
        // 2. all local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TittaLSL::Receiver::gaze::localSystemTimeStamp));
        // 3. all device timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &TittaLSL::Receiver::gaze::gazeData, &Titta::gaze::device_time_stamp));
        // 4. all system timestamps
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &TittaLSL::Receiver::gaze::gazeData, &Titta::gaze::system_time_stamp));
        // 5. left  eye data
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &Titta::gaze::left_eye));
        // 6. right eye data
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &Titta::gaze::right_eye));

        return out;
    }
    mxArray* FieldToMatlab(const std::vector<TittaLSL::Receiver::gaze>& data_, bool rowVector_, TobiiTypes::eyeData Titta::gaze::* field_)
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
        mxSetFieldByNumber(temp, 0, 0, TobiiFieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_on_display_area, 0.));              // 0. causes values to be stored as double
        // 1.2 gazePoint.inUserCoords
        mxSetFieldByNumber(temp, 0, 1, TobiiFieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_in_user_coordinates, 0.));          // 0. causes values to be stored as double
        // 1.3 gazePoint.validity
        mxSetFieldByNumber(temp, 0, 2,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 1.4 gazePoint.available
        mxSetFieldByNumber(temp, 0, 3,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::available));

        // 2. pupil
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesPup)), fieldNamesPup));
        // 2.1 pupil.diameter
        mxSetFieldByNumber(temp, 0, 0,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::diameter, 0.));                                   // 0. causes values to be stored as double
        // 2.2 pupil.validity
        mxSetFieldByNumber(temp, 0, 1,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 2.3 pupil.available
        mxSetFieldByNumber(temp, 0, 2,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::available));

        // 3. gazeOrigin
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesGO)), fieldNamesGO));
        // 3.1 gazeOrigin.inUserCoords
        mxSetFieldByNumber(temp, 0, 0, TobiiFieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_user_coordinates, 0.));        // 0. causes values to be stored as double
        // 3.2 gazeOrigin.inTrackBoxCoords
        mxSetFieldByNumber(temp, 0, 1, TobiiFieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_track_box_coordinates, 0.));   // 0. causes values to be stored as double
        // 3.3 gazeOrigin.validity
        mxSetFieldByNumber(temp, 0, 2,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 3.4 gazeOrigin.available
        mxSetFieldByNumber(temp, 0, 3,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::available));

        // 4. eyeOpenness
        mxSetFieldByNumber(out, 0, 3, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesEO)), fieldNamesEO));
        // 4.1 eye_openness.diameter
        mxSetFieldByNumber(temp, 0, 0,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::diameter, 0.));                             // 0. causes values to be stored as double
        // 4.2 eye_openness.validity
        mxSetFieldByNumber(temp, 0, 1,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 4.3 eye_openness.available
        mxSetFieldByNumber(temp, 0, 2,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::available));

        return out;
    }

    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::eyeImage> data_)
    {
        // check if all gif, then don't output unneeded fields
        bool allGif = allEquals(data_, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::is_gif, true);

        // fieldnames for all structs
        mxArray* out;
        if (allGif)
        {
            const char* fieldNames[] = {"remoteSystemTimeStamp","localSystemTimeStamp","deviceTimeStamp","systemTimeStamp","regionID","regionTop","regionLeft","type","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }
        else
        {
            const char* fieldNames[] = {"remoteSystemTimeStamp","localSystemTimeStamp","deviceTimeStamp","systemTimeStamp","regionID","regionTop","regionLeft","bitsPerPixel","paddingPerPixel","width","height","type","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }

        // all simple fields
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::remoteSystemTimeStamp));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::localSystemTimeStamp));
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::device_time_stamp));
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::system_time_stamp));
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::region_id, 0.));             // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::region_top, 0.));            // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 6, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::region_left, 0.));           // 0. causes values to be stored as double
        if (!allGif)
        {
            mxSetFieldByNumber(out, 0,  7, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::bits_per_pixel, 0.));    // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0,  8, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::padding_per_pixel, 0.)); // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0,  9, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::width, 0.));             // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 10, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::height, 0.));            // 0. causes values to be stored as double
        }
        int off = 4 * (!allGif);
        mxSetFieldByNumber(out, 0,  7 + off, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::type, [](auto in_) {return TobiiResearchEyeImageToString(in_);}));
        mxSetFieldByNumber(out, 0,  8 + off, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::camera_id, 0.));       // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0,  9 + off, FieldToMatlab(data_, true, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::is_gif));
        mxSetFieldByNumber(out, 0, 10 + off, eyeImagesToMatlab(data_));

        return out;
    }

    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::extSignal> data_)
    {
        const char* fieldNames[] = {"remoteSystemTimeStamp","localSystemTimeStamp","deviceTimeStamp","systemTimeStamp","value","changeType"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TittaLSL::Receiver::extSignal::remoteSystemTimeStamp));
        // 2. local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TittaLSL::Receiver::extSignal::localSystemTimeStamp));
        // 3. device timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &TittaLSL::Receiver::extSignal::extSignalData, &TobiiResearchExternalSignalData::device_time_stamp));
        // 4. system timestamps
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &TittaLSL::Receiver::extSignal::extSignalData, &TobiiResearchExternalSignalData::system_time_stamp));
        // 5. external signal values
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &TittaLSL::Receiver::extSignal::extSignalData, &TobiiResearchExternalSignalData::value));
        // 6. value change type
        mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &TittaLSL::Receiver::extSignal::extSignalData, &TobiiResearchExternalSignalData::change_type, uint8_t{}));      // cast enum values to uint8

        return out;
    }

    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::timeSync> data_)
    {
        const char* fieldNames[] = {"remoteSystemTimeStamp","localSystemTimeStamp","systemRequestTimeStamp","deviceTimeStamp","systemResponseTimeStamp"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TittaLSL::Receiver::timeSync::remoteSystemTimeStamp));
        // 2. local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TittaLSL::Receiver::timeSync::localSystemTimeStamp));
        // 3. system request timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TittaLSL::Receiver::timeSync::timeSyncData, &TobiiResearchTimeSynchronizationData::system_request_time_stamp));
        // 4. device timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TittaLSL::Receiver::timeSync::timeSyncData, &TobiiResearchTimeSynchronizationData::device_time_stamp));
        // 5. system response timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &TittaLSL::Receiver::timeSync::timeSyncData, &TobiiResearchTimeSynchronizationData::system_response_time_stamp));

        return out;
    }

    mxArray* FieldToMatlab(const std::vector<TittaLSL::Receiver::positioning>& data_, bool rowVector_, TobiiResearchEyeUserPositionGuide TobiiResearchUserPositionGuide::* field_)
    {
        const char* fieldNames[] = {"userPosition","valid"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1 user_position
        mxSetFieldByNumber(out, 0, 0, TobiiFieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::positioning::positioningData, field_, &TobiiResearchEyeUserPositionGuide::user_position, 0.));    // 0. causes values to be stored as double
        // 2 validity
        mxSetFieldByNumber(out, 0, 1,      FieldToMatlab(data_, rowVector_, &TittaLSL::Receiver::positioning::positioningData, field_, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID));

        return out;
    }

    mxArray* ToMatlab(std::vector<TittaLSL::Receiver::positioning> data_)
    {
        const char* fieldNames[] = {"remoteSystemTimeStamp","localSystemTimeStamp","left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. remote system timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TittaLSL::Receiver::positioning::remoteSystemTimeStamp));
        // 2. local system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TittaLSL::Receiver::positioning::localSystemTimeStamp));
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
