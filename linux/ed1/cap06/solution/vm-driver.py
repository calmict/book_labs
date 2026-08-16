#!/usr/bin/env python3
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


def reach_grub(child):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        child.send("\x1b")
        try:
            child.expect(r"GRUB version", timeout=0.7)
            break
        except pexpect.TIMEOUT:
            continue
    else:
        raise RuntimeError("GRUB menu was not observed on the serial console")

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

    for pattern in (r"(?:linux|linuxefi)\s+", r"(?:initrd|initrdefi)\s+"):
        if re.search(pattern, ANSI.sub("", editor_output)):
            continue
        try:
            child.expect(pattern, timeout=5)
        except pexpect.TIMEOUT as exc:
            raise RuntimeError("GRUB editor did not display the linux and initrd commands") from exc
        editor_output += child.before + child.after

    return editor_output


def editor_linux_command(editor_text):
    positioned = ANSI_POSITION.sub(" ", editor_text)
    flattened = " ".join(ANSI.sub("", positioned).split())
    match = re.search(
        r"(?:^|\s)((?:linux|linuxefi)\s+.*?)(?=\s+(?:initrd|initrdefi)\s+)",
        flattened,
    )
    if not match:
        return None
    command = match.group(1).strip()
    if "/vmlinuz" not in command:
        return None
    return command


def editor_linux_down(editor_text):
    positioned = ANSI_POSITION.sub("\n", editor_text)
    rows = ANSI.sub("", positioned).replace("\r", "\n").splitlines()
    commands = []
    command_pattern = re.compile(
        r"^\s*\|?\s*(setparams|load_video|set|insmod|search|if|else|fi|echo|linux(?:efi)?|initrd(?:efi)?)\b"
    )
    for row in rows:
        match = command_pattern.search(row)
        if match:
            commands.append(match.group(1))
    for index, command in enumerate(commands):
        if command in ("linux", "linuxefi"):
            return index
    return None


def edit_linux_line(child, extra, editor_text):
    configured_down = os.environ.get("LAB_GRUB_LINUX_DOWN")
    if configured_down is None:
        down_count = editor_linux_down(editor_text)
        if down_count is None:
            down_count = 3
    else:
        down_count = int(configured_down)
    if down_count < 0:
        raise RuntimeError("LAB_GRUB_LINUX_DOWN must be zero or greater")

    linux_command = editor_linux_command(editor_text)
    clean_editor_text = ANSI.sub("", ANSI_POSITION.sub(" ", editor_text))
    if linux_command is None and re.search(r"(?:^|\s)quiet(?:\s|$)", clean_editor_text):
        raise RuntimeError("quiet was visible, but the linux command could not be parsed safely")

    child.send("\x1b[B" * down_count)
    child.send("\x05")

    if linux_command is not None:
        words = linux_command.split()
        if "quiet" in words:
            replacement = " ".join(word for word in words if word != "quiet")
            child.send("\x01")
            child.send("\x0b")
            child.send(replacement)

    child.send(" console=ttyS0,115200n8 " + extra)
    time.sleep(1)
    child.send("\x18")


def clean_text(path):
    with open(path, encoding="utf-8", errors="replace") as stream:
        return ANSI.sub("", stream.read()).replace("\r", "")


def command_line_for_marker(text, marker):
    candidates = []
    for line in text.splitlines():
        if marker in line and ("command line" in line.lower() or "Command line" in line):
            candidates.append(line)
    if not candidates:
        raise RuntimeError("kernel command line containing the stage marker was not captured")
    line = candidates[-1]
    if re.search(r"(?:^|\s)quiet(?:\s|$)", line):
        raise RuntimeError("quiet is still present on the captured kernel command line")
    return line


def main():
    if len(sys.argv) < 6:
        raise SystemExit("usage: vm-driver.py STAGE TRANSCRIPT PIDFILE QEMU [ARGS ...]")

    stage, transcript, pidfile, qemu_bin = sys.argv[1:5]
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
            editor_text = reach_grub(child)
            if stage == "verbose":
                marker = "labcap06=verbose"
                edit_linux_line(child, marker, editor_text)
                child.expect(r"login:", timeout=150)
            elif stage == "rescue":
                marker = "labcap06=rescue"
                edit_linux_line(child, "systemd.unit=rescue.target " + marker, editor_text)
                child.expect(
                    [
                        r"rescue mode",
                        r"Give root password for maintenance",
                        r"Press Enter for maintenance",
                    ],
                    timeout=150,
                )
            elif stage == "init-shell":
                marker = "labcap06=init-shell"
                edit_linux_line(child, "init=/bin/bash " + marker, editor_text)
                child.expect([r"bash-[0-9.]+#", r"sh-[0-9.]+#"], timeout=150)
                child.sendline("echo LAB_CAP06_INIT_SHELL; cat /proc/cmdline; ps -p 1 -o pid=,comm=,args=")
                child.expect(r"LAB_CAP06_INIT_SHELL", timeout=10)
                child.expect(r"\s*1\s+bash\s+/bin/bash", timeout=10)
            else:
                raise RuntimeError("unknown stage: " + stage)
            time.sleep(1)
            stop_emulator(child)
        finally:
            stop_emulator(child)

    text = clean_text(transcript)
    line = command_line_for_marker(text, marker)
    print("Verified guest kernel command line: " + line.strip())
    if stage == "verbose":
        if "Linux version" not in text:
            raise RuntimeError("kernel initialization messages were not captured")
    elif stage == "rescue":
        if not re.search(r"rescue mode|root password for maintenance|Enter for maintenance", text, re.I):
            raise RuntimeError("rescue-mode evidence is missing")
    else:
        if "LAB_CAP06_INIT_SHELL" not in text or not re.search(r"\s1\s+bash\s+/bin/bash", text):
            raise RuntimeError("/bin/bash as PID 1 was not verified")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("Live VM check failed: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
