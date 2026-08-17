# Observations

## Arguments

Record the arguments received with unquoted, single-quoted, and double-quoted input. Include one variable and one wildcard pattern.

## File name with a space

Record the failing command and error, then explain why double quotes fix it.

## Minimal environment

Record the result of the original script with the interactive PATH and with env -i. Explain which assumption failed.

## Robust script

Show how the corrected script locates its helper and record the successful minimal-environment test.

## Cleanup

Confirm that you removed the generated reports and scratch files.
