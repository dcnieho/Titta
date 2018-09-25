#define _CRT_SECURE_NO_WARNINGS // for uWS.h
#include <iostream>
#include <map>
#include <string>
#include <sstream>

#include <uWS/uWS.h>
#include <nlohmann/json.hpp>
using json = nlohmann::json;

#include "TobiiBuffer/TobiiBuffer.h"
#include "TobiiBuffer/utils.h"
#pragma comment(lib, "TobiiBuffer.lib")

void DoExitWithMsg(std::string errMsg_);

//#define LOCAL_TEST

namespace {
    // List actions
    enum class Action
    {
        Connect,
        SetSampleFreq,
        StartSampleStream,
        StopSampleStream,
        StartSampleBuffer,
        ClearSampleBuffer,
        PeekSamples,
        StopSampleBuffer,
        SaveData,
        SendMessage
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "connect"          , Action::Connect},
        { "setSampleFreq"    , Action::SetSampleFreq},
        { "startSampleStream", Action::StartSampleStream},
        { "stopSampleStream" , Action::StopSampleStream},
        { "startSampleBuffer", Action::StartSampleBuffer},
        { "clearSampleBuffer", Action::ClearSampleBuffer},
        { "peekSamples"      , Action::PeekSamples},
        { "stopSampleBuffer" , Action::StopSampleBuffer},
        { "saveData"         , Action::SaveData},
        { "sendMessage"      , Action::SendMessage},
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

    json formatSampleAsJSON(TobiiResearchGazeData sample_)
    {
        auto x = (sample_.left_eye.gaze_point.position_on_display_area.x + sample_.right_eye.gaze_point.position_on_display_area.x) / 2.;
        auto y = (sample_.left_eye.gaze_point.position_on_display_area.y + sample_.right_eye.gaze_point.position_on_display_area.y) / 2.;
        
        return
        {
            {"ts", sample_.system_time_stamp},
            {"x" , x},
            {"y" , y}
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
    std::unique_ptr<TobiiBuffer> TobiiBufferInstance;
    TobiiResearchEyeTracker* eyeTracker = nullptr;

    uWS::Hub h;

    /// SERVER
    auto tobiiBroadcastCallback = [&h](TobiiResearchGazeData* gaze_data_)
    {
        auto jsonMsg = formatSampleAsJSON(*gaze_data_);
        auto msg = jsonMsg.dump();
        h.getDefaultGroup<uWS::SERVER>().broadcast(msg.c_str(), msg.length(), uWS::OpCode::TEXT);
    };

    h.onConnection([](uWS::WebSocket<uWS::SERVER> *ws, uWS::HttpRequest req)
    {
        std::cout << "Client has connected" << std::endl;
    });

    h.onMessage([&h, &TobiiBufferInstance, &eyeTracker, &tobiiBroadcastCallback](uWS::WebSocket<uWS::SERVER> *ws, char *message, size_t length, uWS::OpCode opCode)
    {
        auto jsonMsg = json::parse(std::string(message, length));
        std::cout << "Received message on server: " << jsonMsg.dump(4) << std::endl;

        if (jsonMsg.count("action")==0)
        {
            sendJson(ws, {{"error", "jsonMissingParam"},{"param","action"}});
            return;
        }

        // get corresponding action
        auto actionStr = jsonMsg.at("action").get<std::string>();
        if (actionTypeMap.count(actionStr)==0)
        {
            sendJson(ws, {{"error", "Unrecognized action"}, {"action", actionStr}});
            return;
        }
        Action action = actionTypeMap.at(actionStr);

        switch (action)
        {
            case Action::Connect:
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

                    // get info about the connected eye tracker.
                    eyeTracker = eyetrackers->eyetrackers[0];
                    char* address;
                    char* serial_number;
                    char* device_name;
                    tobii_research_get_address(eyeTracker, &address);
                    tobii_research_get_serial_number(eyeTracker, &serial_number);
                    tobii_research_get_device_name(eyeTracker, &device_name);

                    // reply informing what eye-tracker we just connected to
                    sendJson(ws, {{"action", "connect"}, {"deviceName", device_name}, {"serialNumber", serial_number}, {"address", address}});

                    // clean up
                    tobii_research_free_string(address);
                    tobii_research_free_string(serial_number);
                    tobii_research_free_string(device_name);
                }
                break;
            case Action::SetSampleFreq:
            {
                if (jsonMsg.count("freq") == 0)
                {
                    sendJson(ws, {{"error", "jsonMissingParam"},{"param","freq"}});
                    return;
                }
                auto freq = jsonMsg.at("freq").get<float>();

                TobiiResearchStatus result = tobii_research_set_gaze_output_frequency(eyeTracker, freq);
                if (result != TOBII_RESEARCH_STATUS_OK)
                {
                    sendTobiiErrorAsJson(ws, result, "Problem setting sampling frequency");
                    return;
                }

                sendJson(ws, {{"action", "setSampleFreq"}, {"freq", freq}, {"status", true}});
                break;
            }
            case Action::StartSampleStream:
            {
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

            case Action::StartSampleBuffer:
            {
                if (!TobiiBufferInstance.get())
                {
                    char* address;
                    TobiiResearchStatus result = tobii_research_get_address(eyeTracker, &address);
                    if (result != TOBII_RESEARCH_STATUS_OK)
                    {
                        sendTobiiErrorAsJson(ws, result, "Problem getting eye tracker");
                        return;
                    }

                    TobiiBufferInstance = std::make_unique<TobiiBuffer>(address);
                    tobii_research_free_string(address);
                }

                bool status = false;
                if (TobiiBufferInstance.get())
                    status = TobiiBufferInstance.get()->startSampleBuffering();

                sendJson(ws, {{"action", "startSampleBuffer"}, {"status", status}});
                break;
            }
            case Action::ClearSampleBuffer:
                if (TobiiBufferInstance.get())
                    TobiiBufferInstance.get()->clearSampleBuffer();
                break;
            case Action::PeekSamples:
            {
                // get sample
                auto jsonMsg = json::array();   // empty array if no samples
                if (TobiiBufferInstance.get())
                {
                    size_t nSamples = TobiiBuff::g_peekDefaultAmount;
                    if (jsonMsg.count("nSamples"))
                    {
                        nSamples = jsonMsg.at("nSamples").get<decltype(nSamples)>();
                    }

                    auto samples = TobiiBufferInstance.get()->peekSamples(nSamples);
                    if (!samples.empty())
                    {
                        for (auto sample: samples)
                        {
                            jsonMsg.push_back(formatSampleAsJSON(sample));
                        }
                    }
                }

                // send
                sendJson(ws, jsonMsg);
                break;
            }
            case Action::StopSampleBuffer:
            {
                bool status = false;
                if (TobiiBufferInstance.get())
                    status = TobiiBufferInstance.get()->stopSampleBuffering();

                sendJson(ws, {{"action", "stopSampleBuffer"}, {"status", status}});
                break;
            }
            case Action::SaveData:
            {
                if (TobiiBufferInstance.get())
                {
                    auto samples = TobiiBufferInstance.get()->consumeSamples();
                    // TODO: store all to file somehow
                }
                break;
            }
            case Action::SendMessage:
            {
                // TODO: timeStamp and store message somehow
                break;
            }
            default:
                sendJson(ws, {{"error", "Unhandled action"}, {"action", actionStr}});
                break;
        }
    });

    h.onDisconnection([&h](uWS::WebSocket<uWS::SERVER> *ws, int code, char *message, size_t length)
    {
        std::cout << "Client disconnected, code " << code << std::endl;
        h.getDefaultGroup<uWS::SERVER>().close();   // trigger shutdown of server
    });


#ifdef LOCAL_TEST
    /// CLIENT
    h.onConnection([](uWS::WebSocket<uWS::CLIENT> *ws, uWS::HttpRequest req)
    {
        std::cout << "Client has been notified that its connected" << std::endl;
        // start eye tracker
        sendJson(ws, {{"action", "connect"}});
        sendJson(ws, {{"action", "setSampleFreq"}, {"freq", 120}});
        sendJson(ws, {{"action", "startSampleStream"}});
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
