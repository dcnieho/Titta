#define _CRT_SECURE_NO_WARNINGS
#include <uWS/uWS.h>
#include <iostream>
#include <map>
#include <string>
#include <sstream>

#include "TobiiBuffer/TobiiBuffer.h"
#pragma comment(lib, "TobiiBuffer.lib")

//#define LOCAL_TEST

namespace {
    // List actions
    enum class Action
    {
        StartSampleBuffering,
        ClearSampleBuffer,
        PeekSamples,
        StopSampleBuffering,
        SaveSamples
    };

    // Map string (first input argument to mexFunction) to an Action
    const std::map<std::string, Action> actionTypeMap =
    {
        { "startSampleBuffering",		Action::StartSampleBuffering },
        { "clearSampleBuffer",			Action::ClearSampleBuffer },
        { "peekSamples",				Action::PeekSamples },
        { "stopSampleBuffering",		Action::StopSampleBuffering },
        { "saveSamples",				Action::SaveSamples },
    };
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
        std::cout << "Received message on server: " << std::string(message, length) << std::endl;

        // get corresponding action
        auto actionStr = std::string(message, length);
        if (actionTypeMap.count(actionStr) == 0)
            std::cout << "Unrecognized action (not in actionTypeMap): " << actionStr << std::endl;
        Action action = actionTypeMap.at(actionStr);

        switch (action)
        {
            case Action::StartSampleBuffering:
            {
                if (!g_TobiiBufferInstance.get())
                {
                    // connect to eye tracker. TODO: don't hardcode which eye-tracker
                    g_TobiiBufferInstance = std::make_unique<TobiiBuffer>("tet-tcp://169.254.5.224");
                }

                g_TobiiBufferInstance.get()->startSampleBuffering();
                break;
            }
            case Action::ClearSampleBuffer:
                g_TobiiBufferInstance.get()->clearSampleBuffer();
                break;
            case Action::PeekSamples:
            {
                // get sample
                auto samples = g_TobiiBufferInstance.get()->peekSamples(1);
                std::string message;
                if (!samples.empty())
                {
                    auto x = (samples[0].left_eye.gaze_point.position_on_display_area.x+samples[0].right_eye.gaze_point.position_on_display_area.x)/2.;
                    auto y = (samples[0].left_eye.gaze_point.position_on_display_area.y+samples[0].right_eye.gaze_point.position_on_display_area.y)/2.;
                    // format as json, example: {"ts": 1000, "x": 3.4, "y": 3.4}
                    std::stringstream ss;
                    ss << "{\"ts\":" << samples[0].system_time_stamp << ",\"x\":" << x << ",\"y\":" << y << "}";
                    message = ss.str();
                }
                else
                {
                    message = "{\"ts\":0,\"x\":null,\"y\":null}";
                }
                // send
                ws->send(message.c_str(), message.length(), uWS::OpCode::TEXT);
                numRequests++;
                break;
            }
            case Action::StopSampleBuffering:
                g_TobiiBufferInstance.get()->stopSampleBuffering();
                break;
            case Action::SaveSamples:
            {
                auto samples = g_TobiiBufferInstance.get()->consumeSamples();
                // TODO: store all to file somehow
                break;
            }
            default:
                std::cout << "Unhandled action: " << actionStr << std::endl;
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
        std::string message = "startSampleBuffering";
        ws->send(message.c_str(), message.length(), uWS::OpCode::TEXT);
        // request sample
        message = "peekSamples";
        ws->send(message.c_str(), message.length(), uWS::OpCode::TEXT);
    });
    h.onMessage([](uWS::WebSocket<uWS::CLIENT> *ws, char *message, size_t length, uWS::OpCode opCode)
    {
        std::cout << "Received message on client: " << std::string(message, length) << std::endl;
        Sleep(5);
        std::string newMessage = "peekSamples";
        ws->send(newMessage.c_str(), newMessage.length(), uWS::OpCode::TEXT);
    });

    h.onDisconnection([&h](uWS::WebSocket<uWS::CLIENT> *ws, int code, char *message, size_t length) 
    {
        std::cout << "Server has disconnected me with status code " << code << " and message: " << std::string(message, length) << std::endl;
    });
#endif

    h.listen(3000);

#ifdef LOCAL_TEST
    h.connect("ws://localhost:3000", nullptr);
#endif

    h.run();
}




// function for handling errors generated by lib
void DoExitWithMsg(std::string errMsg_)
{
    std::cout << "Error: " << errMsg_ << std::endl;
}