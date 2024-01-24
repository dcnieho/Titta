#include "Titta/types.h"

#include "Titta/utils.h"

namespace TobiiTypes
{
    eyeTracker::eyeTracker(TobiiResearchEyeTracker* et_) :
        et(et_)
    {
        if (et)
        {
            refreshInfo();
        }
    };

    eyeTracker::eyeTracker(std::string deviceName_, std::string serialNumber_, std::string model_, std::string firmwareVersion_, std::string runtimeVersion_, std::string address_,
        const float frequency_, std::string trackingMode_, const TobiiResearchCapabilities capabilities_, std::vector<float> supportedFrequencies_, std::vector<std::string> supportedModes_) :
        deviceName(std::move(deviceName_)),
        serialNumber(std::move(serialNumber_)),
        model(std::move(model_)),
        firmwareVersion(std::move(firmwareVersion_)),
        runtimeVersion(std::move(runtimeVersion_)),
        address(std::move(address_)),
        frequency(frequency_),
        trackingMode(std::move(trackingMode_)),
        capabilities(capabilities_),
        supportedFrequencies(std::move(supportedFrequencies_)),
        supportedModes(std::move(supportedModes_))
    {}

    void eyeTracker::refreshInfo(std::optional<std::string> paramToRefresh_ /*= std::nullopt*/)
    {
        const bool singleOpt = paramToRefresh_.has_value();
        // get all info about the eye tracker
        TobiiResearchStatus status;
        // first bunch of strings
        if (!singleOpt || paramToRefresh_ == "deviceName")
        {
            char* device_name;
            status = tobii_research_get_device_name(et, &device_name);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker device name", status);
            deviceName = device_name;
            tobii_research_free_string(device_name);
            if (singleOpt) return;
        }
        if (!singleOpt || paramToRefresh_ == "serialNumber")
        {
            char* serial_number;
            status = tobii_research_get_serial_number(et, &serial_number);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker serial number", status);
            serialNumber = serial_number;
            tobii_research_free_string(serial_number);
            if (singleOpt) return;
        }
        if (!singleOpt || paramToRefresh_ == "model")
        {
            char* modelT;
            status = tobii_research_get_model(et, &modelT);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker model", status);
            model = modelT;
            tobii_research_free_string(modelT);
            if (singleOpt) return;
        }
        if (!singleOpt || paramToRefresh_ == "firmwareVersion")
        {
            char* firmware_version;
            status = tobii_research_get_firmware_version(et, &firmware_version);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker firmware version", status);
            firmwareVersion = firmware_version;
            tobii_research_free_string(firmware_version);
            if (singleOpt) return;
        }
        if (!singleOpt || paramToRefresh_ == "runtimeVersion")
        {
            char* runtime_version;
            status = tobii_research_get_runtime_version(et, &runtime_version);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker runtime version", status);
            runtimeVersion = runtime_version;
            tobii_research_free_string(runtime_version);
            if (singleOpt) return;
        }
        if (!singleOpt || paramToRefresh_ == "address")
        {
            char* addressT;
            status = tobii_research_get_address(et, &addressT);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker address", status);
            address = addressT;
            tobii_research_free_string(addressT);
            if (singleOpt) return;
        }

        // rest of these should always be refreshed, just to be conservative
        // in case e.g. some tracking mode doesn't support some capabilities
        // or frequencies
        bool used = false;

        // frequency and tracking mode
        float gaze_frequency;
        status = tobii_research_get_gaze_output_frequency(et, &gaze_frequency);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker current frequency", status);
        frequency = gaze_frequency;
        used = used || (singleOpt && paramToRefresh_ == "frequency");

        char* tracking_mode;
        status = tobii_research_get_eye_tracking_mode(et, &tracking_mode);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker current tracking mode", status);
        trackingMode = tracking_mode;
        tobii_research_free_string(tracking_mode);
        used = used || (singleOpt && paramToRefresh_ == "trackingMode");

        // its capabilities
        status = tobii_research_get_capabilities(et, &capabilities);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker capabilities", status);
        used = used || (singleOpt && paramToRefresh_ == "capabilities");

        // get supported sampling frequencies
        TobiiResearchGazeOutputFrequencies* tobiiFreqs = nullptr;
        supportedFrequencies.clear();
        status = tobii_research_get_all_gaze_output_frequencies(et, &tobiiFreqs);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker output frequencies", status);
        supportedFrequencies.insert(supportedFrequencies.end(), &tobiiFreqs->frequencies[0], &tobiiFreqs->frequencies[tobiiFreqs->frequency_count]);   // yes, pointer to one past last element
        tobii_research_free_gaze_output_frequencies(tobiiFreqs);
        used = used || (singleOpt && paramToRefresh_ == "supportedFrequencies");

        // get supported eye tracking modes
        TobiiResearchEyeTrackingModes* tobiiModes = nullptr;
        supportedModes.clear();
        status = tobii_research_get_all_eye_tracking_modes(et, &tobiiModes);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Titta::cpp::eyeTracker::refreshInfo: Cannot get eye tracker's tracking modes", status);
        supportedModes.insert(supportedModes.end(), &tobiiModes->modes[0], &tobiiModes->modes[tobiiModes->mode_count]);   // yes, pointer to one past last element
        tobii_research_free_eye_tracking_modes(tobiiModes);
        used = used || (singleOpt && paramToRefresh_ == "supportedModes");

        if (singleOpt && !used)
            // a single option is specified but unknown, emit error
            DoExitWithMsg(string_format("Titta::cpp::eyeTracker::refreshInfo: Option %s unknown.", paramToRefresh_->c_str()));
    }
}