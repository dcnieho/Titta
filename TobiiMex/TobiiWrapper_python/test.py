import TobiiWrapper
import time

print(TobiiWrapper)
help(TobiiWrapper)
help(TobiiWrapper.TobiiWrapper)

tw = TobiiWrapper.TobiiWrapper('test')
print(tw)

success = tw.startSampleBuffering()
print(success)

time.sleep(5)
samples = sampEvtBuffers.getSamples()

sampEvtBuffers.stopSampleBuffering(true)    # optional input indicating whether to also destroy buffer (delete samples) or not