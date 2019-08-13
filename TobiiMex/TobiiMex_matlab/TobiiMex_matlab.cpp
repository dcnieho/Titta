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

#define TARGET_API_VERSION 700
#define MX_COMPAT_32
#define MW_NEEDS_VERSION_H	// looks like a bug in R2018b, don't know how to check if this is R2018b, define for now
//#define DLL_EXPORT_SYM __declspec(dllexport) // this is what is needed for earlier matlab versions instead
#include <mex.h>
#include "mex_type_utils.h"

#include "pack_utils.h"
#include "tobii_to_matlab.h"

#include "TobiiMex/TobiiMex.h"
#include "TobiiMex/utils.h"

namespace {
    using ClassType         = TobiiMex;
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
        // logging
        StartLogging,
        GetLog,
        StopLogging,

        //// eye-tracker specific getters and setters
        // getters
        GetConnectedEyeTracker,
        GetCurrentFrequency,
        GetCurrentTrackingMode,
        GetTrackBox,
        GetDisplayArea,
        // setters
        SetGazeFrequency,
        SetTrackingMode,
        ApplyLicenses,
        ClearLicenses,

        //// calibration
        EnterCalibrationMode,
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
        Start,
        IsBuffering,
        Clear,
        ClearTimeRange,
        Stop,
        ConsumeN,
        ConsumeTimeRange,
        PeekN,
        PeekTimeRange
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        // MATLAB interface
        { "touch",				Action::Touch },
        { "new",				Action::New },
        { "delete",				Action::Delete },

        //// global SDK functions
        { "getSDKVersion",		Action::GetSDKVersion },
        { "getSystemTimestamp",	Action::GetSystemTimestamp },
        { "findAllEyeTrackers",	Action::FindAllEyeTrackers },
        // logging
        { "startLogging",		Action::StartLogging },
        { "getLog",				Action::GetLog },
        { "stopLogging",		Action::StopLogging },

        //// eye-tracker specific getters and setters
        // getters
        { "getConnectedEyeTracker",			Action::GetConnectedEyeTracker },
        { "getCurrentFrequency",			Action::GetCurrentFrequency },
        { "getCurrentTrackingMode",			Action::GetCurrentTrackingMode },
        { "getTrackBox",			        Action::GetTrackBox },
        { "getDisplayArea",			        Action::GetDisplayArea },
        // setters
        { "setGazeFrequency",			    Action::SetGazeFrequency },
        { "setTrackingMode",			    Action::SetTrackingMode },
        { "applyLicenses",		    	    Action::ApplyLicenses },
        { "clearLicenses",		    	    Action::ClearLicenses },

        //// calibration
        { "enterCalibrationMode",			Action::EnterCalibrationMode },
        { "leaveCalibrationMode",			Action::LeaveCalibrationMode },
        { "calibrationCollectData",		    Action::CalibrationCollectData },
        { "calibrationDiscardData",			Action::CalibrationDiscardData },
        { "calibrationComputeAndApply",		Action::CalibrationComputeAndApply },
        { "calibrationGetData",		        Action::CalibrationGetData },
        { "calibrationApplyData",		    Action::CalibrationApplyData },
        { "calibrationGetStatus",			Action::CalibrationGetStatus },
        { "calibrationRetrieveResult",      Action::CalibrationRetrieveResult },

        //// data streams
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

    mxArray* ToMatlab(TobiiResearchSDKVersion                           data_);
    mxArray* ToMatlab(std::vector<TobiiTypes::eyeTracker>               data_);
    mxArray* ToMatlab(TobiiResearchCapabilities                         data_);

    mxArray* ToMatlab(TobiiResearchTrackBox                             data_);
    mxArray* ToMatlab(TobiiResearchDisplayArea                          data_);
    mxArray* ToMatlab(TobiiResearchPoint3D                              data_);
    mxArray* ToMatlab(TobiiResearchLicenseValidationResult              data_);

    mxArray* FieldToMatlab(const std::vector<TobiiResearchGazeData>&    data_, TobiiResearchEyeData TobiiResearchGazeData::* field_);
    mxArray* ToMatlab(std::vector<TobiiMex::gaze                   > data_);
    mxArray* ToMatlab(std::vector<TobiiMex::eyeImage               > data_);
    mxArray* ToMatlab(std::vector<TobiiMex::extSignal              > data_);
    mxArray* ToMatlab(std::vector<TobiiMex::timeSync               > data_);
    mxArray* ToMatlab(std::vector<TobiiMex::positioning            > data_);
    mxArray* ToMatlab(TobiiMex::logMessage                           data_);
    mxArray* ToMatlab(TobiiMex::streamError                          data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationState                      data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkResult                 data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkItem                   data_);
    mxArray* ToMatlab(TobiiResearchStatus                               data_);
    mxArray* ToMatlab(TobiiTypes::CalibrationAction                     data_);
    mxArray* ToMatlab(TobiiResearchCalibrationResult                    data_);
    mxArray* ToMatlab(TobiiResearchCalibrationStatus                    data_);
    mxArray* ToMatlab(std::vector<TobiiResearchCalibrationPoint>        data_);
    mxArray* ToMatlab(TobiiResearchNormalizedPoint2D                    data_);
    mxArray* ToMatlab(std::vector<TobiiResearchCalibrationSample>		data_);
    mxArray* FieldToMatlab(std::vector<TobiiResearchCalibrationSample>  data_, TobiiResearchCalibrationEyeData TobiiResearchCalibrationSample::* field_);
    mxArray* ToMatlab(TobiiResearchCalibrationEyeValidity               data_);
    mxArray* ToMatlab(TobiiResearchCalibrationData                      data_);
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
    if (action != Action::Touch && action != Action::New &&
        action != Action::GetSDKVersion && action != Action::GetSystemTimestamp && action != Action::FindAllEyeTrackers &&
        action != Action::StartLogging && action != Action::GetLog && action != Action::StopLogging)
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
                mexErrMsgTxt("TobiiMex: Second argument must be a string.");

            char* address = mxArrayToString(prhs[1]);
            auto insResult = instanceTab.insert({++handleVal, std::make_shared<ClassType>(address)});
            mxFree(address);

            if (!insResult.second) // sanity check
                mexErrMsgTxt("Oh, bad news. Tried to add an existing handle."); // shouldn't ever happen
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

        case Action::GetSDKVersion:
        {
            plhs[0] = mxTypes::ToMatlab(TobiiMex::getSDKVersion());
            break;
        }
        case Action::GetSystemTimestamp:
        {
            plhs[0] = mxTypes::ToMatlab(TobiiMex::getSystemTimestamp());
            break;
        }
        case Action::FindAllEyeTrackers:
        {
            plhs[0] = mxTypes::ToMatlab(TobiiMex::findAllEyeTrackers());
            break;
        }

        case Action::GetConnectedEyeTracker:
        {
            // vector so we don't have write another ToMatlab
            std::vector<TobiiTypes::eyeTracker> temp;
            temp.push_back(instance->getConnectedEyeTracker());
            plhs[0] = mxTypes::ToMatlab(temp);
            break;
        }
        case Action::GetCurrentFrequency:
        {
            plhs[0] = mxTypes::ToMatlab(instance->getCurrentFrequency());
            break;
        }
        case Action::GetCurrentTrackingMode:
        {
            plhs[0] = mxTypes::ToMatlab(instance->getCurrentTrackingMode());
            break;
        }
        case Action::GetTrackBox:
        {
            plhs[0] = mxTypes::ToMatlab(instance->getTrackBox());
            break;
        }
        case Action::GetDisplayArea:
        {
            plhs[0] = mxTypes::ToMatlab(instance->getDisplayArea());
            break;
        }
        case Action::SetGazeFrequency:
        {
            float freq = 0.f;
            if (nrhs < 3 || mxIsEmpty(prhs[2]) || !mxIsSingle(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]))
                mexErrMsgTxt("setGazeFrequency: Expected second argument to be a float scalar.");
            freq = *static_cast<float*>(mxGetData(prhs[2]));

            instance->setGazeFrequency(freq);
            break;
        }
        case Action::SetTrackingMode:
        {
            if (nrhs < 3 || mxIsEmpty(prhs[2]) || !mxIsChar(prhs[2]))
                mexErrMsgTxt("setTrackingMode: Expected second argument to be a string.");

            char* bufferCstr = mxArrayToString(prhs[2]);
            instance->setTrackingMode(bufferCstr);
            mxFree(bufferCstr);
            break;
        }
        case Action::ApplyLicenses:
        {
            if (nrhs < 3 || mxIsEmpty(prhs[2]) || !mxIsCell(prhs[2]))
                mexErrMsgTxt("applyLicenses: Expected second argument to be a cell.");

            std::vector<std::vector<uint8_t>> licenses;

            // get how many elements the cell has, iterate over them (don't care about shape)
            const mwSize nElem = mxGetNumberOfElements(prhs[2]);
            for (mwIndex i = 0; i < nElem; i++)
            {
                mxArray* cellElement = mxGetCell(prhs[2], i);
                if (!cellElement)
                    mexErrMsgTxt("applyLicenses: All cell elements should be non-empty.");
                // we've got some kind of cell content, lets check it, and then access it
                if (mxIsEmpty(cellElement) || !mxIsUint8(cellElement) || mxIsComplex(cellElement))
                    mexErrMsgTxt("applyLicenses: All cells should contain arrays of uint8.");
                // now get content, copy over
                uint8_t* in = static_cast<uint8_t*>(mxGetData(cellElement));
                licenses.emplace_back(in, in + mxGetNumberOfElements(cellElement));
            }

            plhs[0] = mxTypes::ToMatlab(instance->applyLicenses(licenses));
            break;
        }
        case Action::ClearLicenses:
        {
            instance->clearLicenses();
            break;
        }

        case Action::EnterCalibrationMode:
        {
            if (nrhs < 3 || mxIsEmpty(prhs[2]) || !mxIsScalar(prhs[2]) || !mxIsLogicalScalar(prhs[2]))
                mexErrMsgTxt("enterCalibrationMode: First argument must be a logical scalar.");;

            bool doMonocular = mxIsLogicalScalarTrue(prhs[2]);
            instance->enterCalibrationMode(doMonocular);
            break;
        }
        case Action::LeaveCalibrationMode:
        {
            if (nrhs < 3 || mxIsEmpty(prhs[2]) || !mxIsScalar(prhs[2]) || !mxIsLogicalScalar(prhs[2]))
                mexErrMsgTxt("leaveCalibrationMode: First argument must be a logical scalar.");;

            bool force = mxIsLogicalScalarTrue(prhs[2]);
            instance->leaveCalibrationMode(force);
            break;
        }
        case Action::CalibrationCollectData:
        {
            if (nrhs < 3 || !mxIsDouble(prhs[2]) || mxIsComplex(prhs[2]) || mxGetNumberOfElements(prhs[2])!=2)
                mexErrMsgTxt("calibrationCollectData: First argument must be a 2-element double array.");
            double* dat = static_cast<double*>(mxGetData(prhs[2]));
            std::array<double, 2> point{ *dat, *(dat + 1) };

            // get optional input argument
            std::optional<std::string> eye;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsChar(prhs[3]))
                    mexErrMsgTxt("calibrationCollectData: Expected second argument to be a char array.");
                char *ceye = mxArrayToString(prhs[3]);
                eye = ceye;
                mxFree(ceye);
            }

            instance->calibrationCollectData(point,eye);
            break;
        }
        case Action::CalibrationDiscardData:
        {
            if (nrhs < 3 || !mxIsDouble(prhs[2]) || mxIsComplex(prhs[2]) || mxGetNumberOfElements(prhs[2]) != 2)
                mexErrMsgTxt("calibrationDiscardData: First argument must be a 2-element double array.");
            double* dat = static_cast<double*>(mxGetData(prhs[2]));
            std::array<double, 2> point{*dat, *(dat + 1)};

            // get optional input argument
            std::optional<std::string> eye;
            if (nrhs > 3 && !mxIsEmpty(prhs[3]))
            {
                if (!mxIsChar(prhs[3]))
                    mexErrMsgTxt("calibrationDiscardData: Expected second argument to be a char array.");
                char *ceye = mxArrayToString(prhs[3]);
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
            if (nrhs < 3 || !mxIsUint8(prhs[2]) || mxIsComplex(prhs[2]) || mxIsEmpty(prhs[2]))
                mexErrMsgTxt("calibrationApplyData: First argument must be a n-element uint8 array, as returned from calibrationGetData.");
            uint8_t* in = static_cast<uint8_t*>(mxGetData(prhs[2]));
            std::vector<uint8_t> calData{in, in+ mxGetNumberOfElements(prhs[2])};

            instance->calibrationApplyData(calData);
            break;
        }
        case Action::CalibrationGetStatus:
        {
            plhs[0] = mxTypes::ToMatlab(instance->calibrationGetStatus());
            break;
        }
        case Action::CalibrationRetrieveResult:
        {
            plhs[0] = mxTypes::ToMatlab(instance->calibrationRetrieveResult(true));
            break;
        }

        case Action::HasStream:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("hasStream: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

            // get data stream identifier string, call hasStream() on instance
            char *bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->hasStream(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::Start:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("start: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

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
                mexErrMsgTxt("isBuffering: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

            // get data stream identifier string, call isBuffering() on instance
            char *bufferCstr = mxArrayToString(prhs[2]);
            plhs[0] = mxCreateLogicalScalar(instance->isBuffering(bufferCstr));
            mxFree(bufferCstr);
            return;
        }
        case Action::Clear:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("clear: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

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
                mexErrMsgTxt("stop: first input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

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
                mexErrMsgTxt("consumeN: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiMex::DataStream dataStream = instance->stringToDataStream(bufferCstr);
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
                case TobiiMex::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiMex::gaze>(nSamp));
                    return;
                case TobiiMex::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiMex::eyeImage>(nSamp));
                    return;
                case TobiiMex::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiMex::extSignal>(nSamp));
                    return;
                case TobiiMex::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiMex::timeSync>(nSamp));
                    return;
                case TobiiMex::DataStream::Positioning:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeN<TobiiMex::positioning>(nSamp));
                    return;
            }
        }
        case Action::ConsumeTimeRange:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("consumeTimeRange: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiMex::DataStream dataStream = instance->stringToDataStream(bufferCstr);
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
                case TobiiMex::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiMex::gaze>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiMex::eyeImage>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiMex::extSignal>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->consumeTimeRange<TobiiMex::timeSync>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::Positioning:
                    DoExitWithMsg("consumeTimeRange: not supported for positioning stream.");
                    return;
            }
        }
        case Action::PeekN:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("peekN: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', 'timeSync', or 'positioning').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiMex::DataStream dataStream = instance->stringToDataStream(bufferCstr);
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
                case TobiiMex::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiMex::gaze>(nSamp));
                    return;
                case TobiiMex::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiMex::eyeImage>(nSamp));
                    return;
                case TobiiMex::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiMex::extSignal>(nSamp));
                    return;
                case TobiiMex::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiMex::timeSync>(nSamp));
                    return;
                case TobiiMex::DataStream::Positioning:
                    plhs[0] = mxTypes::ToMatlab(instance->peekN<TobiiMex::positioning>(nSamp));
                    return;
            }
        }

        case Action::PeekTimeRange:
        {
            if (nrhs < 3 || !mxIsChar(prhs[2]))
                mexErrMsgTxt("peekTimeRange: First input must be a data stream identifier string ('gaze', 'eyeImage', 'externalSignal', or 'timeSync').");

            // get data stream identifier string
            char *bufferCstr = mxArrayToString(prhs[2]);
            TobiiMex::DataStream dataStream = instance->stringToDataStream(bufferCstr);
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
                case TobiiMex::DataStream::Gaze:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiMex::gaze>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::EyeImage:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiMex::eyeImage>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::ExtSignal:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiMex::extSignal>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::TimeSync:
                    plhs[0] = mxTypes::ToMatlab(instance->peekTimeRange<TobiiMex::timeSync>(timeStart, timeEnd));
                    return;
                case TobiiMex::DataStream::Positioning:
                    DoExitWithMsg("peekTimeRange: not supported for positioning stream.");
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

            plhs[0] = mxCreateLogicalScalar(TobiiMex::startLogging(bufSize));
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

            plhs[0] = mxTypes::ToMatlab(TobiiMex::getLog(clearBuffer));
            return;
        }
        case Action::StopLogging:
            plhs[0] = mxCreateLogicalScalar(TobiiMex::stopLogging());
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

    mxArray* eyeImagesToMatlab(const std::vector<TobiiMex::eyeImage>& data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].data_size;
        bool same = allEquals(data_, &TobiiMex::eyeImage::data_size, sz);
        // 2. then copy over the images to matlab
        mxArray* out;
        if (data_[0].bits_per_pixel + data_[0].padding_per_pixel != 8)
            mexErrMsgTxt("eyeImagesToMatlab: non-8bit images not yet implemented");
        if (same)
        {
            auto storage = static_cast<uint8_t*>(mxGetData(out = mxCreateUninitNumericMatrix(static_cast<size_t>(data_[0].width)*data_[0].height, data_.size(), mxUINT8_CLASS, mxREAL)));
            size_t i = 0;
            for (auto &frame : data_)
                memcpy(storage + (i++)*sz, frame.data(), frame.data_size);
        }
        else
        {
            out = mxCreateCellMatrix(1, static_cast<mwSize>(data_.size()));
            mwIndex i = 0;
            for (auto &frame : data_)
            {
                mxArray* temp;
                auto storage = static_cast<uint8_t*>(mxGetData(temp = mxCreateUninitNumericMatrix(1, static_cast<size_t>(frame.width)*frame.height, mxUINT8_CLASS, mxREAL)));
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

    mxArray* ToMatlab(TobiiResearchSDKVersion data_)
    {
        std::stringstream ss;
        ss << data_.major << "." << data_.minor << "." << data_.revision << "." << data_.build;
        return mxCreateString(ss.str().c_str());
    }
    mxArray* ToMatlab(std::vector<TobiiTypes::eyeTracker> data_)
    {
        const char* fieldNames[] = {"deviceName","serialNumber","model","firmwareVersion","runtimeVersion","address","capabilities","supportedFrequencies","supportedModes"};
        mxArray* out = mxCreateStructMatrix(static_cast<mwSize>(data_.size()), 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        for (size_t i = 0; i!=data_.size(); i++)
        {
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 0, mxCreateString(data_[i].deviceName.c_str()));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 1, mxCreateString(data_[i].serialNumber.c_str()));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 2, mxCreateString(data_[i].model.c_str()));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 3, mxCreateString(data_[i].firmwareVersion.c_str()));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 4, mxCreateString(data_[i].runtimeVersion.c_str()));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 5, mxCreateString(data_[i].address.c_str()));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 6, ToMatlab(data_[i].capabilities));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 7, ToMatlab(data_[i].supportedFrequencies));
            mxSetFieldByNumber(out, static_cast<mwIndex>(i), 8, ToMatlab(data_[i].supportedModes));
        }

        return out;
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

        return ToMatlab(out);
    }

    mxArray* ToMatlab(TobiiResearchTrackBox data_)
    {
        const char* fieldNames[] = {"back_lower_left","back_lower_right","back_upper_left","back_upper_right","front_lower_left","front_lower_right","front_upper_left","front_upper_right"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

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
        const char* fieldNames[] = {"height","width","bottom_left","bottom_right","top_left","top_right"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

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
        mxArray* out = mxCreateUninitDoubleMatrix(mxREAL, 3, 1);
        auto storage = static_cast<double*>(mxGetData(out));
        storage[0] = static_cast<double>(data_.x);
        storage[1] = static_cast<double>(data_.y);
        storage[2] = static_cast<double>(data_.z);
        return out;
    }
    mxArray* ToMatlab(TobiiResearchLicenseValidationResult data_)
    {
        return mxCreateString(TobiiResearchLicenseValidationResultToString(data_).c_str());
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

    mxArray* ToMatlab(std::vector<TobiiMex::gaze> data_)
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

    mxArray* ToMatlab(std::vector<TobiiMex::eyeImage> data_)
    {
        // check if all gif, then don't output unneeded fields
        bool allGif = allEquals(data_, &TobiiMex::eyeImage::isGif, true);

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
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiMex::eyeImage::device_time_stamp));
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiMex::eyeImage::system_time_stamp));
        if (!allGif)
        {
            mxSetFieldByNumber(out, 0, 2, FieldToMatlab(data_, &TobiiMex::eyeImage::bits_per_pixel));
            mxSetFieldByNumber(out, 0, 3, FieldToMatlab(data_, &TobiiMex::eyeImage::padding_per_pixel));
            mxSetFieldByNumber(out, 0, 4, FieldToMatlab(data_, &TobiiMex::eyeImage::width, 0.));		// 0. causes values to be stored as double
            mxSetFieldByNumber(out, 0, 5, FieldToMatlab(data_, &TobiiMex::eyeImage::height, 0.));		// 0. causes values to be stored as double
        }
        int off = 4 * (!allGif);
        mxSetFieldByNumber(out, 0, 2 + off, FieldToMatlab(data_, &TobiiMex::eyeImage::type, TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED));
        mxSetFieldByNumber(out, 0, 3 + off, FieldToMatlab(data_, &TobiiMex::eyeImage::camera_id));
        mxSetFieldByNumber(out, 0, 4 + off, FieldToMatlab(data_, &TobiiMex::eyeImage::isGif));
        mxSetFieldByNumber(out, 0, 5 + off, eyeImagesToMatlab(data_));

        return out;
    }

    mxArray* ToMatlab(std::vector<TobiiMex::extSignal> data_)
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

    mxArray* ToMatlab(std::vector<TobiiMex::timeSync> data_)
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

    mxArray* FieldToMatlab(const std::vector<TobiiResearchUserPositionGuide>& data_, TobiiResearchEyeUserPositionGuide TobiiResearchUserPositionGuide::* field_)
    {
        const char* fieldNames[] = {"user_position","valid"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1 user_position
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchEyeUserPositionGuide::user_position, 0.));				// 0. causes values to be stored as double
        // 2 validity
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, field_, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID));

        return out;
    }

    mxArray* ToMatlab(std::vector<TobiiMex::positioning> data_)
    {
        const char* fieldNames[] = {"left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. left  eye data
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchUserPositionGuide::left_eye));
        // 2. right eye data
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchUserPositionGuide::right_eye));

        return out;
    }

    mxArray* ToMatlab(TobiiMex::logMessage data_)
    {
        const char* fieldNames[] = {"type","machineSerialNumber","systemTimeStamp","source","levelOrError","message"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

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

    mxArray* ToMatlab(TobiiMex::streamError data_)
    {
        const char* fieldNames[] = {"type","machineSerialNumber","systemTimeStamp","source","levelOrError","message"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. type
        mxSetFieldByNumber(out, 0, 0, ToMatlab(std::string("stream error")));
        // 2. machine serial number
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.machineSerial));
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
        return mxCreateString(str.c_str());
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkResult data_)
    {
        const char* fieldNames[] = { "workItem","status","statusString","calibrationResult","calibrationData" };
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.workItem));
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.status));
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.statusString));
        mxSetFieldByNumber(out, 0, 3, ToMatlab(data_.calibrationResult));
        mxSetFieldByNumber(out, 0, 4, ToMatlab(data_.calibrationData));

        return out;
    }
    mxArray* ToMatlab(TobiiTypes::CalibrationWorkItem data_)
    {
        const char* fieldNames[] = { "action","coordinates","eye","calData" };
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.action));
        mxSetFieldByNumber(out, 0, 1, ToMatlab(data_.coordinates));
        mxSetFieldByNumber(out, 0, 2, ToMatlab(data_.eye));
        mxSetFieldByNumber(out, 0, 3, ToMatlab(data_.calData));

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
        return mxCreateString(str.c_str());
    }
    mxArray* ToMatlab(TobiiResearchCalibrationResult data_)
    {
        std::vector points(data_.calibration_points, data_.calibration_points+data_.calibration_point_count);
        const char* fieldNames[] = {"status","points"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. status
        mxSetFieldByNumber(out, 0, 0, ToMatlab(data_.status));
        // 2. data per calibration point
        mxSetFieldByNumber(out, 0, 1, ToMatlab(points));

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
        return mxCreateString(str.c_str());
    }
    mxArray* ToMatlab(std::vector<TobiiResearchCalibrationPoint> data_)
    {
        if (!data_.size())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        const char* fieldNames[] = {"position","samples"};
        mxArray* out = mxCreateStructMatrix(static_cast<mwSize>(data_.size()), 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        ToStructArray(out, data_,
                      &TobiiResearchCalibrationPoint::position_on_display_area,
                      std::make_tuple([](auto a, auto b) {return std::vector(a,a+b); }, &TobiiResearchCalibrationPoint::calibration_samples, &TobiiResearchCalibrationPoint::calibration_sample_count)
        );

        return out;
    }
    mxArray* ToMatlab(TobiiResearchNormalizedPoint2D data_)
    {
        return ToMatlab(std::array{static_cast<double>(data_.x),static_cast<double>(data_.y)});
    }
    mxArray* ToMatlab(std::vector<TobiiResearchCalibrationSample> data_)
    {
        const char* fieldNames[] = {"left","right"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1. left  eye data
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, &TobiiResearchCalibrationSample::left_eye));
        // 2. right eye data
        mxSetFieldByNumber(out, 0, 1, FieldToMatlab(data_, &TobiiResearchCalibrationSample::right_eye));

        return out;
    }
    mxArray* FieldToMatlab(std::vector<TobiiResearchCalibrationSample> data_, TobiiResearchCalibrationEyeData TobiiResearchCalibrationSample::* field_)
    {
        const char* fieldNames[] = {"position","validity"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNames) / sizeof(*fieldNames), fieldNames);

        // 1 position on display area
        mxSetFieldByNumber(out, 0, 0, FieldToMatlab(data_, field_, &TobiiResearchCalibrationEyeData::position_on_display_area, 0.));					// 0. causes values to be stored as double
        // 2 validity
        mxArray* temp;
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateCellMatrix(static_cast<mwSize>(data_.size()), 1));
        mwIndex i = 0;
        for (auto &msg : data_)
            mxSetCell(temp, i++, ToMatlab((msg.*field_).validity));

        return out;
    }
    mxArray* ToMatlab(TobiiResearchCalibrationEyeValidity data_)
    {
        std::string str;
        switch (data_)
        {
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_INVALID_AND_NOT_USED:
            str = "invalidAndNotUsed";
            break;
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_BUT_NOT_USED:
            str = "validButNotUsed";
            break;
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED:
            str = "validAndUsed";
            break;
        case TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_UNKNOWN:
            str = "unknown";
            break;
        }
        return mxCreateString(str.c_str());
    }

    mxArray* ToMatlab(TobiiResearchCalibrationData data_)
    {
        return ToMatlab(std::vector(static_cast<uint8_t*>(data_.data), static_cast<uint8_t*>(data_.data)+data_.size));
    }
}


// function for handling errors generated by lib
void DoExitWithMsg(std::string errMsg_)
{
    mexErrMsgTxt(errMsg_.c_str());
}
void RelayMsg(std::string errMsg_)
{
    mexPrintf("%s\n",errMsg_.c_str());
}