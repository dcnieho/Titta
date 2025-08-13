import time

# Import modules
import TittaPy_v2
from TittaPy_v2 import EyeTracker

import TittaLSLPy_v2
from TittaLSLPy_v2 import Sender, Receiver

#help(TittaPy_v2)
#help(EyeTracker)

#help(TittaLSLPy_v2)
#help(Sender)
#help(Receiver)

#exit()


# get eye trackers from TittaPy_v2, connect to first
ets = TittaPy_v2.find_all_eye_trackers()
print(ets)
#EThndl = EyeTracker(ets[0]['address'])

# test static functions
print(TittaLSLPy_v2.__version__)
print(TittaLSLPy_v2.get_Tobii_SDK_version())
print(TittaLSLPy_v2.get_LSL_version())

# exercise outlet
sender = Sender(ets[0]['address'])
print(sender.get_eye_tracker())
print(sender.get_stream_source_id("gaze"))  # can be used to filter out local stream when retrieving streams with Reciever.get_streams()
print(sender.is_streaming('gaze'))
print(sender.is_streaming(EyeTracker.stream.gaze))
sender.create('gaze')
print(sender.is_streaming('gaze'))
sender.set_include_eye_openness_in_gaze(True)
print(sender)

# exercise inlet
remote_streams = Receiver.get_streams("gaze" if True else None)  # can filter so only streams of specific type are provided
print(remote_streams)
receiver = Receiver(remote_streams[0]["source_id"])
print(receiver)
print(receiver.get_info())
print(receiver.get_type())
receiver.start()
print(receiver.is_recording())
time.sleep(10)
sample = receiver.peek_N(2)
print(sample)
samples = receiver.consume_time_range()
print(len(samples['remote_system_time_stamp']),samples['remote_system_time_stamp'][:10])
receiver.stop()

# done with outlet also
sender.destroy('gaze')
print(sender.is_streaming('gaze'))

exit()