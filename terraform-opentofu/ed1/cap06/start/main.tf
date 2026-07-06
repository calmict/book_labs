# Chapter 6 — the first stone.
#
# Your first COMPLETE configuration, written by you, block by block. The
# README shows the code: type it here (no copy-paste — the fingers learn
# too), running tofu validate after every block. Order:
#
# 1. The terraform block — who translates: required_providers with the
#    docker provider (source kreuzwerker/docker, version ~> 3.0).
#
# 2. The provider block — how to talk to it: provider "docker" with an
#    empty body (empty = the default local Docker engine).
#
# 3. The resources — what must exist:
#    - a docker_image named "web": nginx:1.27-alpine, keep_locally true;
#    - a docker_container named "web": name cap06-web, image from the
#      resource above (a reference: chapter 4's edge), and a nested ports
#      block (internal 80, external 8087 — note: no equals sign, it is a
#      block, not an argument).
#
# 4. The output — what to expose: "url", value http://localhost:8087.
#
# An empty file is a valid configuration: validate passes even now.
