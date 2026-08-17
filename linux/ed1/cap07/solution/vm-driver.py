#!/usr/bin/env python3
import base64
import os
import re
import sys
import time

import pexpect


ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
ANSI_POSITION = re.compile(r"\x1b\[[0-9]*;[0-9]*[Hf]")


class Tee:
    def __init__(self, *streams):
        self.streams = streams

    def write(self, data):
        for stream in self.streams:
            stream.write(data)
            stream.flush()

    def flush(self):
        for stream in self.streams:
            stream.flush()


def stop_emulator(child):
    if not child.isalive():
        return
    child.send("\x01x")
    try:
        child.expect(pexpect.EOF, timeout=10)
    except pexpect.TIMEOUT:
        child.terminate(force=True)


def reach_grub_editor(child):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        child.send("\x1b")
        try:
            child.expect(r"GRUB version 2\.06", timeout=0.7)
            break
        except pexpect.TIMEOUT:
            continue
    else:
        raise RuntimeError("GRUB version 2.06 was not observed on the serial console")

    remaining = max(0.1, deadline - time.monotonic())
    try:
        child.expect(r"Press enter to boot the selected OS", timeout=remaining)
        child.expect(r"to edit the commands", timeout=5)
    except pexpect.TIMEOUT as exc:
        raise RuntimeError("GRUB menu did not become interactive") from exc

    child.send("e")
    try:
        child.expect(r"Minimum Emacs-like screen editing is supported", timeout=10)
    except pexpect.TIMEOUT as exc:
        raise RuntimeError("GRUB menu-entry editor did not open") from exc
    editor_output = child.before + child.after

    # The editor draws its whole screen (help text, then every command line)
    # in one burst. Chaining child.expect() calls for "linux " and then
    # "initrd " each consumes the stream only up to the end of its own
    # match, discarding whatever comes after "initrd " before the next
    # expect() starts reading — the initramfs path itself gets thrown away.
    # Drain instead: keep reading whatever has arrived until the screen goes
    # quiet for a full cycle, so nothing after the last matched keyword is
    # silently consumed and lost.
    quiet_deadline = time.monotonic() + 3
    while time.monotonic() < quiet_deadline:
        try:
            editor_output += child.read_nonblocking(size=4096, timeout=0.3)
            quiet_deadline = time.monotonic() + 1
        except pexpect.TIMEOUT:
            continue
        except pexpect.EOF:
            break

    clean = ANSI.sub("", editor_output)
    if not re.search(r"(?:linux|linuxefi)\s+", clean) or not re.search(r"(?:initrd|initrdefi)\s+", clean):
        raise RuntimeError("GRUB editor did not display the linux and initrd commands")

    return editor_output


def editor_commands(editor_text):
    positioned = ANSI_POSITION.sub(" ", editor_text)
    flattened = " ".join(ANSI.sub("", positioned).split())
    match = re.search(
        r"(?:^|\s)((?:linux|linuxefi)\s+.*?)(?=\s+(?:initrd|initrdefi)\s+)",
        flattened,
    )
    initrd_match = re.search(r"(?:^|\s)((?:initrd|initrdefi)\s+.*?)(?=\s+Press Ctrl-x|$)", flattened)
    if not match or not initrd_match:
        raise RuntimeError("the linux and initrd commands could not be parsed safely")
    linux_command = match.group(1).strip()
    initrd_command = initrd_match.group(1).strip()
    if "/vmlinuz" not in linux_command or "/initramfs" not in initrd_command:
        raise RuntimeError("the expected kernel and initramfs paths were not found in the GRUB entry")
    return linux_command, initrd_command


def command_rows(editor_text):
    positioned = ANSI_POSITION.sub("\n", editor_text)
    rows = ANSI.sub("", positioned).replace("\r", "\n").splitlines()
    commands = []
    pattern = re.compile(
        r"^\s*\|?\s*(setparams|load_video|set|insmod|search|if|else|fi|echo|linux(?:efi)?|initrd(?:efi)?)\b"
    )
    for row in rows:
        match = pattern.search(row)
        if match:
            commands.append(match.group(1))
    return commands


def linux_down_count(editor_text):
    configured = os.environ.get("LAB_GRUB_LINUX_DOWN")
    if configured is not None:
        count = int(configured)
        if count < 0:
            raise RuntimeError("LAB_GRUB_LINUX_DOWN must be zero or greater")
        return count
    for index, command in enumerate(command_rows(editor_text)):
        if command in ("linux", "linuxefi"):
            return index
    return 3


def edit_linux_line(child, extra, editor_text, remove_quiet=False):
    linux_command, _ = editor_commands(editor_text)
    child.send("\x1b[B" * linux_down_count(editor_text))
    child.send("\x05")

    if remove_quiet:
        words = linux_command.split()
        if "quiet" in words:
            replacement = " ".join(word for word in words if word != "quiet")
            child.send("\x01")
            child.send("\x0b")
            child.send(replacement)

    child.send(" console=ttyS0,115200n8 " + extra)
    time.sleep(1)
    child.send("\x18")


def healthy_initrd_command(initrd_command):
    words = initrd_command.split()
    replaced = False
    for index, word in enumerate(words):
        if "/initramfs-" in word and ".img" in word and not word.endswith(".labcap07-good"):
            words[index] = word + ".labcap07-good"
            replaced = True
            break
    if not replaced:
        raise RuntimeError("the standard initramfs path could not be replaced with the healthy copy")
    return " ".join(words)


def edit_repair_entry(child, editor_text):
    _, initrd_command = editor_commands(editor_text)
    rows = command_rows(editor_text)
    configured = os.environ.get("LAB_GRUB_INITRD_DOWN")
    if configured is None:
        initrd_index = next(
            (index for index, command in enumerate(rows) if command in ("initrd", "initrdefi")),
            None,
        )
    else:
        initrd_index = int(configured)
        if initrd_index < 0:
            raise RuntimeError("LAB_GRUB_INITRD_DOWN must be zero or greater")
    if initrd_index is None:
        raise RuntimeError("the initrd row was not found in the GRUB editor")

    # This editor's help text only documents Tab, Ctrl-x/F10, Ctrl-c/F2 and
    # ESC: Ctrl-K is not kill-line here. Sending it after Ctrl-A leaves the
    # old text untouched and the new text gets inserted character by
    # character in front of it, producing a single garbled path. Go to the
    # true end of the line instead (Ctrl-E, already proven reliable) and
    # erase exactly the known length of the existing command with
    # backspaces before typing the replacement.
    child.send("\x1b[B" * initrd_index)
    child.send("\x05")
    child.send("\x7f" * len(initrd_command))
    child.send(healthy_initrd_command(initrd_command))
    child.send("\x1b[A")
    child.send("\x05")
    child.send(" console=ttyS0,115200n8 init=/bin/bash labcap07=repair")
    time.sleep(1)
    child.send("\x18")


def expect_pid1_shell(child):
    child.expect([r"bash-[0-9.]+#", r"sh-[0-9.]+#"], timeout=150)


def run_guest_script(child, script, marker, timeout):
    wrapped = "set -eu\ntrap 'rc=$?; echo " + marker + "=$rc' EXIT\n" + script
    payload = base64.b64encode(wrapped.encode("utf-8")).decode("ascii")
    child.sendline("printf %s " + payload + " | base64 -d | /bin/bash")
    child.expect(re.escape(marker) + r"=([0-9]+)", timeout=timeout)
    status = int(child.match.group(1))
    if status != 0:
        raise RuntimeError(marker + " returned status " + str(status))


def run_dracut_shell_script(child, script, success_text, timeout):
    # The dracut emergency shell is a minimal busybox environment: it has
    # neither base64 nor a guarantee of /bin/bash, so run_guest_script's
    # encode-and-pipe transport does not work here. Type each line at the
    # prompt instead, exactly as an interactive user would.
    #
    # Only wait for the success text, and only that. The terminal echoes
    # each typed line back before it is executed, so any failure string
    # that also appears as literal source inside the script (e.g. inside
    # an "if ...; then echo '...'; fi" block) would already be sitting in
    # the buffer as echoed input by the time expect() runs — matching it
    # would report a failure whether or not that branch actually ran.
    for line in script.strip("\n").splitlines():
        if line.strip():
            child.sendline(line)
    try:
        child.expect(re.escape(success_text), timeout=timeout)
    except pexpect.TIMEOUT as exc:
        raise RuntimeError(
            "dracut shell script did not reach: " + success_text
        ) from exc


BREAK_SCRIPT = r'''
mount -o remount,rw /
if findmnt --fstab --target /boot >/dev/null 2>&1; then
    mountpoint -q /boot || mount /boot
fi
ROOT_SOURCE=$(findmnt -n -o SOURCE /)
echo "Guest root source: $ROOT_SOURCE"
test "$ROOT_SOURCE" = /dev/vda3
KVER=$(uname -r)
IMAGE=/boot/initramfs-$KVER.img
GOOD=$IMAGE.labcap07-good
test -f "$IMAGE"
lsinitrd "$IMAGE" | grep -q '/virtio_blk\.ko'
cp -p -- "$IMAGE" "$GOOD"
lsinitrd "$GOOD" | grep -q '/virtio_blk\.ko'
DRACUT_HELP=$(dracut --help 2>&1 || :)
printf '%s\n' "$DRACUT_HELP"
if printf '%s\n' "$DRACUT_HELP" | grep -q -- '--omit-drivers'; then
    OMIT_DRIVER_OPTION=--omit-drivers
elif printf '%s\n' "$DRACUT_HELP" | grep -Eq -- '(^|[[:space:],])-o([[:space:],]+).*omit.*drivers'; then
    OMIT_DRIVER_OPTION=-o
else
    echo "No option explicitly described as omitting kernel drivers" >&2
    exit 20
fi
echo "Selected driver omission option: $OMIT_DRIVER_OPTION"
dracut --force "$OMIT_DRIVER_OPTION" virtio_blk "$IMAGE" "$KVER"
if lsinitrd "$IMAGE" | grep -q '/virtio_blk\.ko'; then
    echo "virtio_blk is still present in the altered initramfs" >&2
    exit 21
fi
echo "Altered initramfs check: virtio_blk absent"
sync
'''


BROKEN_SCRIPT = r'''
echo "Emergency kernel modules:"
cat /proc/modules
if grep -q '^virtio_blk ' /proc/modules; then
    echo "virtio_blk unexpectedly loaded" >&2
    exit 30
fi
if test -e /dev/vda; then
    echo "/dev/vda unexpectedly exists" >&2
    exit 31
fi
echo "Broken boot check: virtio_blk absent and /dev/vda missing"
'''


REPAIR_SCRIPT = r'''
mount -o remount,rw /
if findmnt --fstab --target /boot >/dev/null 2>&1; then
    mountpoint -q /boot || mount /boot
fi
ROOT_SOURCE=$(findmnt -n -o SOURCE /)
echo "Repair root source: $ROOT_SOURCE"
test "$ROOT_SOURCE" = /dev/vda3
KVER=$(uname -r)
IMAGE=/boot/initramfs-$KVER.img
GOOD=$IMAGE.labcap07-good
test -f "$GOOD"
dracut --force "$IMAGE" "$KVER"
lsinitrd "$IMAGE" | grep -q '/virtio_blk\.ko'
echo "Repaired initramfs check: virtio_blk present"
sync
'''


def clean_text(path):
    with open(path, encoding="utf-8", errors="replace") as stream:
        return ANSI.sub("", stream.read()).replace("\r", "")


def verify_stage(stage, text):
    if stage == "break":
        required = (
            "Guest root source: /dev/vda3",
            "Selected driver omission option:",
            "Altered initramfs check: virtio_blk absent",
            "LAB_CAP07_BREAK=0",
        )
    elif stage == "broken":
        required = (
            "Broken boot check: virtio_blk absent and /dev/vda missing",
        )
        failure_evidence = [
            line.strip()
            for line in text.splitlines()
            if re.search(r"warning:|emergency mode", line, re.I)
        ]
        if not failure_evidence:
            raise RuntimeError("the transcript contains no dracut warning or emergency-mode message")
        print("Observed dracut failure evidence: " + failure_evidence[-1])
    elif stage == "repair":
        required = (
            "Repair root source: /dev/vda3",
            "Repaired initramfs check: virtio_blk present",
            "LAB_CAP07_REPAIR=0",
        )
    else:
        required = ("login:", "labcap07=verify")
        if not re.search(r"virtio_blk .*\[vda\]", text):
            raise RuntimeError("the kernel message associating virtio_blk with vda is missing")

    missing = [item for item in required if item not in text]
    if missing:
        raise RuntimeError("missing transcript evidence: " + ", ".join(missing))


def main():
    if len(sys.argv) < 6:
        raise SystemExit("usage: vm-driver.py STAGE TRANSCRIPT PIDFILE QEMU [ARGS ...]")

    stage, transcript, pidfile, qemu_bin = sys.argv[1:5]
    if stage not in ("break", "broken", "repair", "verify"):
        raise RuntimeError("unknown stage: " + stage)
    qemu_args = sys.argv[5:] + ["-pidfile", pidfile]
    command = [
        "timeout",
        "--foreground",
        "--signal=TERM",
        "--kill-after=10s",
        "180s",
        qemu_bin,
        *qemu_args,
    ]

    with open(transcript, "w", encoding="utf-8") as log:
        child = pexpect.spawn(command[0], command[1:], encoding="utf-8", codec_errors="replace", timeout=180)
        child.logfile_read = Tee(sys.stdout, log)
        try:
            editor_text = reach_grub_editor(child)
            if stage == "break":
                edit_linux_line(child, "init=/bin/bash labcap07=break", editor_text)
                expect_pid1_shell(child)
                run_guest_script(child, BREAK_SCRIPT, "LAB_CAP07_BREAK", 140)
            elif stage == "broken":
                # Without a short rd.retry, dracut's default initqueue
                # retry window is long enough to outlast the outer 180s
                # timeout before it ever drops to its emergency shell.
                edit_linux_line(child, "rd.retry=3 labcap07=broken", editor_text)
                child.expect(r"dracut:/#", timeout=60)
                run_dracut_shell_script(
                    child,
                    BROKEN_SCRIPT,
                    "Broken boot check: virtio_blk absent and /dev/vda missing",
                    15,
                )
            elif stage == "repair":
                edit_repair_entry(child, editor_text)
                expect_pid1_shell(child)
                run_guest_script(child, REPAIR_SCRIPT, "LAB_CAP07_REPAIR", 140)
            else:
                edit_linux_line(child, "labcap07=verify", editor_text, remove_quiet=True)
                child.expect(r"login:", timeout=150)
            time.sleep(1)
            stop_emulator(child)
        finally:
            stop_emulator(child)

    verify_stage(stage, clean_text(transcript))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("Live VM check failed: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
