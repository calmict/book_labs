# Expected observations

## Arguments

The shell removes syntactic quotes before execution. Double quotes keep a variable expansion as one argument, while an unquoted expansion can undergo word splitting and pathname expansion. Single quotes suppress expansion. An unquoted wildcard is replaced with every matching path; a quoted wildcard reaches the program as a literal asterisk.

## File name with a space

Expanding $file_name without quotes produces two words, so cat attempts to open quarterly and report.txt separately. Expanding "$file_name" produces exactly one argument and addresses the intended file.

## Minimal environment

The original script depends on an interactive PATH that contains its helper's directory. env -i removes that inherited setting, so the shell reports report-helper as not found. Cron commonly supplies a small environment and may also use a different working directory.

## Robust script

The corrected script derives its directory from BASH_SOURCE and invokes the helper through that absolute path. It therefore works with PATH=/usr/bin:/bin and from an unrelated working directory.

## Cleanup

The demonstration script removes its scratch directory with an EXIT trap.
