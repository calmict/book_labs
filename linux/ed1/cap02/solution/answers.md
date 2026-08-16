# Chapter 2 — Answers (model solution)

## Intermediate output

    /api/orders
    /checkout
    /api/health
    /api/orders
    /checkout
    /api/orders
    /api/health

## Final report

          3 /api/orders
          2 /checkout
          2 /api/health

## Data flowing through the pipeline

- awk emits one path for each request whose status is between 500 and 599.
- The first sort emits the same paths in lexical order, placing equal values next
  to one another.
- uniq -c emits one count and one path for every group.
- sort -nr emits those records in descending numeric order.
- head emits at most the first five records.

## Streaming observation

The consumer prints first record before the producer's two-second pause ends. The
shell starts both sides of a pipeline without waiting for the producer to finish,
and the pipe carries bytes as they become available. A stage may still buffer its
input: sort cannot know which record belongs first until it has seen the end of the
stream, so it normally produces its ordered output only after the producer closes
the pipe.
