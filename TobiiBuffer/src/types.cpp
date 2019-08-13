#include "TobiiBuffer/types.h"

#include "TobiiBuffer/utils.h"

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

    void eyeTracker::refreshInfo()
    {
        // get all info about the eye tracker
        TobiiResearchStatus status;
        // first bunch of strings
        char* device_name, *serial_number, *modelT, *firmware_version, *runtime_version, *addressT;
        status = tobii_research_get_device_name(et, &device_name);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker device name", status);
        status = tobii_research_get_serial_number(et, &serial_number);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker serial number", status);
        status = tobii_research_get_model(et, &modelT);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker model", status);
        status = tobii_research_get_firmware_version(et, &firmware_version);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker firmware version", status);
        status = tobii_research_get_runtime_version(et, &runtime_version);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker runtime version", status);
        status = tobii_research_get_address(et, &addressT);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker address", status);
        deviceName = device_name;
        serialNumber = serial_number;
        model = modelT;
        firmwareVersion = firmware_version;
        runtimeVersion = runtime_version;
        address = addressT;
        tobii_research_free_string(device_name);
        tobii_research_free_string(serial_number);
        tobii_research_free_string(modelT);
        tobii_research_free_string(firmware_version);
        tobii_research_free_string(runtime_version);
        tobii_research_free_string(addressT);

        // its capabilities
        status = tobii_research_get_capabilities(et, &capabilities);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker capabilities", status);

        // get supported sampling frequencies
        TobiiResearchGazeOutputFrequencies* tobiiFreqs = nullptr;
        supportedFrequencies.clear();
        status = tobii_research_get_all_gaze_output_frequencies(et, &tobiiFreqs);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker output frequencies", status);
        supportedFrequencies.insert(supportedFrequencies.end(), &tobiiFreqs->frequencies[0], &tobiiFreqs->frequencies[tobiiFreqs->frequency_count]);   // yes, pointer to one past last element
        tobii_research_free_gaze_output_frequencies(tobiiFreqs);

        // get supported eye tracking modes
        TobiiResearchEyeTrackingModes* tobiiModes = nullptr;
        supportedModes.clear();
        status = tobii_research_get_all_eye_tracking_modes(et, &tobiiModes);
        if (status != TOBII_RESEARCH_STATUS_OK)
            ErrorExit("Cannot get eye tracker's tracking modes", status);
        supportedModes.insert(supportedModes.end(), &tobiiModes->modes[0], &tobiiModes->modes[tobiiModes->mode_count]);   // yes, pointer to one past last element
        tobii_research_free_eye_tracking_modes(tobiiModes);
    }
}