import time

# Import modules
import TittaPy
from TittaPy import EyeTracker

import TittaLSLPy
from TittaLSLPy import TittaLSL

#help(TittaPy)
#help(EyeTracker)
#help(TittaLSLPy)
#help(TittaLSL)
#exit()


# get eye trackers from TittaPy, connect to first
ets = TittaPy.find_all_eye_trackers()
print(ets)
#EThndl = EyeTracker(ets[0]['address'])

# test static functions
print(TittaLSLPy.__version__)
print(TittaLSLPy.get_Tobii_SDK_version())
print(TittaLSLPy.get_LSL_version())

# make class instance and exercise outlet
lsl = TittaLSL()
lsl.connect(ets[0]['address'])
print(lsl.is_streaming('gaze'))
print(lsl.is_streaming(EyeTracker.stream.gaze))
lsl.start_outlet('gaze')
print(lsl.is_streaming('gaze'))
lsl.set_include_eye_openness_in_gaze(True)
#lsl.stop_outlet('gaze')
#print(lsl.is_streaming('gaze'))

# exercise inlet
remote_streams = TittaLSL.get_remote_streams("gaze" if True else None)  # can filter so only streams of specific type are provided
print(remote_streams)
iid = lsl.create_listener(remote_streams[0]["source_id"])
print(lsl.get_inlet_info(iid))
print(lsl.get_inlet_type(iid))
lsl.start_listening(iid)
print(lsl.is_listening(iid))
time.sleep(1)
sample = lsl.peek_N(iid,2)
print(sample)
samples = lsl.consume_time_range(iid)
print(len(samples['remote_system_time_stamp']),samples['remote_system_time_stamp'][:10])
lsl.delete_listener(iid)

lsl.stop_outlet('gaze')
print(lsl.is_streaming('gaze'))

exit()