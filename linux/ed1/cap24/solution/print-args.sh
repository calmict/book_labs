#!/usr/bin/env bash
printf 'argc=%s\n' "$#"
argument_number=0
for argument_value in "$@"; do
    printf 'argv[%s]=<%s>\n' "$argument_number" "$argument_value"
    argument_number=$((argument_number + 1))
done
