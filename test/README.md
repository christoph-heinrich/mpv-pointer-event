This is currently very speciffic to the needs this pointer-event, but I hope to make it more generally useable in the future.
It can currently replay the events from mpv from a log captured with `--msg-level=pointer_event=trace --log-file=log.txt` in the same way things would have happened during runtime.
Doesn't yet have any way of actually running test cases.