#include "LSL_streamer/LSL_streamer.h"

#include <Titta/Titta.h>

#include <iostream>
#include <chrono>
#include <thread>


void DoExitWithMsg(std::string errMsg_);

int main(int argc, char** argv)
{
    try
    {
        std::vector<TobiiTypes::eyeTracker> eyeTrackers;
        for (int i = 0; i < 4; i++)
        {
            eyeTrackers = Titta::findAllEyeTrackers();
            if (!eyeTrackers.empty())
                break;
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }

        if (!eyeTrackers.empty())
        {
            std::cout << "connecting to: " << eyeTrackers[0].deviceName << std::endl;
            auto tobii_lsl = LSL_streamer(eyeTrackers[0]);

            std::cout << "starting stream" << std::endl;
            tobii_lsl.setIncludeEyeOpennessInGaze(true);
            tobii_lsl.startOutlet(Titta::Stream::Gaze);
            tobii_lsl.startOutlet(Titta::Stream::ExtSignal);
            tobii_lsl.startOutlet(Titta::Stream::TimeSync);
            tobii_lsl.startOutlet(Titta::Stream::Positioning);

            std::this_thread::sleep_for(std::chrono::seconds(1));
            auto streams = LSL_streamer::getRemoteStreams("");
            for (auto& s: streams)
            {
                std::cout << s.name() << " " << s.hostname() << " " << s.type() << " " << s.source_id() << std::endl;
            }
            std::cout << "----" << std::endl;
            streams = LSL_streamer::getRemoteStreams("gaze");
            for (auto& s : streams)
            {
                std::cout << s.name() << " " << s.hostname() << " " << s.type() << " " << s.source_id() << std::endl;
            }
            std::cout << streams[0].as_xml() << std::endl;
            auto id = tobii_lsl.createListener(streams[0].source_id());
            std::cout << tobii_lsl.getInletInfo(id).as_xml() << std::endl;

            for (int i = 0; i < 60; i++)
            {
                std::cout << "sleep" << std::endl;
                std::this_thread::sleep_for(std::chrono::seconds(1));
            }
            std::cout << "done" << std::endl;
        }
        else
            std::cout << "no eye tracker" << std::endl;
    }
    catch (const std::string& e)
    {
        DoExitWithMsg(e);
    }
    catch (const char* e)
    {
        DoExitWithMsg(e);
    }
    catch (...)
    {
        DoExitWithMsg("Some exception occurred");
    }

    return 0;
}

void DoExitWithMsg(std::string errMsg_)
{
    std::cout << "Error: " << errMsg_ << std::endl;
}