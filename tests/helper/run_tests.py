#!/usr/bin/env python3
"""Compile actual controller and extracted delegate with explicit OS boundary fakes.

SWIFTC may select a compiler. Signing enforcement needs native macOS validation;
the lifecycle extraction deliberately excludes that platform-only implementation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path)
parser.add_argument("--suite", choices=["all", "hardware", "lifecycle", "watchdog", "native"], default="all")
args = parser.parse_args()
out = args.output or Path(tempfile.mkdtemp(prefix="opendente-helper-tests-"))
out.mkdir(parents=True, exist_ok=True)
compiler = os.environ.get("SWIFTC", "swiftc")
flags = [compiler, "-swift-version", "6", "-strict-concurrency=minimal", "-module-cache-path", str(out / "module-cache")]
# Compile the complete, unmodified helper on macOS, including Security and XPC.
# This never executes the helper or opens the SMC.
if args.suite == "native" and sys.platform != "darwin":
    parser.error("The native helper check requires macOS")
if sys.platform == "darwin" and args.suite in ("all", "native"):
    native_sources = sorted((ROOT / "OpenDenteHelper").glob("*.swift"))
    native_sources += sorted((ROOT / "Shared").glob("*.swift"))
    native_sources += [ROOT / "OpenDente/Services/SMCService.swift", ROOT / "OpenDente/Models/BatteryState.swift"]
    result = subprocess.run(flags + ["-typecheck", "-module-name", "OpenDenteHelper"]
                            + [str(path) for path in native_sources], capture_output=True, text=True)
    (out / "native-typecheck.log").write_text(result.stdout + result.stderr)
    if result.returncode:
        print(result.stdout + result.stderr, file=sys.stderr)
        sys.exit(result.returncode)
    print("PASS complete native helper typecheck; Security/XPC included, no helper executed.")
    if args.suite == "native":
        sys.exit(0)

controller = ROOT / "OpenDenteHelper/ChargingHardwareController.swift"
model = ROOT / "OpenDente/Models/BatteryState.swift"
source = ROOT / "OpenDenteHelper/HelperDelegate.swift"
text = source.read_text()
start = text.index("    private static func makeCallerRequirement() -> String? {")
end = text.index("    /// Called under lock", start)
text = text[:start] + '    private static func makeCallerRequirement() -> String? { "TEST ONLY" }\n\n' + text[end:]
text = text.replace("final class HelperDelegate: NSObject, NSXPCListenerDelegate, HelperProtocol", "final class HelperDelegate")
text = "\n".join(line for line in text.splitlines()
                 if not line.startswith(("import os.log", "import Security", "import CryptoKit", "private let log ="))
                 and "log." not in line and "super.init()" not in line)
extracted = out / "HelperDelegate.lifecycle-extracted.swift"
extracted.write_text(text + "\n")
watchdog_source = ROOT / "OpenDenteHelper/Watchdog.swift"
watchdog_text = "\n".join(line for line in watchdog_source.read_text().splitlines()
                          if not line.startswith(("import os.log", "private let log =")) and "log." not in line)
watchdog_text = watchdog_text[:watchdog_text.rindex("}")] + "    func runCheckForTesting() { queue.sync { check() } }\n}\n"
watchdog_extracted = out / "Watchdog.extracted.swift"
watchdog_extracted.write_text(watchdog_text)
(out / "manifest.json").write_text(json.dumps({
    "source": str(source.relative_to(ROOT)),
    "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "extracted_sha256": hashlib.sha256(extracted.read_bytes()).hexdigest(),
    "watchdog_source_sha256": hashlib.sha256(watchdog_source.read_bytes()).hexdigest(),
    "watchdog_extracted_sha256": hashlib.sha256(watchdog_extracted.read_bytes()).hexdigest(),
    "excluded": ["Apple signature requirement construction", "os.log", "NSObject superclass"],
    "faked_boundaries": ["NSXPCConnection/Listener/Interface", "SMCService", "HelperState", "Watchdog"],
    "not_tested": ["native signature enforcement", "IOKit", "filesystem ownership/persistence", "real battery behavior"]
}, indent=2) + "\n")
for name, files in [
    ("hardware", [model, controller, ROOT / "tests/helper/HardwareRecoveryTests.swift"]),
    ("lifecycle", [ROOT / "Shared/MagSafeLEDSession.swift", ROOT / "Shared/NativeLimitSession.swift", model, controller, ROOT / "Shared/HelperConstants.swift", extracted, ROOT / "tests/helper/SessionLifecycleTests.swift"]),
    ("watchdog", [model, controller, ROOT / "Shared/HelperConstants.swift", watchdog_extracted, ROOT / "tests/helper/WatchdogRecoveryTests.swift"])
]:
    if args.suite not in ("all", name):
        continue
    binary = out / name
    subprocess.run(flags + [str(file) for file in files] + ["-o", str(binary)], check=True)
    result = subprocess.run([str(binary)], check=True, capture_output=True, text=True)
    (out / f"{name}.log").write_text(result.stdout + result.stderr)
    print(result.stdout, end="")
print(f"Logs and extraction manifest: {out}")
