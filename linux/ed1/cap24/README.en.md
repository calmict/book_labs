# Chapter 24 — The Command You Did Not Write

> Exercise for **Chapter 24 — The Shell: What Happens Before Execution** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- distinguish typed command text from the arguments received by a program;
- recognize the effects of word splitting and pathname expansion;
- protect file names and variable values with quotes;
- make a script independent of its current directory and interactive PATH.

## Prerequisites

- Bash on Linux.
- The env, cat, and date commands.
- No cron daemon: its minimal environment is simulated with env -i.

All tests operate inside the exercise directory, and the solution removes temporary data on exit.

## Instructions

1. Copy the answer template. Make start/print-args.sh executable and call it with plain arguments, spaces, variables, and wildcard characters:

       cp start/answers.md answers.md
       chmod +x start/print-args.sh
       start/print-args.sh one "two words" '*.log'

   The fake command prints its argument count and puts delimiters around each value. Compare single quotes, double quotes, and no quotes. Record what the program actually receives, not merely the text shown on the command line.

2. Create two .log files and repeat the command with *.log first unquoted and then quoted. Explain when the shell expands the pattern before starting the program.

3. Create a file named quarterly report.txt, assign its name to a variable, and reproduce the failure:

       file_name='quarterly report.txt'
       cat $file_name

   The shell passes two names to cat. Fix the command and verify the contents:

       cat "$file_name"

4. Inspect start/backup-report.sh. The report-helper command works in your interactive shell when its directory is on PATH:

       PATH="$PWD/start:$PATH" start/backup-report.sh /tmp/labcap24-report.txt

   Without installing a real crontab, simulate cron with an empty environment and a minimal PATH:

       env -i PATH=/usr/bin:/bin "$PWD/start/backup-report.sh" /tmp/labcap24-report.txt

   Record the error. Fix a copy of the script by finding its own directory and invoking report-helper through an absolute path. Do not depend on PWD or the session's PATH.

5. Test the fix in the same minimal environment, or run the complete demonstration:

       ./solution/run.sh

6. Remove answers.md, the test files, and /tmp/labcap24-report.txt.

## Definition of "done"

- [ ] You displayed the argument vector produced by quoting, variables, and pathname expansion.
- [ ] You reproduced the failure caused by a space in a file name and fixed it with quotes.
- [ ] The original script succeeds with the interactive PATH and fails under env -i.
- [ ] The fixed script succeeds under env -i by deriving a path from its own location.
- [ ] You completed answers.md and removed all temporary files.
