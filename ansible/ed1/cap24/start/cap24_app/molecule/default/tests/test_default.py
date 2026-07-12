# TODO 3 (24.6): write the verifications with Testinfra.
#   Testinfra gives you a 'host' fixture that inspects the REAL system, not
#   Ansible's own report. Assert that:
#     - /etc/cap24app is a directory with mode 0o755
#     - /etc/cap24app/app.conf exists, mode 0o644, and its content contains
#       "workers = 4"
#   Useful lenses: host.file(path), host.user(name), host.package(name),
#   host.service(name). A file object has .exists, .is_directory, .mode,
#   .user, .group, .content_string.

testinfra_hosts = ["all"]

# def test_config_directory(host):
#     ...

# def test_config_file(host):
#     ...
