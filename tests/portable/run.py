#!/usr/bin/env python3
"""Compile selected, actual OpenDente logic with inert platform boundaries.

This is not a macOS build. Source extraction preserves decision branches and
command methods; only logging, Combine observation and platform collaborators
are replaced. --source-ref reads a pinned git revision for before/after checks.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source-ref", help="Read production sources from this git revision")
parser.add_argument("--swiftc", default="swiftc")
parser.add_argument("--output", type=Path, default=REPO / ".build/portable-regressions")
parser.add_argument("--generate-only", action="store_true")
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)

manifest = {
    "source_ref": args.source_ref or "working tree",
    "production_sha256": {},
    "extractions": [],
    "not_tested": ["SwiftUI/AppKit/Combine integration", "XPC and signing", "SMC hardware",
                   "full macOS application build", "the complete native XCTest suite"],
}


def read_source(name):
    if args.source_ref:
        value = subprocess.check_output(["git", "-C", str(REPO), "show",
                                         f"{args.source_ref}:{name}"], text=True)
    else:
        value = (REPO / name).read_text()
    manifest["production_sha256"][name] = hashlib.sha256(value.encode()).hexdigest()
    return value


def observation_and_logs(value):
    """Remove no decision-making or hardware-command code."""
    result = []
    for line in value.splitlines():
        if line.strip() == "import SwiftUI":
            continue
        if "private var cancellables = Set<AnyCancellable>()" in line:
            continue
        if re.match(r"\s*log\.(debug|info|notice|warning|error|fault)\(", line):
            if not line.rstrip().endswith(")"):
                raise ValueError("Refusing to silently transform multiline logging: " + line)
            result.append("        // Platform diagnostic logging omitted by portable harness.")
        else:
            result.append(line.replace("@Published ", ""))
    return "\n".join(result)


def member(source, name, *, kind="func", required=True):
    pattern = re.compile(r"^    (?:private |private\(set\) |nonisolated )*" + kind
                         + r" " + re.escape(name) + r"(?:\b|\()")
    lines = source.splitlines()
    class_start = next(i for i, line in enumerate(lines)
                       if line.startswith("final class ChargingManager:"))
    starts = [i for i, line in enumerate(lines) if i > class_start and pattern.match(line)]
    if not starts and not required:
        return ""
    if len(starts) != 1:
        raise ValueError(f"Expected one source member {kind} {name}; got {len(starts)}")
    start = starts[0]
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == "    }")
    value = observation_and_logs("\n".join(lines[start:end + 1]))
    manifest["extractions"].append({"member": name, "first_line": start + 1,
                                    "last_line": end + 1,
                                    "sha256": hashlib.sha256(value.encode()).hexdigest()})
    return value


settings = read_source("OpenDente/Models/AppSettings.swift")
battery = read_source("OpenDente/Models/BatteryState.swift")
constants = read_source("Shared/HelperConstants.swift")
manager = read_source("OpenDente/Services/ChargingManager.swift")

protocol_start = manager.index("protocol ChargingControl:")
protocol_end = manager.index("extension HelperClient:")
protocol = manager[protocol_start:protocol_end]
fields_start = manager.index("    @Published var mode:")
fields_end = manager.index("    private convenience init()")
fields = observation_and_logs(manager[fields_start:fields_end])
# The injected initializer is the only initializer beginning at this indentation
# without 'private'; retain it verbatim rather than recreating its assignments.
ctor_start = manager.index("    init(settings:")
ctor_end = manager.index("\n    }", ctor_start) + len("\n    }")
constructor = observation_and_logs(manager[ctor_start:ctor_end])
methods = []
for name in ["evaluateState", "verifyChargingInhibition", "updateSleepAssertion",
             "updateSystemChargeLimitConflict", "startTopUp", "cancelTopUp",
             "startDischarge", "stopDischarge", "pauseCharging", "inhibitCharging",
             "enableCharging", "forceDischarge", "updateMagSafeLED", "sendLEDColor",
             "resetToDefaults", "resetToDefaultsSync"]:
    methods.append(member(manager, name, required=name != "verifyChargingInhibition"))
for name in ["canControlCharging", "controlUnavailableReason"]:
    methods.append(member(manager, name, kind="var"))

personal_features = "enum ChargeProfile" in settings and "var topUpRequested" in manager
manifest["personal_features_present"] = personal_features
fixture = (HERE / "fixtures.swift").read_text()
tests = (HERE / "scenarios.swift").read_text()
source = "\n\n".join([
    "// Generated by tests/portable/run.py; do not edit. No privileged calls exist here.",
    "import Foundation\n#if os(Linux)\nimport Glibc\n#else\nimport Darwin\n#endif",
    fixture, protocol, battery, constants, observation_and_logs(settings),
    "@MainActor\nfinal class ChargingManager {", fields, constructor,
    *methods, "}", tests,
])
generated = args.output / "BatteryCarePortable.swift"
generated.write_text(source)
manifest["generated_sha256"] = hashlib.sha256(source.encode()).hexdigest()
(args.output / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
if args.generate_only:
    print(generated)
    sys.exit(0)

command = [args.swiftc, "-swift-version", "6", "-parse-as-library", "-module-cache-path",
           str(args.output / "module-cache"), str(generated), "-o", str(args.output / "regressions")]
if personal_features:
    command[1:1] = ["-D", "PERSONAL_FEATURES"]
compiled = subprocess.run(command, text=True, capture_output=True)
(args.output / "compiler.log").write_text(compiled.stdout + compiled.stderr)
if compiled.returncode:
    print(compiled.stdout + compiled.stderr, file=sys.stderr)
    sys.exit(compiled.returncode)
result = subprocess.run([str(args.output / "regressions")], text=True, capture_output=True)
(args.output / "results.jsonl").write_text(result.stdout)
(args.output / "stderr.log").write_text(result.stderr)
print(result.stdout, end="")
if result.stderr:
    print(result.stderr, file=sys.stderr)
sys.exit(result.returncode)
