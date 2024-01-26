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
namespace mxTypes
{
    // template specializations
    // NB: to get types output as a struct, specialize typeToMxClass for them (set mxClassID value = mxSTRUCT_CLASS)
    // NB: if a vector of such types with typeToMxClass is passed, a cell-array with the structs in them will be produced
    // NB: if you want an array-of-structs instead, also specialize typeNeedsMxCellStorage for the type (set bool value = false)
    template <>
    struct typeToMxClass<TobiiTypes::eyeTracker> { static constexpr mxClassID value = mxSTRUCT_CLASS; };
    template <>
    struct typeToMxClass<TobiiTypes::CalibrationPoint> { static constexpr mxClassID value = mxSTRUCT_CLASS; };
    template <>
    struct typeToMxClass<Titta::notification> { static constexpr mxClassID value = mxSTRUCT_CLASS; };

    template <>
    struct typeNeedsMxCellStorage<TobiiTypes::eyeTracker> { static constexpr bool value = false; };
    template <>
    struct typeNeedsMxCellStorage<TobiiTypes::CalibrationPoint> { static constexpr bool value = false; };
    template <>
    struct typeNeedsMxCellStorage<Titta::notification> { static constexpr bool value = false; };

    // forward declarations
    template<typename Cont, typename... Fs>
    mxArray* TobiiFieldToMatlab(const Cont& data_, bool rowVectors_, Fs... fields);

    mxArray* ToMatlab(TobiiResearchSDKVersion                           data_);
    mxArray* ToMatlab(TobiiTypes::eyeTracker data_, mwIndex idx_ = 0, mwSize size_ = 1, mxArray* storage_ = nullptr);
    mxArray* ToMatlab(TobiiResearchCapabilities                         data_);

    mxArray* ToMatlab(TobiiResearchTrackBox                             data_);
    mxArray* ToMatlab(TobiiResearchDisplayArea                          data_);
    mxArray* ToMatlab(TobiiResearchPoint3D                              data_);
    mxArray* ToMatlab(TobiiResearchLicenseValidationResult              data_);

    mxArray* ToMatlab(std::vector<Titta::gaze           >               data_);
    mxArray* FieldToMatlab(const std::vector<Titta::gaze>&              data_, bool rowVector_, TobiiTypes::eyeData Titta::gaze::* field_);
    mxArray* ToMatlab(std::vector<Titta::eyeImage       >               data_);
    mxArray* ToMatlab(std::vector<Titta::extSignal      >               data_);
    mxArray* ToMatlab(std::vector<Titta::timeSync       >               data_);
    mxArray* ToMatlab(std::vector<Titta::positioning    >               data_);
    mxArray* ToMatlab(Titta::logMessage                                 data_);
    mxArray* ToMatlab(Titta::streamError                                data_);
    mxArray* ToMatlab(Titta::notification data_, mwIndex idx_ = 0, mwSize size_ = 1, mxArray* storage_ = nullptr);
    mxArray* ToMatlab(TobiiTypes::CalibrationState                      data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkResult                 data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkItem                   data_);
    mxArray* ToMatlab(TobiiResearchStatus                               data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationAction                     data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationResult                     data_);
    mxArray* ToMatlab(TobiiResearchCalibrationStatus                    data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationPoint data_, mwIndex idx_ = 0, mwSize size_ = 1, mxArray* storage_ = nullptr);
    mxArray* ToMatlab(TobiiResearchNormalizedPoint2D                    data_);
    mxArray* ToMatlab(std::vector<TobiiResearchCalibrationSample>       data_);
    mxArray* FieldToMatlab(std::vector<TobiiResearchCalibrationSample>  data_, bool rowVector_, TobiiResearchCalibrationEyeData TobiiResearchCalibrationSample::* field_);
}
#include "cpp_mex_helpers/mex_type_utils.h"

namespace {
    using ClassType         = Titta;
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

        //// global SDK functions
        GetSDKVersion,
        GetSystemTimestamp,
        FindAllEyeTrackers,
        GetEyeTrackerFromAddress,
        // logging
        StartLogging,
        GetLog,
        StopLogging,
        // check functions for dummy mode
        CheckStream,
        CheckBufferSide,
        // data stream info
        GetAllStreamsString,
        GetAllBufferSidesString,

        //// eye-tracker specific getters and setters
        // getters
        GetEyeTrackerInfo,
        GetDeviceName,
        GetSerialNumber,
        GetModel,
        GetFirmwareVersion,
        GetRuntimeVersion,
        GetAddress,
        GetCapabilities,
        GetSupportedFrequencies,
        GetSupportedModes,
        GetFrequency,
        GetTrackingMode,
        GetTrackBox,
        GetDisplayArea,
        // setters
        SetDeviceName,
        SetFrequency,
        SetTrackingMode,
        // modifiers
        ApplyLicenses,
        ClearLicenses,

        //// calibration
        EnterCalibrationMode,
        IsInCalibrationMode,
        LeaveCalibrationMode,
        CalibrationCollectData,
        CalibrationDiscardData,
        CalibrationComputeAndApply,
        CalibrationGetData,
        CalibrationApplyData,
        CalibrationGetStatus,
        CalibrationRetrieveResult,

        //// data streams
        HasStream,
        SetIncludeEyeOpennessInGaze,
        Start,
        IsRecording,
        ConsumeN,
        ConsumeTimeRange,
        PeekN,
        PeekTimeRange,
        Clear,
        ClearTimeRange,
        Stop
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        // MATLAB interface
        { "touch",                          Action::Touch },
        { "new",                            Action::New },
        { "delete",                         Action::Delete },

        //// global SDK functions
        { "getSDKVersion",                  Action::GetSDKVersion },
        { "getSystemTimestamp",             Action::GetSystemTimestamp },
        { "findAllEyeTrackers",             Action::FindAllEyeTrackers },
        { "getEyeTrackerFromAddress",       Action::GetEyeTrackerFromAddress },
        // logging
        { "startLogging",                   Action::StartLogging },
        { "getLog",                         Action::GetLog },
        { "stopLogging",                    Action::StopLogging },
        // check functions for dummy mode
        { "checkStream",                    Action::CheckStream },
        { "checkBufferSide",                Action::CheckBufferSide },
        // data stream info
        { "getAllStreamsString",            Action::GetAllStreamsString },
        { "getAllBufferSidesString",        Action::GetAllBufferSidesString },

        //// eye-tracker specific getters and setters
        // getters
        { "getEyeTrackerInfo",              Action::GetEyeTrackerInfo },
        { "getDeviceName",                  Action::GetDeviceName },
        { "getSerialNumber",                Action::GetSerialNumber },
        { "getModel",                       Action::GetModel },
        { "getFirmwareVersion",             Action::GetFirmwareVersion },
        { "getRuntimeVersion",              Action::GetRuntimeVersion },
        { "getAddress",                     Action::GetAddress },
        { "getCapabilities",                Action::GetCapabilities },
        { "getSupportedFrequencies",        Action::GetSupportedFrequencies },
        { "getSupportedModes",              Action::GetSupportedModes },
        { "getFrequency",                   Action::GetFrequency },
        { "getTrackingMode",                Action::GetTrackingMode },
        { "getTrackBox",                    Action::GetTrackBox },
        { "getDisplayArea",                 Action::GetDisplayArea },
        // setters
        { "setDeviceName",                  Action::SetDeviceName },
        { "setFrequency",                   Action::SetFrequency },
        { "setTrackingMode",                Action::SetTrackingMode },
        // modifiers
        { "applyLicenses",                  Action::ApplyLicenses },
        { "clearLicenses",                  Action::ClearLicenses },

        //// calibration
        { "enterCalibrationMode",           Action::EnterCalibrationMode },
        { "isInCalibrationMode",            Action::IsInCalibrationMode },
        { "leaveCalibrationMode",           Action::LeaveCalibrationMode },
        { "calibrationCollectData",         Action::CalibrationCollectData },
        { "calibrationDiscardData",         Action::CalibrationDiscardData },
        { "calibrationComputeAndApply",     Action::CalibrationComputeAndApply },
        { "calibrationGetData",             Action::CalibrationGetData },
        { "calibrationApplyData",           Action::CalibrationApplyData },
        { "calibrationGetStatus",           Action::CalibrationGetStatus },
        { "calibrationRetrieveResult",      Action::CalibrationRetrieveResult },

        //// data streams
        { "hasStream",                      Action::HasStream },
        { "setIncludeEyeOpennessInGaze",    Action::SetIncludeEyeOpennessInGaze },
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
            throw string_format("No instance corresponding to handle %u found.", h);
        return it;
    }

    bool registeredAtExit = false;
    void atExitCleanUp()
    {
        instanceTab.clear();
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
            throw "First input must be an action string ('new', 'delete', or a method name).";

        // get action string
        char* actionCstr = mxArrayToString(prhs_[0]);
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
            action != Action::GetSDKVersion && action != Action::GetSystemTimestamp &&
            action != Action::FindAllEyeTrackers && action != Action::GetEyeTrackerFromAddress &&
            action != Action::StartLogging && action != Action::GetLog && action != Action::StopLogging &&
            action != Action::CheckStream && action != Action::CheckBufferSide &&
            action != Action::GetAllStreamsString && action != Action::GetAllBufferSidesString)
        {
            instIt = checkHandle(instanceTab, getHandle(nrhs_, prhs_));
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
            if (nrhs_ < 2 || !mxIsChar(prhs_[1]))
                throw "TittaMex: Second argument must be a string.";

            char* address = mxArrayToString(prhs_[1]);
            auto insResult = instanceTab.insert({ ++handleVal, std::make_shared<ClassType>(address) });
            mxFree(address);

            if (!insResult.second) // sanity check
                throw "Oh, bad news. Tried to add an existing handle."; // shouldn't ever happen
            else
                mexLock(); // add to the lock count

            // return the handle
            plhs_[0] = mxTypes::ToMatlab(insResult.first->first);

            break;
        }
        case Action::Delete:
        {
            instanceTab.erase(instIt);      // erase from map
            instance.reset();               // decrement ref count of shared pointer, should cause it to delete instance itself
            mexUnlock();
            plhs_[0] = mxCreateLogicalScalar(instanceTab.empty()); // info
            break;
        }

        case Action::GetSDKVersion:
        {
            plhs_[0] = mxTypes::ToMatlab(Titta::getSDKVersion());
            break;
        }
        case Action::GetSystemTimestamp:
        {
            plhs_[0] = mxTypes::ToMatlab(Titta::getSystemTimestamp());
            break;
        }
        case Action::FindAllEyeTrackers:
        {
            plhs_[0] = mxTypes::ToMatlab(Titta::findAllEyeTrackers());
            break;
        }
        case Action::GetEyeTrackerFromAddress:
        {
            if (nrhs_ < 2 || !mxIsChar(prhs_[1]))
                throw "TittaMex: Second argument must be a string.";

            char* address = mxArrayToString(prhs_[1]);
            auto insResult = instanceTab.insert({ ++handleVal, std::make_shared<ClassType>(address) });
            mxFree(address);

            plhs_[0] = mxTypes::ToMatlab(Titta::getEyeTrackerFromAddress(address));
            break;
        }
        case Action::StartLogging:
        {
            // get optional input argument
            std::optional<size_t> bufSize;
            if (nrhs_ > 1 && !mxIsEmpty(prhs_[1]))
            {
                if (!mxIsUint64(prhs_[1]) || mxIsComplex(prhs_[1]) || !mxIsScalar(prhs_[1]))
                    throw "startLogging: Expected first argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs_[1]));
                if (temp > SIZE_MAX)
                    throw "startLogging: Requesting preallocated buffer of a larger size than is possible on a 32bit platform.";
                bufSize = static_cast<size_t>(temp);
            }

            plhs_[0] = mxCreateLogicalScalar(Titta::startLogging(bufSize));
            return;
        }
        case Action::GetLog:
        {
            // get optional input argument
            std::optional<bool> clearBuffer;
            if (nrhs_ > 1 && !mxIsEmpty(prhs_[1]))
            {
                if (!(mxIsDouble(prhs_[1]) && !mxIsComplex(prhs_[1]) && mxIsScalar(prhs_[1])) && !mxIsLogicalScalar(prhs_[1]))
                    throw "getLog: Expected first argument to be a logical scalar.";
                clearBuffer = mxIsLogicalScalarTrue(prhs_[1]);
            }

            plhs_[0] = mxTypes::ToMatlab(Titta::getLog(clearBuffer));
            return;
        }
        case Action::StopLogging:
            plhs_[0] = mxCreateLogicalScalar(Titta::stopLogging());
            return;
        case Action::CheckStream:
        {
            if (nrhs_ < 2 || !mxIsChar(prhs_[1]))
            {
                std::string err = "checkStream: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string, check if valid
            char* bufferCstr = mxArrayToString(prhs_[1]);
            Titta::stringToStream(bufferCstr);
            mxFree(bufferCstr);
            plhs_[0] = mxCreateLogicalScalar(true);
            return;
        }
        case Action::CheckBufferSide:
        {
            if (nrhs_ < 2 || !mxIsChar(prhs_[1]))
            {
                std::string err = "checkBufferSide: First input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                throw err;
            }

            // get data stream identifier string, check if valid
            char* bufferCstr = mxArrayToString(prhs_[1]);
            Titta::stringToBufferSide(bufferCstr);
            mxFree(bufferCstr);
            plhs_[0] = mxCreateLogicalScalar(true);
            return;
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

                    plhs_[0] = mxTypes::ToMatlab(Titta::getAllStreamsString(quoteChar, snakeCase));
                }
                else
                    plhs_[0] = mxTypes::ToMatlab(Titta::getAllStreamsString(quoteChar));
            }
            else
                plhs_[0] = mxTypes::ToMatlab(Titta::getAllStreamsString());
            return;
        }
        case Action::GetAllBufferSidesString:
        {
            if (nrhs_ > 1)
            {
                if (!mxIsChar(prhs_[1]) || mxIsComplex(prhs_[1]) || (!mxIsScalar(prhs_[1]) && !mxIsEmpty(prhs_[1])))
                    throw "getAllBufferSidesString: Expected first argument to be a char scalar or empty char array.";
                char quoteChar[2] = { "\0" };
                if (!mxIsEmpty(prhs_[1]))
                    quoteChar[0] = *static_cast<char*>(mxGetData(prhs_[1]));
                plhs_[0] = mxTypes::ToMatlab(Titta::getAllBufferSidesString(quoteChar));
            }
            else
                plhs_[0] = mxTypes::ToMatlab(Titta::getAllBufferSidesString());
            return;
        }

        case Action::GetEyeTrackerInfo:
        {
            // put in vector so we don't have write another ToMatlab()
            std::vector<TobiiTypes::eyeTracker> temp;
            temp.push_back(instance->getEyeTrackerInfo());
            plhs_[0] = mxTypes::ToMatlab(temp);
            break;
        }
        case Action::GetDeviceName:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("deviceName").deviceName);
            break;
        }
        case Action::GetSerialNumber:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("serialNumber").serialNumber);
            break;
        }
        case Action::GetModel:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("model").model);
            break;
        }
        case Action::GetFirmwareVersion:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("firmwareVersion").firmwareVersion);
            break;
        }
        case Action::GetRuntimeVersion:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("runtimeVersion").runtimeVersion);
            break;
        }
        case Action::GetAddress:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("address").address);
            break;
        }
        case Action::GetCapabilities:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("capabilities").capabilities);
            break;
        }
        case Action::GetSupportedFrequencies:
        {
            // return as doubles
            std::vector<double> freqs;
            for (float f : instance->getEyeTrackerInfo("supportedFrequencies").supportedFrequencies)
                freqs.push_back(static_cast<double>(f));
            plhs_[0] = mxTypes::ToMatlab(freqs);
            break;
        }
        case Action::GetSupportedModes:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("supportedModes").supportedModes);
            break;
        }
        case Action::GetFrequency:
        {
            plhs_[0] = mxTypes::ToMatlab(static_cast<double>(instance->getEyeTrackerInfo("frequency").frequency));
            break;
        }
        case Action::GetTrackingMode:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getEyeTrackerInfo("trackingMode").trackingMode);
            break;
        }
        case Action::GetTrackBox:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getTrackBox());
            break;
        }
        case Action::GetDisplayArea:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->getDisplayArea());
            break;
        }
        case Action::SetDeviceName:
        {
            if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsChar(prhs_[2]))
                throw "setDeviceName: Expected second argument to be a string.";

            char* bufferCstr = mxArrayToString(prhs_[2]);
            instance->setDeviceName(bufferCstr);
            mxFree(bufferCstr);
            break;
        }
        case Action::SetFrequency:
        {
            double freq = 0.;
            if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsDouble(prhs_[2]) || mxIsComplex(prhs_[2]) || !mxIsScalar(prhs_[2]))
                throw "setFrequency: Expected second argument to be a double scalar.";
            freq = *static_cast<double*>(mxGetData(prhs_[2]));

            instance->setFrequency(static_cast<float>(freq));
            break;
        }
        case Action::SetTrackingMode:
        {
            if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsChar(prhs_[2]))
                throw "setTrackingMode: Expected second argument to be a string.";

            char* bufferCstr = mxArrayToString(prhs_[2]);
            instance->setTrackingMode(bufferCstr);
            mxFree(bufferCstr);
            break;
        }
        case Action::ApplyLicenses:
        {
            if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsCell(prhs_[2]))
                throw "applyLicenses: Expected second argument to be a cell.";

            std::vector<std::vector<uint8_t>> licenses;

            // get how many elements the cell has, iterate over them (don't care about shape)
            const auto nElem = static_cast<mwIndex>(mxGetNumberOfElements(prhs_[2]));
            for (mwIndex i = 0; i < nElem; i++)
            {
                mxArray* cellElement = mxGetCell(prhs_[2], i);
                if (!cellElement)
                    throw "applyLicenses: All cell elements should be non-empty.";
                // we've got some kind of cell content, lets check it, and then access it
                if (mxIsEmpty(cellElement) || !mxIsUint8(cellElement) || mxIsComplex(cellElement))
                    throw "applyLicenses: All cells should contain arrays of uint8.";
                // now get content, copy over
                uint8_t* in = static_cast<uint8_t*>(mxGetData(cellElement));
                licenses.emplace_back(in, in + mxGetNumberOfElements(cellElement));
            }

            plhs_[0] = mxTypes::ToMatlab(instance->applyLicenses(licenses));
            break;
        }
        case Action::ClearLicenses:
        {
            instance->clearLicenses();
            break;
        }

        case Action::EnterCalibrationMode:
        {
            if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsScalar(prhs_[2]) || !mxIsLogicalScalar(prhs_[2]))
                throw "enterCalibrationMode: First argument must be a logical scalar.";

            bool doMonocular = mxIsLogicalScalarTrue(prhs_[2]);
            plhs_[0] = mxTypes::ToMatlab(instance->enterCalibrationMode(doMonocular));
            break;
        }
        case Action::IsInCalibrationMode:
        {
            std::optional<bool> issueErrorIfNot;
            if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
            {
                if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsScalar(prhs_[2]) || !mxIsLogicalScalar(prhs_[2]))
                    throw "isInCalibrationMode: First argument must be a logical scalar.";
                issueErrorIfNot = mxIsLogicalScalarTrue(prhs_[2]);
            }

            plhs_[0] = mxTypes::ToMatlab(instance->isInCalibrationMode(issueErrorIfNot));
            break;
        }
        case Action::LeaveCalibrationMode:
        {
            std::optional<bool> force;
            if (nrhs_ > 2 && !mxIsEmpty(prhs_[2]))
            {
                if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsScalar(prhs_[2]) || !mxIsLogicalScalar(prhs_[2]))
                    throw "leaveCalibrationMode: First argument must be a logical scalar.";
                force = mxIsLogicalScalarTrue(prhs_[2]);
            }

            plhs_[0] = mxTypes::ToMatlab(instance->leaveCalibrationMode(force));
            break;
        }
        case Action::CalibrationCollectData:
        {
            if (nrhs_ < 3 || !mxIsDouble(prhs_[2]) || mxIsComplex(prhs_[2]) || mxGetNumberOfElements(prhs_[2]) != 2)
                throw "calibrationCollectData: First argument must be a 2-element double array.";
            double* dat = static_cast<double*>(mxGetData(prhs_[2]));
            std::array<float, 2> point{ static_cast<float>(*dat), static_cast<float>(*(dat + 1)) };

            // get optional input argument
            std::optional<std::string> eye;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsChar(prhs_[3]))
                    throw "calibrationCollectData: Expected second argument to be a char array.";
                char* ceye = mxArrayToString(prhs_[3]);
                eye = ceye;
                mxFree(ceye);
            }

            instance->calibrationCollectData(point, eye);
            break;
        }
        case Action::CalibrationDiscardData:
        {
            if (nrhs_ < 3 || !mxIsDouble(prhs_[2]) || mxIsComplex(prhs_[2]) || mxGetNumberOfElements(prhs_[2]) != 2)
                throw "calibrationDiscardData: First argument must be a 2-element double array.";
            double* dat = static_cast<double*>(mxGetData(prhs_[2]));
            std::array<float, 2> point{ static_cast<float>(*dat), static_cast<float>(*(dat + 1)) };

            // get optional input argument
            std::optional<std::string> eye;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsChar(prhs_[3]))
                    throw "calibrationDiscardData: Expected second argument to be a char array.";
                char* ceye = mxArrayToString(prhs_[3]);
                eye = ceye;
                mxFree(ceye);
            }

            instance->calibrationDiscardData(point, eye);
            break;
        }
        case Action::CalibrationComputeAndApply:
        {
            instance->calibrationComputeAndApply();
            break;
        }
        case Action::CalibrationGetData:
        {
            instance->calibrationGetData();
            break;
        }
        case Action::CalibrationApplyData:
        {
            if (nrhs_ < 3 || !mxIsUint8(prhs_[2]) || mxIsComplex(prhs_[2]) || mxIsEmpty(prhs_[2]))
                throw "calibrationApplyData: First argument must be a n-element uint8 array, as returned from calibrationGetData.";
            uint8_t* in = static_cast<uint8_t*>(mxGetData(prhs_[2]));
            std::vector<uint8_t> calData{ in, in + mxGetNumberOfElements(prhs_[2]) };

            instance->calibrationApplyData(calData);
            break;
        }
        case Action::CalibrationGetStatus:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->calibrationGetStatus());
            break;
        }
        case Action::CalibrationRetrieveResult:
        {
            plhs_[0] = mxTypes::ToMatlab(instance->calibrationRetrieveResult(true));
            break;
        }

        case Action::HasStream:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "hasStream: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string, call hasStream() on instance
            char* bufferCstr = mxArrayToString(prhs_[2]);
            plhs_[0] = mxCreateLogicalScalar(instance->hasStream(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::SetIncludeEyeOpennessInGaze:
        {
            if (nrhs_ < 3 || mxIsEmpty(prhs_[2]) || !mxIsScalar(prhs_[2]) || !mxIsLogicalScalar(prhs_[2]))
                throw "setIncludeEyeOpennessInGaze: First argument must be a logical scalar.";

            bool include = mxIsLogicalScalarTrue(prhs_[2]);
            plhs_[0] = mxCreateLogicalScalar(instance->setIncludeEyeOpennessInGaze(include));
            break;
        }
        case Action::Start:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "start: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get optional input arguments
            std::optional<size_t> bufSize;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsUint64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                    throw "start: Expected second argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs_[3]));
                bufSize = static_cast<size_t>(temp);
            }
            std::optional<bool> asGif;
            if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
            {
                if (!(mxIsDouble(prhs_[4]) && !mxIsComplex(prhs_[4]) && mxIsScalar(prhs_[4])) && !mxIsLogicalScalar(prhs_[4]))
                    throw "start: Expected third argument to be a logical scalar.";
                asGif = mxIsLogicalScalarTrue(prhs_[4]);
            }

            // get data stream identifier string, call start() on instance
            char* bufferCstr = mxArrayToString(prhs_[2]);
            plhs_[0] = mxCreateLogicalScalar(instance->start(bufferCstr, bufSize, asGif));
            mxFree(bufferCstr);
            return;
        }
        case Action::IsRecording:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "isRecording: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string, call isBuffering() on instance
            char* bufferCstr = mxArrayToString(prhs_[2]);
            plhs_[0] = mxCreateLogicalScalar(instance->isRecording(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::ConsumeN:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "consumeN: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string
            char* bufferCstr = mxArrayToString(prhs_[2]);
            Titta::Stream stream = instance->stringToStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input arguments
            std::optional<size_t> nSamp;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsUint64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                    throw "consumeN: Expected second argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs_[3]));
                if (temp > SIZE_MAX)
                    throw "consumeN: Requesting preallocated buffer of a larger size than is possible on a 32bit platform.";
                nSamp = static_cast<size_t>(temp);
            }
            std::optional<Titta::BufferSide> side;
            if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
            {
                if (!mxIsChar(prhs_[4]))
                {
                    std::string err = "consumeN: Third input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                    throw err;
                }
                char* bufferCstr = mxArrayToString(prhs_[4]);
                side = instance->stringToBufferSide(bufferCstr);
                mxFree(bufferCstr);
            }

            switch (stream)
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeN<Titta::gaze>(nSamp, side));
                return;
            case Titta::Stream::EyeImage:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeN<Titta::eyeImage>(nSamp, side));
                return;
            case Titta::Stream::ExtSignal:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeN<Titta::extSignal>(nSamp, side));
                return;
            case Titta::Stream::TimeSync:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeN<Titta::timeSync>(nSamp, side));
                return;
            case Titta::Stream::Positioning:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeN<Titta::positioning>(nSamp, side));
                return;
            case Titta::Stream::Notification:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeN<Titta::notification>(nSamp, side));
                return;
            }
        }
        case Action::ConsumeTimeRange:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "consumeTimeRange: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string
            char* bufferCstr = mxArrayToString(prhs_[2]);
            Titta::Stream stream = instance->stringToStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsInt64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                    throw "consumeTimeRange: Expected second argument to be a int64 scalar.";
                timeStart = *static_cast<int64_t*>(mxGetData(prhs_[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
            {
                if (!mxIsInt64(prhs_[4]) || mxIsComplex(prhs_[4]) || !mxIsScalar(prhs_[4]))
                    throw "consumeTimeRange: Expected third argument to be a int64 scalar.";
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs_[4]));
            }

            switch (stream)
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeTimeRange<Titta::gaze>(timeStart, timeEnd));
                return;
            case Titta::Stream::EyeImage:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeTimeRange<Titta::eyeImage>(timeStart, timeEnd));
                return;
            case Titta::Stream::ExtSignal:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeTimeRange<Titta::extSignal>(timeStart, timeEnd));
                return;
            case Titta::Stream::TimeSync:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeTimeRange<Titta::timeSync>(timeStart, timeEnd));
                return;
            case Titta::Stream::Positioning:
                throw "consumeTimeRange: not supported for positioning stream.";
                return;
            case Titta::Stream::Notification:
                plhs_[0] = mxTypes::ToMatlab(instance->consumeTimeRange<Titta::notification>(timeStart, timeEnd));
                return;
            }
        }
        case Action::PeekN:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "peekN: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string
            char* bufferCstr = mxArrayToString(prhs_[2]);
            Titta::Stream stream = instance->stringToStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input arguments
            std::optional<size_t> nSamp;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsUint64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                    throw "peekN: Expected second argument to be a uint64 scalar.";
                auto temp = *static_cast<uint64_t*>(mxGetData(prhs_[3]));
                if (temp > SIZE_MAX)
                    throw "peekN: Requesting preallocated buffer of a larger size than is possible on a 32bit platform.";
                nSamp = static_cast<size_t>(temp);
            }
            std::optional<Titta::BufferSide> side;
            if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
            {
                if (!mxIsChar(prhs_[4]))
                {
                    std::string err = "peekN: Third input must be a buffer side identifier string (" + Titta::getAllBufferSidesString("'") + ").";
                    throw err;
                }
                char* bufferCstr = mxArrayToString(prhs_[4]);
                side = instance->stringToBufferSide(bufferCstr);
                mxFree(bufferCstr);
            }

            switch (stream)
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs_[0] = mxTypes::ToMatlab(instance->peekN<Titta::gaze>(nSamp, side));
                return;
            case Titta::Stream::EyeImage:
                plhs_[0] = mxTypes::ToMatlab(instance->peekN<Titta::eyeImage>(nSamp, side));
                return;
            case Titta::Stream::ExtSignal:
                plhs_[0] = mxTypes::ToMatlab(instance->peekN<Titta::extSignal>(nSamp, side));
                return;
            case Titta::Stream::TimeSync:
                plhs_[0] = mxTypes::ToMatlab(instance->peekN<Titta::timeSync>(nSamp, side));
                return;
            case Titta::Stream::Positioning:
                plhs_[0] = mxTypes::ToMatlab(instance->peekN<Titta::positioning>(nSamp, side));
                return;
            case Titta::Stream::Notification:
                plhs_[0] = mxTypes::ToMatlab(instance->peekN<Titta::notification>(nSamp, side));
                return;
            }
        }
        case Action::PeekTimeRange:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "peekTimeRange: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string
            char* bufferCstr = mxArrayToString(prhs_[2]);
            Titta::Stream stream = instance->stringToStream(bufferCstr);
            mxFree(bufferCstr);

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsInt64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                    throw "peekTimeRange: Expected second argument to be a int64 scalar.";
                timeStart = *static_cast<int64_t*>(mxGetData(prhs_[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
            {
                if (!mxIsInt64(prhs_[4]) || mxIsComplex(prhs_[4]) || !mxIsScalar(prhs_[4]))
                    throw "peekTimeRange: Expected third argument to be a int64 scalar.";
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs_[4]));
            }

            switch (stream)
            {
            case Titta::Stream::Gaze:
            case Titta::Stream::EyeOpenness:
                plhs_[0] = mxTypes::ToMatlab(instance->peekTimeRange<Titta::gaze>(timeStart, timeEnd));
                return;
            case Titta::Stream::EyeImage:
                plhs_[0] = mxTypes::ToMatlab(instance->peekTimeRange<Titta::eyeImage>(timeStart, timeEnd));
                return;
            case Titta::Stream::ExtSignal:
                plhs_[0] = mxTypes::ToMatlab(instance->peekTimeRange<Titta::extSignal>(timeStart, timeEnd));
                return;
            case Titta::Stream::TimeSync:
                plhs_[0] = mxTypes::ToMatlab(instance->peekTimeRange<Titta::timeSync>(timeStart, timeEnd));
                return;
            case Titta::Stream::Positioning:
                throw "peekTimeRange: not supported for positioning stream.";
                return;
            case Titta::Stream::Notification:
                plhs_[0] = mxTypes::ToMatlab(instance->peekTimeRange<Titta::notification>(timeStart, timeEnd));
                return;
            }
        }
        case Action::Clear:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "clear: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get data stream identifier string, clear buffer
            char* bufferCstr = mxArrayToString(prhs_[2]);
            instance->clear(bufferCstr);
            mxFree(bufferCstr);
            break;
        }
        case Action::ClearTimeRange:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "clearTimeRange: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get optional input arguments
            std::optional<int64_t> timeStart;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!mxIsInt64(prhs_[3]) || mxIsComplex(prhs_[3]) || !mxIsScalar(prhs_[3]))
                    throw "clearTimeRange: Expected second argument to be a int64 scalar.";
                timeStart = *static_cast<int64_t*>(mxGetData(prhs_[3]));
            }
            std::optional<int64_t> timeEnd;
            if (nrhs_ > 4 && !mxIsEmpty(prhs_[4]))
            {
                if (!mxIsInt64(prhs_[4]) || mxIsComplex(prhs_[4]) || !mxIsScalar(prhs_[4]))
                    throw "clearTimeRange: Expected third argument to be a int64 scalar.";
                timeEnd = *static_cast<int64_t*>(mxGetData(prhs_[4]));
            }

            // get data stream identifier string, clear buffer
            char* bufferCstr = mxArrayToString(prhs_[2]);
            instance->clearTimeRange(bufferCstr, timeStart, timeEnd);
            mxFree(bufferCstr);
            break;
        }
        case Action::Stop:
        {
            if (nrhs_ < 3 || !mxIsChar(prhs_[2]))
            {
                std::string err = "stop: First input must be a data stream identifier string (" + Titta::getAllStreamsString("'") + ").";
                throw err;
            }

            // get optional input argument
            std::optional<bool> clearBuffer;
            if (nrhs_ > 3 && !mxIsEmpty(prhs_[3]))
            {
                if (!(mxIsDouble(prhs_[3]) && !mxIsComplex(prhs_[3]) && mxIsScalar(prhs_[3])) && !mxIsLogicalScalar(prhs_[3]))
                    throw "stop: Expected second argument to be a logical scalar.";
                clearBuffer = mxIsLogicalScalarTrue(prhs_[3]);
            }

            // get data stream identifier string, stop buffering
            char* bufferCstr = mxArrayToString(prhs_[2]);
            plhs_[0] = mxCreateLogicalScalar(instance->stop(bufferCstr, clearBuffer));
            mxFree(bufferCstr);
            break;
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
        mexErrMsgTxt("Titta: Unknown exception occurred");
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

    mxArray* eyeImagesToMatlab(const std::vector<Titta::eyeImage>& data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].data_size;
        bool same = allEquals(data_, &Titta::eyeImage::data_size, sz);
        // 2. then copy over the images to matlab
        mxArray* out;
        if (data_[0].bits_per_pixel + data_[0].padding_per_pixel != 8)
            throw "Titta: eyeImagesToMatlab: non-8bit images not implemented";
        if (same)
        {
            auto storage = static_cast<uint8_t*>(mxGetData(out = mxCreateUninitNumericMatrix(static_cast<size_t>(data_[0].width)*data_[0].height, data_.size(), mxUINT8_CLASS, mxREAL)));
            size_t i = 0;
            for (auto &frame : data_)
                std::memcpy(storage + (i++)*sz, frame.data(), frame.data_size);
        }
        else
        {
            out = mxCreateCellMatrix(1, static_cast<mwSize>(data_.size()));
            mwIndex i = 0;
            for (auto &frame : data_)
            {
                mxArray* temp;
                auto storage = static_cast<uint8_t*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, static_cast<size_t>(frame.width)*frame.height, mxUINT8_CLASS, mxREAL)));
                std::memcpy(storage, frame.data(), frame.data_size);
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
    mxArray* ToMatlab(TobiiTypes::eyeTracker data_, mwIndex idx_/*=0*/, mwSize size_/*=1*/, mxArray* storage_/*=nullptr*/)
    {
        if (idx_ == 0)
        {
            const char* fieldNames[] = { "deviceName","serialNumber","model","firmwareVersion","runtimeVersion","address","frequency","trackingMode","capabilities","supportedFrequencies","supportedModes" };
            storage_ = mxCreateStructMatrix(size_, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            if (size_ == 0)
                return storage_;
        }

        mxSetFieldByNumber(storage_, idx_,  0, ToMatlab(data_.deviceName));
        mxSetFieldByNumber(storage_, idx_,  1, ToMatlab(data_.serialNumber));
        mxSetFieldByNumber(storage_, idx_,  2, ToMatlab(data_.model));
        mxSetFieldByNumber(storage_, idx_,  3, ToMatlab(data_.firmwareVersion));
        mxSetFieldByNumber(storage_, idx_,  4, ToMatlab(data_.runtimeVersion));
        mxSetFieldByNumber(storage_, idx_,  5, ToMatlab(data_.address));
        mxSetFieldByNumber(storage_, idx_,  6, ToMatlab(static_cast<double>(data_.frequency)));    // output as double, not single
        mxSetFieldByNumber(storage_, idx_,  7, ToMatlab(data_.trackingMode));
        mxSetFieldByNumber(storage_, idx_,  8, ToMatlab(data_.capabilities));
        mxSetFieldByNumber(storage_, idx_,  9, ToMatlab(std::vector<double>(data_.supportedFrequencies.begin(), data_.supportedFrequencies.end()))); // return frequencies as double, not single, precision
        mxSetFieldByNumber(storage_, idx_, 10, ToMatlab(data_.supportedModes));

        return storage_;
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

    mxArray* ToMatlab(TobiiResearchTrackBox data_)
    {
        const char* fieldNames[] = {"backLowerLeft","backLowerRight","backUpperLeft","backUpperRight","frontLowerLeft","frontLowerRight","frontUpperLeft","frontUpperRight"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.back_lower_left));
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.back_lower_right));
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.back_upper_left));
        mxSetFieldByNumber(out, 0, 3, ToMatlab(data_.back_upper_right));
        mxSetFieldByNumber(out, 0, 4, ToMatlab(data_.front_lower_left));
        mxSetFieldByNumber(out, 0, 5, ToMatlab(data_.front_lower_right));
        mxSetFieldByNumber(out, 0, 6, ToMatlab(data_.front_upper_left));
        mxSetFieldByNumber(out, 0, 7, ToMatlab(data_.front_upper_right));

        return out;
    }
    mxArray* ToMatlab(TobiiResearchDisplayArea data_)
    {
        const char* fieldNames[] = {"height","width","bottomLeft","bottomRight","topLeft","topRight"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        mxSetFieldByNumber(out, 0, 0, ToMatlab(static_cast<double>(data_.height)));
        mxSetFieldByNumber(out, 0, 1, ToMatlab(static_cast<double>(data_.width)));
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.bottom_left));
        mxSetFieldByNumber(out, 0, 3, ToMatlab(data_.bottom_right));
        mxSetFieldByNumber(out, 0, 4, ToMatlab(data_.top_left));
        mxSetFieldByNumber(out, 0, 5, ToMatlab(data_.top_right));

        return out;
    }
    mxArray* ToMatlab(TobiiResearchPoint3D data_)
    {
        mxArray* out = mxCreateDoubleMatrix(3, 1, mxREAL);
        auto storage = static_cast<double*>(mxGetData(out));
        storage[0] = static_cast<double>(data_.x);
        storage[1] = static_cast<double>(data_.y);
        storage[2] = static_cast<double>(data_.z);
        return out;
    }
    mxArray* ToMatlab(TobiiResearchLicenseValidationResult data_)
    {
        return ToMatlab(TobiiResearchLicenseValidationResultToString(data_));
    }

    mxArray* ToMatlab(std::vector<Titta::gaze> data_)
    {
        const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. all device timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &Titta::gaze::device_time_stamp));
        // 2. all system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &Titta::gaze::system_time_stamp));
        // 3. left  eye data
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &Titta::gaze::left_eye));
        // 4. right eye data
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &Titta::gaze::right_eye));

        return out;
    }
    mxArray* FieldToMatlab(const std::vector<Titta::gaze>& data_, bool rowVector_, TobiiTypes::eyeData Titta::gaze::* field_)
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
        mxSetFieldByNumber(temp, 0, 0, TobiiFieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_on_display_area, 0.));              // 0. causes values to be stored as double
        // 1.2 gazePoint.inUserCoords
        mxSetFieldByNumber(temp, 0, 1, TobiiFieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_in_user_coordinates, 0.));          // 0. causes values to be stored as double
        // 1.3 gazePoint.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 1.4 gazePoint.available
        mxSetFieldByNumber(temp, 0, 3, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::available));

        // 2. pupil
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesPup)), fieldNamesPup));
        // 2.1 pupil.diameter
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::diameter, 0.));                                   // 0. causes values to be stored as double
        // 2.2 pupil.validity
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 2.3 pupil.available
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::available));

        // 3. gazeOrigin
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesGO)), fieldNamesGO));
        // 3.1 gazeOrigin.inUserCoords
        mxSetFieldByNumber(temp, 0, 0, TobiiFieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_user_coordinates, 0.));        // 0. causes values to be stored as double
        // 3.2 gazeOrigin.inTrackBoxCoords
        mxSetFieldByNumber(temp, 0, 1, TobiiFieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_track_box_coordinates, 0.));   // 0. causes values to be stored as double
        // 3.3 gazeOrigin.validity
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 3.4 gazeOrigin.available
        mxSetFieldByNumber(temp, 0, 3, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::available));

        // 4. eyeOpenness
        mxSetFieldByNumber(out, 0, 3, temp = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNamesEO)), fieldNamesEO));
        // 4.1 eye_openness.diameter
        mxSetFieldByNumber(temp, 0, 0, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::diameter, 0.));                             // 0. causes values to be stored as double
        // 4.2 eye_openness.validity
        mxSetFieldByNumber(temp, 0, 1, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::validity, TOBII_RESEARCH_VALIDITY_VALID));
        // 4.3 eye_openness.available
        mxSetFieldByNumber(temp, 0, 2, FieldToMatlab(data_, rowVector_, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::available));

        return out;
    }

    mxArray* ToMatlab(std::vector<Titta::eyeImage> data_)
    {
        // check if all gif, then don't output unneeded fields
        bool allGif = allEquals(data_, &Titta::eyeImage::is_gif, true);

        // fieldnames for all structs
        mxArray* out;
        if (allGif)
        {
            const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","regionID","regionTop","regionLeft","type","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }
        else
        {
            const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","regionID","regionTop","regionLeft","bitsPerPixel","paddingPerPixel","width","height","type","cameraID","isGif","image"};
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }

        // all simple fields
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &Titta::eyeImage::device_time_stamp));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &Titta::eyeImage::system_time_stamp));
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &Titta::eyeImage::region_id, 0.));             // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &Titta::eyeImage::region_top, 0.));            // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, true, &Titta::eyeImage::region_left, 0.));           // 0. causes values to be stored as double
        if (!allGif)
        {
            mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, true, &Titta::eyeImage::bits_per_pixel, 0.));    // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 6, FieldToMatlab(data_, true, &Titta::eyeImage::padding_per_pixel, 0.)); // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 7, FieldToMatlab(data_, true, &Titta::eyeImage::width, 0.));             // 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 8, FieldToMatlab(data_, true, &Titta::eyeImage::height, 0.));            // 0. causes values to be stored as double
        }
        int off = 4 * (!allGif);
        mxSetFieldByNumber(out, 0, 5 + off, FieldToMatlab(data_, true, &Titta::eyeImage::type, [](auto in_) {return TobiiResearchEyeImageToString(in_);}));
        mxSetFieldByNumber(out, 0, 6 + off, FieldToMatlab(data_, true, &Titta::eyeImage::camera_id, 0.));       // 0. causes values to be stored as double
        mxSetFieldByNumber(out, 0, 7 + off, FieldToMatlab(data_, true, &Titta::eyeImage::is_gif));
        mxSetFieldByNumber(out, 0, 8 + off, eyeImagesToMatlab(data_));

        return out;
    }

    mxArray* ToMatlab(std::vector<Titta::extSignal> data_)
    {
        const char* fieldNames[] = {"deviceTimeStamp","systemTimeStamp","value","changeType"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. device timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TobiiResearchExternalSignalData::device_time_stamp));
        // 2. system timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TobiiResearchExternalSignalData::system_time_stamp));
        // 3. external signal values
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &TobiiResearchExternalSignalData::value));
        // 4. value change type
        mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, true, &TobiiResearchExternalSignalData::change_type, uint8_t{}));      // cast enum values to uint8

        return out;
    }

    mxArray* ToMatlab(std::vector<Titta::timeSync> data_)
    {
        const char* fieldNames[] = {"systemRequestTimeStamp","deviceTimeStamp","systemResponseTimeStamp"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. system request timestamps
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TobiiResearchTimeSynchronizationData::system_request_time_stamp));
        // 2. device timestamps
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TobiiResearchTimeSynchronizationData::device_time_stamp));
        // 3. system response timestamps
        mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, true, &TobiiResearchTimeSynchronizationData::system_response_time_stamp));

        return out;
    }

    mxArray* FieldToMatlab(const std::vector<TobiiResearchUserPositionGuide>& data_, bool rowVector_, TobiiResearchEyeUserPositionGuide TobiiResearchUserPositionGuide::* field_)
    {
        const char* fieldNames[] = {"userPosition","valid"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1 user_position
        mxSetFieldByNumber(out, 0, 0, TobiiFieldToMatlab(data_, rowVector_, field_, &TobiiResearchEyeUserPositionGuide::user_position, 0.));    // 0. causes values to be stored as double
        // 2 validity
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, rowVector_, field_, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID));

        return out;
    }

    mxArray* ToMatlab(std::vector<Titta::positioning> data_)
    {
        const char* fieldNames[] = {"left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. left  eye data
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TobiiResearchUserPositionGuide::left_eye));
        // 2. right eye data
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TobiiResearchUserPositionGuide::right_eye));

        return out;
    }

    mxArray* ToMatlab(Titta::logMessage data_)
    {
        const char* fieldNames[] = {"type","machineSerialNumber","systemTimeStamp","source","levelOrError","message"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. type
        mxSetFieldByNumber(out, 0, 0, ToMatlab(std::string("log message")));
        // 2. machine serial number (none)
        mxSetFieldByNumber(out, 0, 1, ToMatlab(std::string("")));
        // 3. system timestamps
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.system_time_stamp));
        // 4. log source
        mxSetFieldByNumber(out, 0, 3, ToMatlab(TobiiResearchLogSourceToString(data_.source)));
        // 5. log level
        mxSetFieldByNumber(out, 0, 4, ToMatlab(TobiiResearchLogLevelToString(data_.level)));
        // 6. log messages
        mxSetFieldByNumber(out, 0, 5, ToMatlab(data_.message));

        return out;
    }

    mxArray* ToMatlab(Titta::streamError data_)
    {
        const char* fieldNames[] = {"type","machineSerialNumber","systemTimeStamp","source","levelOrError","message"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. type
        mxSetFieldByNumber(out, 0, 0, ToMatlab(std::string("stream error")));
        // 2. machine serial number
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.machine_serial));
        // 3. system timestamps
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.system_time_stamp));
        // 4. stream error source
        mxSetFieldByNumber(out, 0, 3, ToMatlab(TobiiResearchStreamErrorSourceToString(data_.source)));
        // 5. stream error
        mxSetFieldByNumber(out, 0, 4, ToMatlab(TobiiResearchStreamErrorToString(data_.error)));
        // 6. log messages
        mxSetFieldByNumber(out, 0, 5, ToMatlab(data_.message));

        return out;
    }
    mxArray* ToMatlab(Titta::notification data_, mwIndex idx_/*=0*/, mwSize size_/*=1*/, mxArray* storage_/*=nullptr*/)
    {
        if (idx_ == 0)
        {
            const char* fieldNames[] = { "systemTimeStamp","notification","explanation","value" };
            storage_ = mxCreateStructMatrix(size_, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            if (size_ == 0)
                return storage_;
        }

        auto hasOutputFrequency = data_.output_frequency.has_value();
        auto hasDisplayArea     = data_.display_area.has_value();
        auto hasErrorsOrWarnings= data_.errors_or_warnings.has_value();

        // there are four options: (1) neither of the three optionals are available, or
        // (2-4) one of the three optionals is available
        mxSetFieldByNumber(storage_, idx_, 0, ToMatlab(data_.system_time_stamp));
        mxSetFieldByNumber(storage_, idx_, 1, ToMatlab(TobiiResearchNotificationToString(data_.notification_type)));
        mxSetFieldByNumber(storage_, idx_, 2, ToMatlab(TobiiResearchNotificationToExplanation(data_.notification_type)));
        if (hasOutputFrequency)
            mxSetFieldByNumber(storage_, idx_, 3, ToMatlab(data_.output_frequency));
        else if (hasDisplayArea)
            mxSetFieldByNumber(storage_, idx_, 3, ToMatlab(data_.display_area));
        else if (hasErrorsOrWarnings)
            mxSetFieldByNumber(storage_, idx_, 3, ToMatlab(data_.errors_or_warnings));
        // else don't set value, which yields an empty double, fine

        return storage_;
    }

    mxArray* ToMatlab(TobiiTypes::CalibrationState data_)
    {
        std::string str;
        switch (data_)
        {
        case TobiiTypes::CalibrationState::NotYetEntered:
            str = "NotYetEntered";
            break;
        case TobiiTypes::CalibrationState::AwaitingCalPoint:
            str = "AwaitingCalPoint";
            break;
        case TobiiTypes::CalibrationState::CollectingData:
            str = "CollectingData";
            break;
        case TobiiTypes::CalibrationState::DiscardingData:
            str = "DiscardingData";
            break;
        case TobiiTypes::CalibrationState::Computing:
            str = "Computing";
            break;
        case TobiiTypes::CalibrationState::GettingCalibrationData:
            str = "GettingCalibrationData";
            break;
        case TobiiTypes::CalibrationState::ApplyingCalibrationData:
            str = "ApplyingCalibrationData";
            break;
        case TobiiTypes::CalibrationState::Left:
            str = "Left";
            break;
        default:
            str = "!!unknown";
            break;
        }
        return ToMatlab(str);
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkResult data_)
    {
        auto hasCalResult = data_.calibrationResult.has_value();
        auto hasCalData   = data_.calibrationData  .has_value();
        mxArray* out;

        // there are three options, neither of calResult and calData are available, or one of the two
        // both is not possible as they are used in completely different situations
        // there are three options: (1) none of the two above variables are set; (2) only calData is
        // set; (3) only calResult is set. Other combinations are not possible because of how work
        // results are used in the code, these result from separate thread actions.
        if (hasCalResult)
        {
            const char* fieldNames[] = { "workItem","status","statusString","calibrationResult" };
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }
        else if (hasCalData)
        {
            const char* fieldNames[] = { "workItem","status","statusString","calibrationData" };
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }
        else
        {
            const char* fieldNames[] = { "workItem","status","statusString" };
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }

        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.workItem));
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.status));
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.statusString));
        if (hasCalResult)
            mxSetFieldByNumber(out, 0, 3, ToMatlab(data_.calibrationResult));
        if (hasCalData)
            mxSetFieldByNumber(out, 0, 3, ToMatlab(data_.calibrationData));

        return out;
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkItem data_)
    {
        auto hasCoords  = data_.coordinates    .has_value();
        auto hasEye     = data_.eye            .has_value();
        auto hasCalData = data_.calibrationData.has_value();
        mxArray* out;

        // there are four options: (1) none of the three above variables are set; (2) calData is set
        // (3) coordinates is set without eye; (4) coordinates is set with eye. Other combinations
        // are not possible because of how work items are used in the code, these are separate thread
        // actions.
        if (hasCoords)
        {
            if (hasEye)
            {
                const char* fieldNames[] = { "action","coordinates","eye" };
                out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            }
            else
            {
                const char* fieldNames[] = { "action","coordinates" };
                out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            }
        }
        else if (hasCalData)
        {
            const char* fieldNames[] = { "action","calibrationData" };
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }
        else
        {
            const char* fieldNames[] = { "action" };
            out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
        }

        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.action));
        if (hasCoords)
            mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.coordinates));
        if (hasEye)
            mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.eye));
        if (hasCalData)
            mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.calibrationData));

        return out;
    }
    mxArray* ToMatlab(TobiiResearchStatus data_)
    {
        return ToMatlab(static_cast<int>(data_));
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationAction data_)
    {
        std::string str;
        switch (data_)
        {
        case TobiiTypes::CalibrationAction::Nothing:
            str = "Nothing";
            break;
        case TobiiTypes::CalibrationAction::Enter:
            str = "Enter";
            break;
        case TobiiTypes::CalibrationAction::CollectData:
            str = "CollectData";
            break;
        case TobiiTypes::CalibrationAction::DiscardData:
            str = "DiscardData";
            break;
        case TobiiTypes::CalibrationAction::Compute:
            str = "Compute";
            break;
        case TobiiTypes::CalibrationAction::GetCalibrationData:
            str = "GetCalibrationData";
            break;
        case TobiiTypes::CalibrationAction::ApplyCalibrationData:
            str = "ApplyCalibrationData";
            break;
        case TobiiTypes::CalibrationAction::Exit:
            str = "Exit";
            break;
        default:
            str = "!!unknown";
            break;
        }
        return ToMatlab(str);
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationResult data_)
    {
        const char* fieldNames[] = {"status","points"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. status
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.status));
        // 2. data per calibration point
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.calibration_points));

        return out;
    }
    mxArray* ToMatlab(TobiiResearchCalibrationStatus data_)
    {
        std::string str;
        switch (data_)
        {
        case TOBII_RESEARCH_CALIBRATION_FAILURE:
            str = "failure";
            break;
        case TOBII_RESEARCH_CALIBRATION_SUCCESS:
            str = "success";
            break;
        case TOBII_RESEARCH_CALIBRATION_SUCCESS_LEFT_EYE:
            str = "successLeftEye";
            break;
        case TOBII_RESEARCH_CALIBRATION_SUCCESS_RIGHT_EYE:
            str = "successRightEye";
            break;
        }
        return ToMatlab(str);
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationPoint data_, mwIndex idx_/*=0*/, mwSize size_/*=1*/, mxArray* storage_/*=nullptr*/)
    {
        if (idx_ == 0)
        {
            const char* fieldNames[] = { "position","samples" };
            storage_ = mxCreateStructMatrix(size_, 1, static_cast<int>(std::size(fieldNames)), fieldNames);
            if (size_ == 0)
                return storage_;
        }

        mxSetFieldByNumber(storage_, idx_, 0, ToMatlab(data_.position_on_display_area));
        mxSetFieldByNumber(storage_, idx_, 1, ToMatlab(data_.calibration_samples));

        return storage_;
    }
    mxArray* ToMatlab(TobiiResearchNormalizedPoint2D data_)
    {
        return ToMatlab(std::array<double,2>{static_cast<double>(data_.x),static_cast<double>(data_.y)});
    }
    mxArray* ToMatlab(std::vector<TobiiResearchCalibrationSample> data_)
    {
        const char* fieldNames[] = {"left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1. left  eye data
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, true, &TobiiResearchCalibrationSample::left_eye));
        // 2. right eye data
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, true, &TobiiResearchCalibrationSample::right_eye));

        return out;
    }
    mxArray* FieldToMatlab(std::vector<TobiiResearchCalibrationSample> data_, bool rowVector_, TobiiResearchCalibrationEyeData TobiiResearchCalibrationSample::* field_)
    {
        const char* fieldNames[] = {"position","validity"};
        mxArray* out = mxCreateStructMatrix(1, 1, static_cast<int>(std::size(fieldNames)), fieldNames);

        // 1 position on display area
        mxSetFieldByNumber(out, 0, 0, TobiiFieldToMatlab(data_, rowVector_, field_, &TobiiResearchCalibrationEyeData::position_on_display_area, 0.));     // 0. causes values to be stored as double
        // 2 validity
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, rowVector_, field_, &TobiiResearchCalibrationEyeData::validity, [](auto in_) {return TobiiResearchCalibrationEyeValidityToString(in_); }));

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
