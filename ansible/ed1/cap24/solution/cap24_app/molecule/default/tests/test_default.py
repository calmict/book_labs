testinfra_hosts = ["all"]


def test_config_directory(host):
    d = host.file("/etc/cap24app")
    assert d.is_directory
    assert d.mode == 0o755


def test_config_file(host):
    f = host.file("/etc/cap24app/app.conf")
    assert f.exists
    assert f.mode == 0o644
    assert "workers = 4" in f.content_string
