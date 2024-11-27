function tell_to_disconnect(outlet,hostname)
outlet.push_sample({sprintf('disconnect_stream,%s',hostname)});