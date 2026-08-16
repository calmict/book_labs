#!/usr/bin/env bash

set -euo pipefail

kernel_trace() {
    local release base suffix
    local major minor patch

    release=$(uname -r)

    printf '%s\n' '== Kernel release =='
    printf 'Full release: %s\n' "$release"

    if [[ $release =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)([-+].*)?$ ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        patch=${BASH_REMATCH[3]}
        suffix=${BASH_REMATCH[4]:-(none)}
        base=$major.$minor.$patch

        printf 'Base version: %s (major=%s, minor=%s, patch=%s)\n' \
            "$base" "$major" "$minor" "$patch"
        printf 'Distribution/build suffix: %s\n' "$suffix"
    else
        printf '%s\n' 'This release does not use the expected numeric triplet; inspect it as a distribution-specific string.'
    fi

    printf '%s\n' \
        'Meaning: the numeric components identify the kernel release line; the suffix identifies a distribution build or variant.' \
        'Caution: an older-looking base version may still contain newer fixes backported by its distributor, so the numbers alone are not a security or feature inventory.'
}

dpkg_owner() {
    local path=$1 command_name=$2 result

    result=$(dpkg-query -S "$path" 2>/dev/null | head -n 1 || true)
    if [[ -z $result ]]; then
        result=$(dpkg-query -S "/bin/$command_name" 2>/dev/null | head -n 1 || true)
    fi
    if [[ -z $result ]]; then
        result=$(dpkg-query -S "/usr/bin/$command_name" 2>/dev/null | head -n 1 || true)
    fi

    [[ -n $result ]] || return 1
    printf '%s\n' "${result%%:*}"
}

package_license() {
    local command_name=$1 path package license source_file

    printf '\n== License for %s ==\n' "$command_name"

    path=$(type -P "$command_name")
    printf 'Executable: %s\n' "$path"

    if command -v rpm >/dev/null 2>&1 && rpm -qf "$path" >/dev/null 2>&1; then
        package=$(rpm -qf --qf '%{NAME}\n' "$path" | head -n 1)
        license=$(rpm -q --qf '%{LICENSE}\n' "$package")
        printf 'Package: %s\n' "$package"
        printf 'Declared license: %s\n' "$license"
        printf '%s\n' 'Source: RPM package database, LICENSE metadata field'
        return
    fi

    if command -v dpkg-query >/dev/null 2>&1; then
        package=$(dpkg_owner "$path" "$command_name") || {
            printf '%s\n' 'Unable to find the owning package in the dpkg database.' >&2
            return 1
        }
        package=${package%%,*}
        source_file=/usr/share/doc/$package/copyright
        [[ -r $source_file ]] || {
            printf 'Package copyright file is not readable: %s\n' "$source_file" >&2
            return 1
        }
        license=$(awk '/^License:/ { sub(/^License:[[:space:]]*/, ""); print; exit }' "$source_file")
        [[ -n $license ]] || {
            printf 'No machine-readable License field found in %s\n' "$source_file" >&2
            return 1
        }
        printf 'Package: %s\n' "$package"
        printf 'Declared license: %s\n' "$license"
        printf 'Source: %s, first License field\n' "$source_file"
        return
    fi

    printf '%s\n' 'Neither RPM nor dpkg could identify the installed command package.' >&2
    return 1
}

bin_trace() {
    local target resolved

    printf '%s\n' '' '== The /bin path =='
    ls -ld /bin

    if [[ -L /bin ]]; then
        target=$(readlink /bin)
        resolved=$(readlink -f /bin)
        printf 'Link target: %s\n' "$target"
        printf 'Resolved path: %s\n' "$resolved"
        printf '%s\n' 'Observed layout: merged-/usr; /bin and /usr/bin name the same directory.'
    else
        printf '%s\n' 'Observed layout: /bin is a separate directory on this system.'
    fi

    printf '%s\n' \
        'Historical reason: essential programs lived in /bin so they were available early in boot, before a separate /usr filesystem could be mounted.' \
        'Modern reason: early boot is handled without that split, so merging into /usr/bin removes duplicate locations and makes packaging and path handling simpler.'
}

kernel_trace
package_license ls
package_license uname
bin_trace
