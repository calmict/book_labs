# Observations

## Pipe capacity

Record F_GETPIPE_SZ and the number of bytes written before EAGAIN. Explain why measuring is better than assuming a constant.

## Backpressure

Record whether the producer was blocked, how long it waited, and what action allowed it to continue.

## The while loop

Record both count values and explain where the first loop ran.

## Status 141

Record the overall pipeline status and both PIPESTATUS values. Explain 141 in terms of SIGPIPE and the consumer's early exit.

## Cleanup

Confirm that no producer or consumer process remains.
