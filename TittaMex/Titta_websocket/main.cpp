#define _CRT_SECURE_NO_WARNINGS // for uWS.h
#include <iostream>
#include <fstream>
#include <locale>
#include <map>
#include <string>
#include <sstream>
#include <atomic>
#include <cmath>
#include <optional>
#include <filesystem>

#include <uWS/uWS.h>
#include <nlohmann/json.hpp>
using json = nlohmann::json;

#include "Titta/Titta.h"
#include "Titta/utils.h"
#include "function_traits.h"


void DoExitWithMsg(std::string errMsg_);

// locale for proper nan printing (always nan, not sometimes -nan(ind))
template<typename Iterator = std::ostreambuf_iterator<char>>
class NumPut : public std::num_put<char, Iterator>
{
private:
    using base_type = std::num_put<char, Iterator>;

public:
    using char_type = typename base_type::char_type;
    using iter_type = typename base_type::iter_type;

    NumPut(std::size_t refs = 0)
        : base_type(refs)
    {}

protected:
    virtual iter_type do_put(iter_type out, std::ios_base& str, char_type fill, double v) const override {
        if (std::isnan(v))
            out = std::copy(std::begin(NotANumber), std::end(NotANumber), out);
        else
            out = base_type::do_put(out, str, fill, v);
        return out;
    }
    virtual iter_type do_put(iter_type out, std::ios_base& str, char_type fill, long double v) const override {
        if (std::isnan(v))
            out = std::copy(std::begin(NotANumber), std::end(NotANumber), out);
        else
            out = base_type::do_put(out, str, fill, v);
        return out;
    }
private:
    std::string NotANumber = "nan";
};

//#define LOCAL_TEST

namespace {
    // List actions
    enum class Action
    {
        Connect,

        SetSampleStreamFreq,
        StartSampleStream,
        StopSampleStream,

        SetBaseSampleFreq,
        StartSampleBuffer,
        ClearSampleBuffer,
        PeekSamples,
        StopSampleBuffer,
        SaveData,

        StoreMessage
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "connect"             , Action::Connect},

        { "setSampleStreamFreq" , Action::SetSampleStreamFreq},
        { "startSampleStream"   , Action::StartSampleStream},
        { "stopSampleStream"    , Action::StopSampleStream},

        { "setBaseSampleFreq"   , Action::SetBaseSampleFreq},
        { "startSampleBuffer"   , Action::StartSampleBuffer},
        { "clearSampleBuffer"   , Action::ClearSampleBuffer},
        { "peekSamples"         , Action::PeekSamples},
        { "stopSampleBuffer"    , Action::StopSampleBuffer},
        { "saveData"            , Action::SaveData},

        { "storeMessage"        , Action::StoreMessage},
    };

    template <bool isServer>
    void sendJson(uWS::WebSocket<isServer> *ws_, json jsonMsg_)
    {
        auto msg = jsonMsg_.dump();
        ws_->send(msg.c_str(), msg.length(), uWS::OpCode::TEXT);
    }

    template <bool isServer>
    void sendTobiiErrorAsJson(uWS::WebSocket<isServer> *ws_, TobiiResearchStatus result_, std::string errMsg_)
    {
        sendJson(ws_, {{"error", errMsg_},{"TobiiErrorCode",result_},{"TobiiErrorString",TobiiResearchStatusToString(result_)},{"TobiiErrorExplanation",TobiiResearchStatusToExplanation(result_)}});
    }

    template <bool isServer>
    void sendTobiiErrorAsJson(uWS::WebSocket<isServer> *ws_, TobiiResearchLicenseValidationResult result_, std::string errMsg_)
    {
        sendJson(ws_, { {"error", errMsg_},{"TobiiErrorCode",result_},{"TobiiErrorString",TobiiResearchLicenseValidationResultToString(result_)},{"TobiiErrorExplanation",TobiiResearchLicenseValidationResultToExplanation(result_)} });
    }

    json formatSampleAsJSON(TobiiResearchGazeData sample_)
    {
        auto lx = sample_.left_eye .gaze_point.position_on_display_area.x;
        auto ly = sample_.left_eye.gaze_point.position_on_display_area.y;
        auto lp = sample_.left_eye.pupil_data.diameter;
        auto rx = sample_.right_eye.gaze_point.position_on_display_area.x;
        auto ry = sample_.right_eye.gaze_point.position_on_display_area.y;
        auto rp = sample_.right_eye.pupil_data.diameter;

        return
        {
            {"ts", sample_.system_time_stamp},
            {"lx" , lx},
            {"ly" , ly},
            {"lp" , lp},
            {"rx" , rx},
            {"ry" , ry},
            {"rp" , rp}
        };
    }

    json formatSampleAsJSON(Titta::gaze sample_)
    {
        auto lx = sample_.left_eye.gaze_point.position_on_display_area.x;
        auto ly = sample_.left_eye.gaze_point.position_on_display_area.y;
        auto lp = sample_.left_eye.pupil.diameter;
        auto rx = sample_.right_eye.gaze_point.position_on_display_area.x;
        auto ry = sample_.right_eye.gaze_point.position_on_display_area.y;
        auto rp = sample_.right_eye.pupil.diameter;

        return
        {
            {"ts", sample_.system_time_stamp},
            {"lx" , lx},
            {"ly" , ly},
            {"lp" , lp},
            {"rx" , rx},
            {"ry" , ry},
            {"rp" , rp}
        };
    }

    void invoke_function(TobiiResearchGazeData* gaze_data_, void* ptr)
    {
        (*static_cast<std::function<void(TobiiResearchGazeData*)>*>(ptr))(gaze_data_);
    }
}

int main()
{
    // global Tobii Buffer instance
    std::unique_ptr<Titta> TittaInstance;
    TobiiResearchEyeTracker* eyeTracker = nullptr;

    uWS::Hub h;
    std::atomic<int> nClients = 0;
    int downSampFac;
    std::atomic<int> sampleTick = 0;
    std::optional<float> baseSampleFreq;
    bool needSetSampleStreamFreq = true;

    /// SERVER
    auto tobiiBroadcastCallback = [&h, &sampleTick, &downSampFac](TobiiResearchGazeData* gaze_data_)
    {
        sampleTick++;
        if ((sampleTick = sampleTick%downSampFac)!=0)
            // we're downsampling by only sending every downSampFac'th sample (e.g. every second). This is one we're not sending
            return;

        auto jsonMsg = formatSampleAsJSON(*gaze_data_);
        auto msg = jsonMsg.dump();
        h.getDefaultGroup<uWS::SERVER>().broadcast(msg.c_str(), msg.length(), uWS::OpCode::TEXT);
    };

    h.onConnection([&nClients](uWS::WebSocket<uWS::SERVER> *ws, uWS::HttpRequest req)
    {
        std::cout << "Client has connected" << std::endl;
        ws->setNoDelay(true);       // Switch off Nagle (hopefully)
        nClients++;
    });

    h.onMessage([&h, &TittaInstance, &eyeTracker, &tobiiBroadcastCallback, &downSampFac, &baseSampleFreq, &needSetSampleStreamFreq](uWS::WebSocket<uWS::SERVER> *ws, char *message, size_t length, uWS::OpCode opCode)
    {
        auto jsonInput = json::parse(std::string(message, length),nullptr,false);
        if (jsonInput.is_discarded() || jsonInput.is_null())
        {
            sendJson(ws, {{"error", "invalidJson"}});
            return;
        }
#ifdef _DEBUG
        std::cout << "Received message on server: " << jsonInput.dump(4) << std::endl;
#endif

        if (jsonInput.count("action")==0)
        {
            sendJson(ws, {{"error", "jsonMissingParam"},{"param","action"}});
            return;
        }

        // get corresponding action
        auto actionStr = jsonInput.at("action").get<std::string>();
        if (actionTypeMap.count(actionStr)==0)
        {
            sendJson(ws, {{"error", "Unrecognized action"}, {"action", actionStr}});
            return;
        }
        Action action = actionTypeMap.at(actionStr);

        switch (action)
        {
            case Action::Connect:
            {
                if (!eyeTracker)
                {
                    TobiiResearchEyeTrackers* eyetrackers = nullptr;
                    TobiiResearchStatus result = tobii_research_find_all_eyetrackers(&eyetrackers);

                    // notify if no tracker found
                    if (result != TOBII_RESEARCH_STATUS_OK)
                    {
                        sendTobiiErrorAsJson(ws, result, "Problem finding eye tracker");
                        return;
                    }

                    // select eye tracker.
                    eyeTracker = eyetrackers->eyetrackers[0];
                }

                // if license file is found in the directory, try applying it
                auto cp = std::filesystem::current_path();
                if (std::filesystem::exists("./TobiiLicense"))    // file with this name expected in cwd
                {
                    std::ifstream input("./TobiiLicense", std::ios::binary);
                    std::vector<char> buffer(std::istreambuf_iterator<char>(input), {});

#                   define NUM_OF_LICENSES 1
                    char* license_key_ring[NUM_OF_LICENSES];
                    license_key_ring[0] = &buffer[0];
                    size_t sizes[NUM_OF_LICENSES];
                    sizes[0] = buffer.size();
                    TobiiResearchLicenseValidationResult validation_results[NUM_OF_LICENSES];
                    TobiiResearchStatus result = tobii_research_apply_licenses(eyeTracker, (const void**)license_key_ring, sizes, validation_results, NUM_OF_LICENSES);
                    if (result != TOBII_RESEARCH_STATUS_OK || validation_results[0] != TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_OK)
                    {
                        if (result != TOBII_RESEARCH_STATUS_OK)
                            sendTobiiErrorAsJson(ws, result, "License file \"TobiiLicense\" found in pwd, but could not be applied.");
                        else
                            sendTobiiErrorAsJson(ws, validation_results[0], "License file \"TobiiLicense\" found in pwd, but could not be applied.");
                        return;
                    }
                }

                // get info about the connected eye tracker
                char* address;
                char* serialNumber;
                char* deviceName;
                tobii_research_get_address(eyeTracker, &address);
                tobii_research_get_serial_number(eyeTracker, &serialNumber);
                tobii_research_get_model(eyeTracker, &deviceName);

                // reply informing what eye-tracker we just connected to
                sendJson(ws, {{"action", "connect"}, {"deviceModel", deviceName}, {"serialNumber", serialNumber}, {"address", address}});

                // clean up
                tobii_research_free_string(address);
                tobii_research_free_string(serialNumber);
                tobii_research_free_string(deviceName);
            }
            break;
            case Action::SetSampleStreamFreq:
            {
                if (jsonInput.count("freq") == 0)
                {
                    sendJson(ws, {{"error", "jsonMissingParam"},{"param","freq"}});
                    return;
                }
                auto freq = jsonInput.at("freq").get<float>();

                // see what frequencies the connect device supports
                std::vector<float> frequencies;
                if (baseSampleFreq.has_value())
                    frequencies.push_back(baseSampleFreq.value());
                else
                {
                    TobiiResearchGazeOutputFrequencies* tobiiFreqs = nullptr;
                    TobiiResearchStatus result = tobii_research_get_all_gaze_output_frequencies(eyeTracker, &tobiiFreqs);
                    if (result != TOBII_RESEARCH_STATUS_OK)
                    {
                        sendTobiiErrorAsJson(ws, result, "Problem getting sampling frequencies");
                        return;
                    }
                    frequencies.insert(frequencies.end(),&tobiiFreqs->frequencies[0], &tobiiFreqs->frequencies[tobiiFreqs->frequency_count]);   // yes, pointer to one past last element
                    tobii_research_free_gaze_output_frequencies(tobiiFreqs);
                }

                // see if the requested frequency is a divisor of any of the supported frequencies, choose the best one (lowest possible frequency)
                auto best = frequencies.cend();
                downSampFac = 9999;
                for (auto x = frequencies.cbegin(); x!=frequencies.cend(); ++x)
                {
                    // is this frequency is a multiple of the requested frequency and thus in our set of potential sampling frequencies?
                    if (static_cast<int>(*x+.5f)%static_cast<int>(freq+.5f) == 0)
                    {
                        // check if this is a lower frequency than previously selecting (i.e., is the downsampling factor lower?)
                        auto tempDownSampFac = static_cast<int>(*x/freq+.5f);
                        if (tempDownSampFac<downSampFac)
                        {
                            // yes, we got a new best option
                            best = x;
                            downSampFac = tempDownSampFac;
                        }
                    }
                }
                // no matching frequency found: error
                if (best==frequencies.cend())
                {
                    if (baseSampleFreq.has_value())
                    {
                        sendJson(ws, {{"error", "invalidParam"},{"param","freq"},{"reason","requested frequency is not a divisor of the set base frequency "},{"baseFreq",baseSampleFreq.value()}});
                    }
                    else
                        sendJson(ws, {{"error", "invalidParam"},{"param","freq"},{"reason","requested frequency is not a divisor of any supported sampling frequency"}});
                    return;
                }
                // select best frequency as base frequency. Downsampling factor is already set above
                freq = *best;

                // now set the tracker to the base frequency
                TobiiResearchStatus result = tobii_research_set_gaze_output_frequency(eyeTracker, freq);
                if (result != TOBII_RESEARCH_STATUS_OK)
                {
                    sendTobiiErrorAsJson(ws, result, "Problem setting sampling frequency");
                    return;
                }

                needSetSampleStreamFreq = false;
                sendJson(ws, {{"action", "setSampleFreq"}, {"freq", freq/downSampFac}, {"baseFreq", freq}, {"status", true}});
                break;
            }
            case Action::StartSampleStream:
            {
                if (needSetSampleStreamFreq)
                {
                    sendJson(ws, {{"error", "startSampleStream"},{"reason","You have to set the stream sample rate first using action setSampleStreamFreq. NB: you also have to do this after calling setBaseSampleFreq."}});
                    return;
                }
                TobiiResearchStatus result = tobii_research_subscribe_to_gaze_data(eyeTracker, &invoke_function, new std::function<void(TobiiResearchGazeData*)>(tobiiBroadcastCallback));
                if (result != TOBII_RESEARCH_STATUS_OK)
                {
                    sendTobiiErrorAsJson(ws, result, "Problem subscribing to gaze data");
                    return;
                }

                sendJson(ws, {{"action", "startSampleStream"}, {"status", true}});
                break;
            }
            case Action::StopSampleStream:
            {
                TobiiResearchStatus result = tobii_research_unsubscribe_from_gaze_data(eyeTracker, &invoke_function);
                if (result != TOBII_RESEARCH_STATUS_OK)
                {
                    sendTobiiErrorAsJson(ws, result, "Problem unsubscribing from gaze data");
                    return;
                }

                sendJson(ws, {{"action", "stopSampleStream"}, {"status", true}});
                break;
            }

            case Action::SetBaseSampleFreq:
            {
                if (jsonInput.count("freq") == 0)
                {
                    sendJson(ws, {{"error", "jsonMissingParam"},{"param","freq"}});
                    return;
                }
                auto freq = jsonInput.at("freq").get<float>();

                // now set the tracker to the base frequency
                TobiiResearchStatus result = tobii_research_set_gaze_output_frequency(eyeTracker, freq);
                if (result != TOBII_RESEARCH_STATUS_OK)
                {
                    sendTobiiErrorAsJson(ws, result, "Problem setting sampling frequency");
                    return;
                }
                baseSampleFreq = freq;

                // user needs to reset sampleStream frequency after calling this, as downsample factor may have changed or requested may even have become unavailable
                needSetSampleStreamFreq = true;
                // also ensure no stream is currently active
                tobii_research_unsubscribe_from_gaze_data(eyeTracker, &invoke_function);

                sendJson(ws, {{"action", "setSampleFreq"}, {"freq", freq}, {"status", true}});
                break;
            }
            case Action::StartSampleBuffer:
            {
                if (!TittaInstance.get())
                    if (eyeTracker)
                        TittaInstance = std::make_unique<Titta>(eyeTracker);
                    else
                    {
                        sendJson(ws, {{"error", "startSampleBuffer"},{"reason","you need to do the \"connect\" action first"}});
                        return;
                    }

                bool status = false;
                if (TittaInstance.get())
                {
                    if (TittaInstance.get()->hasStream(Titta::Stream::EyeOpenness))
                        TittaInstance.get()->setIncludeEyeOpennessInGaze(true);
                    status = TittaInstance.get()->start(Titta::Stream::Gaze);
                }

                sendJson(ws, {{"action", "startSampleBuffer"}, {"status", status}});
                break;
            }
            case Action::ClearSampleBuffer:
                if (TittaInstance.get())
                    TittaInstance.get()->clear(Titta::Stream::Gaze);
                sendJson(ws, {{"action", "clearSampleBuffer"}, {"status", true}});  // nothing to clear or cleared, both success status
                break;
            case Action::PeekSamples:
            {
                // get sample
                auto jsonOutput = json::array();   // empty array if no samples
                if (TittaInstance.get())
                {
                    using argType = function_traits<decltype(&Titta::peekN<Titta::gaze>)>::argument<1>::type::value_type;
                    std::optional<argType> nSamples;
                    if (jsonInput.count("nSamples"))
                        nSamples = jsonInput.at("nSamples").get<argType>();

                    auto samples = TittaInstance.get()->peekN<Titta::gaze>(nSamples);
                    if (!samples.empty())
                    {
                        for (auto sample: samples)
                            jsonOutput.push_back(formatSampleAsJSON(sample));
                    }
                }

                // send
                sendJson(ws, jsonOutput);
                break;
            }
            case Action::StopSampleBuffer:
            {
                bool status = false;
                if (TittaInstance.get())
                    status = TittaInstance.get()->stop(Titta::Stream::Gaze);

                sendJson(ws, {{"action", "stopSampleBuffer"}, {"status", status}});
                break;
            }
            case Action::SaveData:
            {
                if (TittaInstance.get())
                {
                    std::optional<std::string> filePathOpt;
                    if (jsonInput.count("filePath"))
                        filePathOpt = jsonInput.at("filePath").get<std::string>();
                    auto filePath = filePathOpt.value_or("data.txt");

                    auto num_put = new NumPut<>();
                    std::locale locale(std::cout.getloc(), num_put);    // pass ownership

                    std::ofstream outFile;
                    outFile.open(filePath, std::iostream::out| std::iostream::trunc);
                    if (outFile.is_open())
                    {
                        outFile.imbue(locale);

                        // header
                        for (auto x : {
                            "device_time_stamp",
                            "system_time_stamp",

                            "left_gaze_point_available",
                            "left_gaze_point_valid",
                            "left_gaze_point_on_display_area_x",
                            "left_gaze_point_on_display_area_y",
                            "left_gaze_point_in_user_coordinates_x",
                            "left_gaze_point_in_user_coordinates_y",
                            "left_gaze_point_in_user_coordinates_z",
                            "left_gaze_origin_available",
                            "left_gaze_origin_valid",
                            "left_gaze_origin_in_trackbox_coordinates_x",
                            "left_gaze_origin_in_trackbox_coordinates_y",
                            "left_gaze_origin_in_trackbox_coordinates_z",
                            "left_gaze_origin_in_user_coordinates_x",
                            "left_gaze_origin_in_user_coordinates_y",
                            "left_gaze_origin_in_user_coordinates_z",
                            "left_pupil_available",
                            "left_pupil_valid",
                            "left_pupil_diameter",
                            "left_eye_openness_available",
                            "left_eye_openness_valid",
                            "left_eye_openness_diameter",

                            "right_gaze_point_available",
                            "right_gaze_point_valid",
                            "right_gaze_point_on_display_area_x",
                            "right_gaze_point_on_display_area_y",
                            "right_gaze_point_in_user_coordinates_x",
                            "right_gaze_point_in_user_coordinates_y",
                            "right_gaze_point_in_user_coordinates_z",
                            "right_gaze_origin_available",
                            "right_gaze_origin_valid",
                            "right_gaze_origin_in_trackbox_coordinates_x",
                            "right_gaze_origin_in_trackbox_coordinates_y",
                            "right_gaze_origin_in_trackbox_coordinates_z",
                            "right_gaze_origin_in_user_coordinates_x",
                            "right_gaze_origin_in_user_coordinates_y",
                            "right_gaze_origin_in_user_coordinates_z",
                            "right_pupil_available",
                            "right_pupil_valid",
                            "right_pupil_diameter",
                            "right_eye_openness_available",
                            "right_eye_openness_valid",
                            "right_eye_openness_diameter",
                            })
                        {
                            outFile << x << '\t';
                        }
                        outFile << '\n';

                        // samples
                        for (const auto& sample : TittaInstance.get()->consumeN<Titta::gaze>())
                        {
                            outFile << sample.device_time_stamp << '\t';
                            outFile << sample.system_time_stamp << '\t';

                            outFile << sample.left_eye.gaze_point.available << '\t';
                            outFile << (sample.left_eye.gaze_point.validity==TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.left_eye.gaze_point.position_on_display_area.x << '\t';
                            outFile << sample.left_eye.gaze_point.position_on_display_area.y << '\t';
                            outFile << sample.left_eye.gaze_point.position_in_user_coordinates.x << '\t';
                            outFile << sample.left_eye.gaze_point.position_in_user_coordinates.y << '\t';
                            outFile << sample.left_eye.gaze_point.position_in_user_coordinates.z << '\t';
                            outFile << sample.left_eye.gaze_origin.available << '\t';
                            outFile << (sample.left_eye.gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.left_eye.gaze_origin.position_in_track_box_coordinates.x << '\t';
                            outFile << sample.left_eye.gaze_origin.position_in_track_box_coordinates.y << '\t';
                            outFile << sample.left_eye.gaze_origin.position_in_track_box_coordinates.z << '\t';
                            outFile << sample.left_eye.gaze_origin.position_in_user_coordinates.x << '\t';
                            outFile << sample.left_eye.gaze_origin.position_in_user_coordinates.y << '\t';
                            outFile << sample.left_eye.gaze_origin.position_in_user_coordinates.z << '\t';
                            outFile << sample.left_eye.pupil.available << '\t';
                            outFile << (sample.left_eye.pupil.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.left_eye.pupil.diameter << '\t';
                            outFile << sample.left_eye.eye_openness.available << '\t';
                            outFile << (sample.left_eye.eye_openness.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.left_eye.eye_openness.diameter << '\t';

                            outFile << sample.right_eye.gaze_point.available << '\t';
                            outFile << (sample.right_eye.gaze_point.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.right_eye.gaze_point.position_on_display_area.x << '\t';
                            outFile << sample.right_eye.gaze_point.position_on_display_area.y << '\t';
                            outFile << sample.right_eye.gaze_point.position_in_user_coordinates.x << '\t';
                            outFile << sample.right_eye.gaze_point.position_in_user_coordinates.y << '\t';
                            outFile << sample.right_eye.gaze_point.position_in_user_coordinates.z << '\t';
                            outFile << sample.right_eye.gaze_origin.available << '\t';
                            outFile << (sample.right_eye.gaze_origin.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.right_eye.gaze_origin.position_in_track_box_coordinates.x << '\t';
                            outFile << sample.right_eye.gaze_origin.position_in_track_box_coordinates.y << '\t';
                            outFile << sample.right_eye.gaze_origin.position_in_track_box_coordinates.z << '\t';
                            outFile << sample.right_eye.gaze_origin.position_in_user_coordinates.x << '\t';
                            outFile << sample.right_eye.gaze_origin.position_in_user_coordinates.y << '\t';
                            outFile << sample.right_eye.gaze_origin.position_in_user_coordinates.z << '\t';
                            outFile << sample.right_eye.pupil.available << '\t';
                            outFile << (sample.right_eye.pupil.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.right_eye.pupil.diameter << '\t';
                            outFile << sample.right_eye.eye_openness.available << '\t';
                            outFile << (sample.right_eye.eye_openness.validity == TOBII_RESEARCH_VALIDITY_VALID) << '\t';
                            outFile << sample.right_eye.eye_openness.diameter << '\t';
                        outFile << '\n';
                        }
                        outFile.close();
                        sendJson(ws, { {"action", "saveData"}, {"status", true} });
                    }
                    else
                        sendJson(ws, { {"error", "saveData"}, {"reason","could not open file"}, {"filePath", filePath}});
                }
                else
                    sendJson(ws, {{"error", "saveData"}, {"reason","you need to startSampleBuffer first"}});
                break;
            }
            case Action::StoreMessage:
            {
                // TODO: timeStamp and store message somehow
                break;
            }
            default:
                sendJson(ws, {{"error", "Unhandled action"}, {"action", actionStr}});
                break;
        }
    });

    h.onDisconnection([&h,&nClients,&eyeTracker,&TittaInstance](uWS::WebSocket<uWS::SERVER> *ws, int code, char *message, size_t length)
    {
        std::cout << "Client disconnected, code " << code << std::endl;
        if (--nClients == 0)
        {
            std::cout << "No clients left, stopping buffering and streaming, if active..." << std::endl;
            tobii_research_unsubscribe_from_gaze_data(eyeTracker, &invoke_function);
            if (TittaInstance.get())
                TittaInstance.get()->stop("gaze");
        }
    });


#ifdef LOCAL_TEST
    /// CLIENT
    h.onConnection([](uWS::WebSocket<uWS::CLIENT> *ws, uWS::HttpRequest req)
    {
        std::cout << "Client has been notified that its connected" << std::endl;
        // start eye tracker
        sendJson(ws, {{"action", "connect"}});
        sendJson(ws, {{"action", "setSampleStreamFreq"}, {"freq", 120}});
        sendJson(ws, {{"action", "startSampleStream"}});
        sendJson(ws, {{"action", "stopSampleStream"}});
        // request sample
        sendJson(ws, {{"action", "peekSamples"}});
    });
    h.onMessage([](uWS::WebSocket<uWS::CLIENT> *ws, char *message, size_t length, uWS::OpCode opCode)
    {
        std::cout << "Received message on client: " << std::string(message, length) << std::endl;
        Sleep(10);
        sendJson(ws, {{"action", "peekSamples"}});
    });

    h.onDisconnection([&h](uWS::WebSocket<uWS::CLIENT> *ws, int code, char *message, size_t length)
    {
        std::cout << "Server has disconnected me with status code " << code << " and message: " << std::string(message, length) << std::endl;
    });
#endif

    h.listen(3003);

#ifdef LOCAL_TEST
    h.connect("ws://localhost:3003", nullptr);
#endif

    h.run();
}




// function for handling errors generated by lib
void DoExitWithMsg(std::string errMsg_)
{
    std::cout << "Error: " << errMsg_ << std::endl;
}
