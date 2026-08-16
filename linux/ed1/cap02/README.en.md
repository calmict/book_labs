# Chapter 2 — Build a Tool That Does Not Exist

> Exercise for **Chapter 2 — The Unix Philosophy: Tools That Work Together** of the
> *Linux Manual* (Calm ICT series — [calmict.com](https://calmict.com)).

**Level:** Foundational

## Objectives

By the end of this lab you will be able to:

- turn an operational question into a sequence of small filters;
- connect awk, sort, uniq, and head in a reproducible pipeline;
- distinguish a concurrent pipeline from a plain sequence of commands;
- inspect intermediate and final results instead of trusting appearances.

## Prerequisites

- A Linux system with Bash, awk, sort, uniq, head, and diff.
- Terminal access from the repository root.
- No administrative privileges are required.

## Instructions

The start/requests-sample.txt file is a small HTTP request log. Build the tool that
answers this question: which paths produced the most 5xx responses?

1. Inspect the format and identify the fields containing the path and HTTP status:

       head start/requests-sample.txt

2. Extract only the paths of failed requests. Check this intermediate result
   before adding more commands:

       awk '$9 >= 500 && $9 < 600 {print $7}' start/requests-sample.txt

3. Compose the complete pipeline. Each command has one job: awk filters, the first
   sort groups equal lines, uniq counts them, the second sort orders the counts,
   and head limits the report:

       awk '$9 >= 500 && $9 < 600 {print $7}' start/requests-sample.txt | sort | uniq -c | sort -nr | head -5

4. Save the output as report.txt and describe in start/answers.md what enters and
   leaves each stage of the pipeline.

5. Verify that a pipe does not necessarily wait for the command on its left to
   finish. The producer writes one line, waits two seconds, and writes another:

       start/slow-producer.sh | awk '{ print "consumer:", $0; fflush() }'

   The consumer's first line must appear during the pause, before the producer's
   second line. By contrast, sort must read all input before it can guarantee a
   complete ordering. Record this distinction.

6. Run the automated solution and compare its check with your report:

       solution/run.sh

## Definition of "done"

- [ ] report.txt lists the 5xx paths in descending count order.
- [ ] You inspected at least one intermediate result before the final report.
- [ ] start/answers.md describes the data flowing through every pipe.
- [ ] You saw the consumer's first line before the two-second pause ended.
- [ ] You can explain why sort may delay output while still belonging to a concurrent pipeline.
- [ ] solution/run.sh completes all checks and leaves no temporary files behind.
