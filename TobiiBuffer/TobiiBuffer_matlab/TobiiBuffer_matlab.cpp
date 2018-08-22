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
        PeekEyeImages
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
    mxArray* EyeImageVectorToMatlab(std::vector<TobiiBuff::eyeImage  > data_);
    mxArray*   SampleVectorToMatlab(std::vector<TobiiResearchGazeData> data_);
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
    if (action != Action::New && action != Action::Delete) {
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

        std::pair<instanceMap_type::iterator, bool> insResult;
        if (nrhs > 1) {
            char* address = mxArrayToString(prhs[1]);
            insResult = instanceTab.insert(indPtrPair_type(++handleVal, std::make_shared<class_type>(address)));
            mxFree(address);
        }

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

    default:
        mexErrMsgTxt(("Unhandled action: " + actionStr).c_str());
        break;
    }
}


// helpers
namespace
{
    template <typename T>
    constexpr mxClassID typeToMxClass(T)
    {
        if constexpr (std::is_same<T, double>::value)
            return mxDOUBLE_CLASS;
        else if constexpr (std::is_same<T, float>::value)
            return mxSINGLE_CLASS;
        else if constexpr (std::is_same<T, bool>::value)
            return mxLOGICAL_CLASS;
        else if constexpr (std::is_same<T, uint64_t>::value)
            return mxUINT64_CLASS;
        else if constexpr (std::is_same<T, int64_t>::value)
            return mxINT64_CLASS;
        else if constexpr (std::is_same<T, uint32_t>::value)
            return mxUINT32_CLASS;
        else if constexpr (std::is_same<T, int32_t>::value)
            return mxINT32_CLASS;
        else if constexpr (std::is_same<T, uint16_t>::value)
            return mxUINT16_CLASS;
        else if constexpr (std::is_same<T, int16_t>::value)
            return mxINT16_CLASS;
        else if constexpr (std::is_same<T, uint8_t>::value)
            return mxUINT8_CLASS;
        else if constexpr (std::is_same<T, int8_t>::value)
            return mxINT8_CLASS;
    }

    template <typename T>
    void VectorStructToArray(const T& samp_, double* storage_, size_t* i_)
    {
        storage_[(*i_)++] = samp_.x;
        storage_[(*i_)++] = samp_.y;
        if constexpr(std::disjunction<std::is_same<T, TobiiResearchPoint3D>, std::is_same<T, TobiiResearchNormalizedPoint3D>>::value)
            storage_[(*i_)++] = samp_.z;
    }


    mxArray* FieldToMatlab(const std::vector<TobiiResearchGazeData>& data_, TobiiResearchEyeData TobiiResearchGazeData::* field_)
    {
        const char* fieldNamesEye[] = {"gazePoint","pupil","gazeOrigin"};
        const char* fieldNamesGP[] = {"onDisplayArea","inUserCoords","validity"};
        const char* fieldNamesPup[] = {"diameter","validity"};
        const char* fieldNamesGO[] = {"inUserCoords","inTrackBoxCoords","validity"};
        mxArray* out = mxCreateStructMatrix(1, 1, sizeof(fieldNamesEye) / sizeof(*fieldNamesEye), fieldNamesEye);
        mxArray* temp;
        mxArray* temp2;

        // 1. gazePoint
        mxSetFieldByNumber(out, 0, 0, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesGP) / sizeof(*fieldNamesGP), fieldNamesGP));
        // 1.1 gazePoint.onDisplayArea
        mxSetFieldByNumber(temp, 0, 0, temp2 = mxCreateUninitNumericMatrix(2, data_.size(), mxDOUBLE_CLASS, mxREAL));
        auto storage = static_cast<double*>(mxGetData(temp2));
        size_t i = 0;
        for (auto &samp : data_)
            VectorStructToArray((samp.*field_).gaze_point.position_on_display_area, storage, &i);
        // 1.2 gazePoint.inUserCoords
        mxSetFieldByNumber(temp, 0, 1, temp2 = mxCreateUninitNumericMatrix(3, data_.size(), mxDOUBLE_CLASS, mxREAL));
        storage = static_cast<double*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            VectorStructToArray((samp.*field_).gaze_point.position_in_user_coordinates, storage, &i);
        // 1.3 gazePoint.validity
        mxSetFieldByNumber(temp, 0, 2, temp2 = mxCreateUninitNumericMatrix(1, data_.size(), mxLOGICAL_CLASS, mxREAL));
        auto storageb = static_cast<bool*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            storageb[i++] = (samp.*field_).gaze_point.validity == TOBII_RESEARCH_VALIDITY_VALID;

        // 2. pupil
        mxSetFieldByNumber(out, 0, 1, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesPup) / sizeof(*fieldNamesPup), fieldNamesPup));
        // 2.1 pupil.diameter
        mxSetFieldByNumber(temp, 0, 0, temp2 = mxCreateUninitNumericMatrix(1, data_.size(), mxDOUBLE_CLASS, mxREAL));
        storage = static_cast<double*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            storage[i++] = (samp.*field_).pupil_data.diameter;
        // 2.2 pupil.validity
        mxSetFieldByNumber(temp, 0, 1, temp2 = mxCreateUninitNumericMatrix(1, data_.size(), mxLOGICAL_CLASS, mxREAL));
        storageb = static_cast<bool*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            storageb[i++] = (samp.*field_).pupil_data.validity == TOBII_RESEARCH_VALIDITY_VALID;

        // 3. gazePoint
        mxSetFieldByNumber(out, 0, 2, temp = mxCreateStructMatrix(1, 1, sizeof(fieldNamesGO) / sizeof(*fieldNamesGO), fieldNamesGO));
        // 3.1 gazeOrigin.inUserCoords
        mxSetFieldByNumber(temp, 0, 0, temp2 = mxCreateUninitNumericMatrix(3, data_.size(), mxDOUBLE_CLASS, mxREAL));
        storage = static_cast<double*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            VectorStructToArray((samp.*field_).gaze_origin.position_in_user_coordinates, storage, &i);
        // 3.2 gazeOrigin.inTrackBoxCoords
        mxSetFieldByNumber(temp, 0, 1, temp2 = mxCreateUninitNumericMatrix(3, data_.size(), mxDOUBLE_CLASS, mxREAL));
        storage = static_cast<double*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            VectorStructToArray((samp.*field_).gaze_origin.position_in_track_box_coordinates, storage, &i);
        // 3.3 gazeOrigin.validity
        mxSetFieldByNumber(temp, 0, 2, temp2 = mxCreateUninitNumericMatrix(1, data_.size(), mxLOGICAL_CLASS, mxREAL));
        storageb = static_cast<bool*>(mxGetData(temp2));
        i = 0;
        for (auto &samp : data_)
            storageb[i++] = (samp.*field_).gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID;

        return out;
    }

    template <typename S, typename T, typename U = T>	// default output storage type U to type matching input type T, can override through type tag dispatch
    mxArray* FieldToMatlab(const std::vector<S>& data_, T S::* field_, U = {})
    {
        mxArray* temp;
        auto storage = static_cast<U*>(mxGetData(temp = mxCreateUninitNumericMatrix(data_.size(), 1, typeToMxClass(U{}), mxREAL)));
        size_t i = 0;
        for (auto &samp : data_)
            storage[i++] = samp.*field_;
        return temp;
    }

    mxArray* SampleVectorToMatlab(std::vector<TobiiResearchGazeData> data_)
    {
        if (data_.empty())
            return mxCreateDoubleMatrix(0, 0, mxREAL);

        // fieldnames for all structs
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

    mxArray* eyeImagesToMatlab(const std::vector<TobiiBuff::eyeImage>& data_)
    {
        // 1. see if all same size, then we can put them in one big matrix
        auto sz = data_[0].data_size;
        bool same = true;
        for (auto &frame : data_)
            if (frame.data_size != sz)
            {
                same = false;
                break;
            }
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
                auto storage = static_cast<uint8_t*>(mxGetData(temp = mxCreateUninitNumericMatrix(frame.width*frame.height, 1, mxUINT8_CLASS, mxREAL)));
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
        bool allGif = true;
        for (auto &frame : data_)
            if (!frame.isGif)
            {
                allGif = false;
                break;
            }

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

        mxArray* temp;
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
        mxSetFieldByNumber(out, 0, 2 + off, temp = mxCreateUninitNumericMatrix(data_.size(), 1, mxLOGICAL_CLASS, mxREAL));
        auto storage = static_cast<bool*>(mxGetData(temp));
        size_t i = 0;
        for (auto &frame : data_)
            storage[i++] = frame.type == TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED;
        mxSetFieldByNumber(out, 0, 3 + off, FieldToMatlab(data_, &TobiiBuff::eyeImage::camera_id));
        mxSetFieldByNumber(out, 0, 4 + off, FieldToMatlab(data_, &TobiiBuff::eyeImage::isGif));
        mxSetFieldByNumber(out, 0, 5 + off, eyeImagesToMatlab(data_));

        return out;
    }
}