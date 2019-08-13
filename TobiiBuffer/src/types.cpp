#include "TobiiBuffer/types.h"

#include "TobiiBuffer/utils.h"

namespace TobiiTypes
{
    eyeTracker::eyeTracker(TobiiResearchEyeTracker* et_) :
        _eyetracker(et_)
    {
        if (_eyetracker)
        {
            // get all info about the eye tracker
            TobiiResearchStatus status;
            // first bunch of strings
            char* device_name, * serial_number, * model, * firmware_version, * runtime_version, * address;
            status = tobii_research_get_device_name(_eyetracker, &device_name);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker device name", status);
            status = tobii_research_get_serial_number(_eyetracker, &serial_number);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker serial number", status);
            status = tobii_research_get_model(_eyetracker, &model);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker model", status);
            status = tobii_research_get_firmware_version(_eyetracker, &firmware_version);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker firmware version", status);
            status = tobii_research_get_runtime_version(_eyetracker, &runtime_version);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker runtime version", status);
            status = tobii_research_get_address(_eyetracker, &address);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker address", status);
            _deviceName = device_name;
            _serialNumber = serial_number;
            _model = model;
            _firmwareVersion = firmware_version;
            _runtimeVersion = runtime_version;
            _address = address;
            tobii_research_free_string(device_name);
            tobii_research_free_string(serial_number);
            tobii_research_free_string(model);
            tobii_research_free_string(firmware_version);
            tobii_research_free_string(runtime_version);
            tobii_research_free_string(address);

            // its capabilities
            status = tobii_research_get_capabilities(_eyetracker, &_capabilities);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker capabilities", status);

            // get supported sampling frequencies
            TobiiResearchGazeOutputFrequencies* tobiiFreqs = nullptr;
            status = tobii_research_get_all_gaze_output_frequencies(_eyetracker, &tobiiFreqs);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker output frequencies", status);
            _frequencies.insert(_frequencies.end(), &tobiiFreqs->frequencies[0], &tobiiFreqs->frequencies[tobiiFreqs->frequency_count]);   // yes, pointer to one past last element
            tobii_research_free_gaze_output_frequencies(tobiiFreqs);

            // get supported eye tracking modes
            TobiiResearchEyeTrackingModes* tobiiModes = nullptr;
            status = tobii_research_get_all_eye_tracking_modes(_eyetracker, &tobiiModes);
            if (status != TOBII_RESEARCH_STATUS_OK)
                ErrorExit("Cannot get eye tracker's tracking modes", status);
            _modes.insert(_modes.end(), &tobiiModes->modes[0], &tobiiModes->modes[tobiiModes->mode_count]);   // yes, pointer to one past last element
            tobii_research_free_eye_tracking_modes(tobiiModes);
        }
    };
}