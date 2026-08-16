#!/usr/bin/env bash

set -euo pipefail

kernel_trace() {
    local release
    release=$(uname -r)

    printf '%s\n' '== Kernel release =='
    printf 'Full release: %s\n' "$release"

    # TODO: separate and print the numeric triplet and the optional suffix.
    # TODO: explain what the release can and cannot tell you about backports.
}

package_license() {
    local command_name=$1

    printf '\n== License for %s ==\n' "$command_name"

    # TODO: resolve the command path and identify its owning package.
    # TODO: query RPM metadata or the Debian copyright file for its license.
    printf '%s\n' 'INCOMPLETE: package and license lookup'
}

bin_trace() {
    printf '%s\n' '' '== The /bin path =='
    ls -ld /bin

    # TODO: inspect the link, when present, and explain the merged-/usr layout.
}

kernel_trace
package_license ls
package_license uname
bin_trace

printf '%s\n' '' 'INCOMPLETE: finish every TODO before considering the lab done.'
exit 1
