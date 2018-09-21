#define _CRT_SECURE_NO_WARNINGS // for uWS.h
#include <iostream>
#include <map>
#include <string>
#include <sstream>

#include <uWS/uWS.h>
#include <nlohmann/json.hpp>
using json = nlohmann::json;

#include "TobiiBuffer/TobiiBuffer.h"
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
        ClearSampleBuffer,
        PeekSamples,
        SaveData,
        SendMessage,
        StopSampleStream
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "connect"          , Action::Connect},
        { "setSampleFreq"    , Action::SetSampleFreq},
        { "startSampleStream", Action::StartSampleStream},
        { "clearSampleBuffer", Action::ClearSampleBuffer},
        { "peekSamples"      , Action::PeekSamples},
        { "saveData"         , Action::SaveData},
        { "sendMessage"      , Action::SendMessage},
        { "stopSampleStream" , Action::StopSampleStream},
    };

    template <bool isServer>
    void sendJson(uWS::WebSocket<isServer> *ws, json jsonMsg)
    {
        auto msg = jsonMsg.dump();
        ws->send(msg.c_str(), msg.length(), uWS::OpCode::TEXT);
    }
}

int main() {
    // global Tobii Buffer instance
    std::unique_ptr<TobiiBuffer> g_TobiiBufferInstance;

    uWS::Hub h;


    int numRequests = 0;

    /// SERVER
    h.onConnection([](uWS::WebSocket<uWS::SERVER> *ws, uWS::HttpRequest req)
    {
        std::cout << "Client has connected" << std::endl;
    });

    h.onMessage([&h, &numRequests, &g_TobiiBufferInstance](uWS::WebSocket<uWS::SERVER> *ws, char *message, size_t length, uWS::OpCode opCode)
    {
        auto jsonMsg = json::parse(std::string(message, length));
        std::cout << "Received message on server: " << jsonMsg.dump(4) << std::endl;

        if (jsonMsg.count("action")==0)
        {
            sendJson(ws, {{"error", "jsonMissingAction"}});
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
                if (!g_TobiiBufferInstance.get())
                {
                    TobiiResearchEyeTrackers* eyetrackers = nullptr;
                    TobiiResearchStatus result;
                    result = tobii_research_find_all_eyetrackers(&eyetrackers);

                    // notify if no tracker found
                    if (result != TOBII_RESEARCH_STATUS_OK)
                    {
                        sendJson(ws, {{"error", "noET"}});
                        return;
                    }

                    // connect to eye tracker.
                    char* address;
                    tobii_research_get_address(eyetrackers->eyetrackers[0], &address);
                    g_TobiiBufferInstance = std::make_unique<TobiiBuffer>(address);

                    // reply informing what eye-tracker we just connected to
                    sendJson(ws, {{"action", "connect"}, {"tracker", address}});

                    // clean up
                    tobii_research_free_string(address);
                }
                break;
            case Action::SetSampleFreq:
            {
            }
            case Action::StartSampleStream:
            {
                bool status = false;
                if (g_TobiiBufferInstance.get())
                    status = g_TobiiBufferInstance.get()->startSampleBuffering();

                sendJson(ws, {{"action", "startSampleStream"}, {"status", status}});
                break;
            }
            case Action::ClearSampleBuffer:
                if (g_TobiiBufferInstance.get())
                    g_TobiiBufferInstance.get()->clearSampleBuffer();
                break;
            case Action::PeekSamples:
            {
                // get sample
                if (g_TobiiBufferInstance.get())
                {
                    size_t nSamples = TobiiBuff::g_peekDefaultAmount;
                    if (jsonMsg.count("nSamples"))
                    {
                        nSamples = jsonMsg.at("action").get<size_t>();
                    }

                    auto samples = g_TobiiBufferInstance.get()->peekSamples(nSamples);
                    json jsonMsg;
                    if (!samples.empty())   // TODO: multiple samples in array
                    {
                        auto x = (samples[0].left_eye.gaze_point.position_on_display_area.x + samples[0].right_eye.gaze_point.position_on_display_area.x) / 2.;
                        auto y = (samples[0].left_eye.gaze_point.position_on_display_area.y + samples[0].right_eye.gaze_point.position_on_display_area.y) / 2.;
                        jsonMsg =
                        {
                            {"ts", samples[0].system_time_stamp},
                            {"x" , x},
                            {"y" , y}
                        };
                    }
                    else
                    {
                        jsonMsg =
                        {
                            {"ts", 0},
                            {"x" , nullptr},
                            {"y" , nullptr}
                        };
                    }
                    // send
                    sendJson(ws, jsonMsg);
                    numRequests++;
                }
                break;
            }
            case Action::SaveData:
            {
                auto samples = g_TobiiBufferInstance.get()->consumeSamples();
                // TODO: store all to file somehow
                break;
            }
            case Action::SendMessage:
            {
                // TODO: timeStamp and store message somehow
                break;
            }
            case Action::StopSampleStream:
            {
                bool status = false;
                if (g_TobiiBufferInstance.get())
                    status = g_TobiiBufferInstance.get()->stopSampleBuffering();

                sendJson(ws, {{"action", "stopSampleStream"}, {"status", status}});
                break;
            }
            default:
                sendJson(ws, {{"error", "Unhandled action"}, {"action", actionStr}});
                break;
        }

        if (numRequests>=100)
        {
            const char *closeMessage = "We're done, stop it now";
            ws->close(1000, closeMessage, strlen(closeMessage));
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
