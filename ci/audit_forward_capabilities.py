#!/usr/bin/env python3
"""Source-only fail-closed forward proxy policy audit; not native execution."""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOLD = "if: " + chr(36) + "{{ false }}"
PATHS = ("src/connect_admission.atto", "src/network_admission.atto",
         "src/route_policy.atto", "src/proxy_wire.atto",
         ".github/workflows/native-contracts.yml",
         ".github/workflows/attolang-source-policy.yml")

def load() -> dict[str, str]:
    out = {}
    for name in PATHS:
        path = ROOT / name
        if not path.is_file() or path.is_symlink():
            raise AssertionError("missing/symlinked source: " + name)
        out[name] = path.read_text(encoding="utf-8")
    return out

def code(source: str) -> str:
    return "\n".join(line.split("//", 1)[0] for line in source.splitlines())

def validate(raw: dict[str, str]) -> None:
    plan, net, route, wire = (code(raw[p]) for p in PATHS[:4])
    native, policy = (raw[p] for p in PATHS[4:])
    fn = re.search(r"pub fnc may_connect\(borrow Intent intent\): bool\s*\{([^{}]*)\}", plan)
    if not fn or re.sub(r"\s+", "", fn.group(1)) != "returnfalse;":
        raise AssertionError("symbolic intent gained socket authority")
    if not re.search(r"return Ok\(new Intent\([^;]*,\s*false\)\);", plan, re.S):
        raise AssertionError("symbolic intent authorized a socket")
    for key in ("proxy_wire.connect(request_line, host_header)",
                "proxy_wire.configured_connect(", 'actor.abi != "connect-policy-v1"',
                "actor.network_capable", "actor.epoch != snapshot.epoch"):
        if key not in plan: raise AssertionError("missing CONNECT binding gate: " + key)
    if "pub define class ForwardPermit as" not in net or "pub define class ReversePermit as" not in net:
        raise AssertionError("forward permit class missing")
    forward_permit = net.split("pub define class ForwardPermit as", 1)[1].split("pub define class ReversePermit as", 1)[0]
    if "private constructor(" not in forward_permit:
        raise AssertionError("forward permit constructor broadened")
    if "pub fnc authorize_connect(" not in net or "pub fnc authorize_reverse(" not in net:
        raise AssertionError("per-direction admission entrypoints missing")
    forward_dial = net.split("pub fnc authorize_connect(", 1)[1].split("pub fnc authorize_reverse(", 1)[0]
    for key in ("!endpoint.dns_pinned", "!endpoint.public_address",
                'endpoint.port != "443"'):
        if key not in forward_dial:
            raise AssertionError("missing forward pre-dial guard: " + key)
    if "request.ticket.epoch != snapshot.epoch" not in net:
        raise AssertionError("shared request epoch gate removed")
    if 'port != "443"' not in route or 'method != "CONNECT"' not in route:
        raise AssertionError("configured CONNECT port/method broadened")
    if 'host_header != target' not in wire:
        raise AssertionError("CONNECT Host equality removed")
    for path in PATHS[:4]:
        for primitive in ("network.connect(", "network.connect_async(",
                          "http.request(", "http.fetch(", "socket.open("):
            if primitive in code(raw[path]):
                raise AssertionError("network primitive in pure module: " + path)
    if HOLD not in native or "runs-on: [self-hosted" not in native:
        raise AssertionError("trusted native runner security hold removed")
    if "permissions: {}" not in policy or "persist-credentials: false" not in policy:
        raise AssertionError("source-only token permissions broadened")

def self_test(raw: dict[str, str]) -> None:
    cases = (
        ("allow_socket", 0, "return false;", "return true;"),
        ("forge_intent", 0, "actor.name, actor.target, false));", "actor.name, actor.target, true));"),
        ("bypass_role", 0, 'actor.abi != "connect-policy-v1"', "false"),
        ("bypass_network", 0, "actor.network_capable", "false"),
        ("skip_pin", 1, "!endpoint.dns_pinned || !endpoint.public_address ||", "false || !endpoint.public_address ||"),
        ("skip_public", 1, "!endpoint.public_address", "false"),
        ("port_80", 2, 'port != "443"', 'port != "80"'),
        ("ignore_host", 3, "host_header != target", "false"),
        ("unlock_runner", 4, HOLD, "if: true"),
        ("persist_checkout_token", 5, "persist-credentials: false", "persist-credentials: true"),
    )
    validate(raw)
    print("PASS forward boundary: baseline")
    for label, index, before, after in cases:
        path = PATHS[index]
        if raw[path].count(before) != 1:
            raise AssertionError("mutator not grounded: " + label)
        altered = dict(raw)
        altered[path] = altered[path].replace(before, after)
        try:
            validate(altered)
        except AssertionError:
            print("PASS forward mutation rejected: " + label)
        else:
            raise AssertionError("mutant escaped forward gate: " + label)
    print("FORWARD_PURE_BOUNDARY_MUTATIONS_PASS=11/11; NOT NATIVE")

if __name__ == "__main__":
    try:
        files = load()
        if sys.argv[1:] == ["--self-test"]:
            self_test(files)
        elif not sys.argv[1:]:
            validate(files)
            print("FORWARD_PURE_BOUNDARY_AUDIT_PASS; NOT NATIVE")
        else:
            raise AssertionError("usage: audit_forward_capabilities.py [--self-test]")
    except (AssertionError, OSError) as exc:
        print("FAIL forward boundary: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
