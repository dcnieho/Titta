import time

# Import modules
import TittaPy
from TittaPy import EyeTracker

import TittaLSLPy
from TittaLSLPy import Streamer, Receiver

#help(TittaPy)
#help(EyeTracker)

#help(TittaLSLPy)
#help(Streamer)
#help(Receiver)

#exit()


# get eye trackers from TittaPy, connect to first
ets = TittaPy.find_all_eye_trackers()
print(ets)
#EThndl = EyeTracker(ets[0]['address'])

# test static functions
print(TittaLSLPy.__version__)
print(TittaLSLPy.get_Tobii_SDK_version())
print(TittaLSLPy.get_LSL_version())

# exercise outlet
streamer = Streamer(ets[0]['address'])
print(streamer.is_streaming('gaze'))
print(streamer.is_streaming(EyeTracker.stream.gaze))
streamer.start_outlet('gaze')
print(streamer.is_streaming('gaze'))
streamer.set_include_eye_openness_in_gaze(True)

# exercise inlet
remote_streams = Receiver.get_remote_streams("gaze" if True else None)  # can filter so only streams of specific type are provided
print(remote_streams)
receiver = Receiver()
iid = receiver.create_listener(remote_streams[0]["source_id"])
print(receiver.get_inlet_info(iid))
print(receiver.get_inlet_type(iid))
receiver.start_listening(iid)
print(receiver.is_listening(iid))
time.sleep(1)
sample = receiver.peek_N(iid,2)
print(sample)
samples = receiver.consume_time_range(iid)
print(len(samples['remote_system_time_stamp']),samples['remote_system_time_stamp'][:10])
receiver.delete_listener(iid)

# done with outlet also
streamer.stop_outlet('gaze')
print(streamer.is_streaming('gaze'))

exit()