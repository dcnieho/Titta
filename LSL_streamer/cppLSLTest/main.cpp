#include "TittaLSL/TittaLSL.h"

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
            auto lslStreamer = TittaLSL::Sender(eyeTrackers[0]);

            std::cout << "starting stream" << std::endl;
            lslStreamer.setIncludeEyeOpennessInGaze(true);
            lslStreamer.start(Titta::Stream::Gaze);
            lslStreamer.start(Titta::Stream::ExtSignal);
            lslStreamer.start(Titta::Stream::TimeSync);
            lslStreamer.start(Titta::Stream::Positioning);

            std::this_thread::sleep_for(std::chrono::seconds(1));
            auto streams = TittaLSL::Receiver::GetStreams("");
            for (auto& s: streams)
            {
                std::cout << s.name() << " " << s.hostname() << " " << s.type() << " " << s.source_id() << std::endl;
            }
            std::cout << "----" << std::endl;
            streams = TittaLSL::Receiver::GetStreams("gaze");
            for (auto& s : streams)
            {
                std::cout << s.name() << " " << s.hostname() << " " << s.type() << " " << s.source_id() << std::endl;
            }
            std::cout << streams[0].as_xml() << std::endl;

            auto lslReceiver = TittaLSL::Receiver(streams[0].source_id());
            std::cout << lslReceiver.getInfo().as_xml() << std::endl;
            lslReceiver.start();

            for (int i = 0; i < 3; i++)
            {
                std::cout << "sleep" << std::endl;
                std::this_thread::sleep_for(std::chrono::seconds(1));
            }
            std::cout << "done" << std::endl;
            auto data = lslReceiver.consumeN<TittaLSL::Receiver::gaze>(1);

            lslReceiver.stop();
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