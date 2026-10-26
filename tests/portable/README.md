# Portable charge-policy regressions

These tests compile **extracted production Swift**, not a rewritten state
machine. `run.py` takes the actual settings, battery model, manager properties,
injected initializer, decision methods and command methods from the working
tree. A manifest records source hashes and method line ranges.

The harness replaces platform logging, Combine observation and the SMC, XPC,
notification, battery-monitor and sleep-assertion boundaries with inert fixtures.
Helper replies normally succeed; two asynchronous scenarios inject an inhibition
failure and execute the real manager callback, including a positive control that
confirms the callback runs. These tests assess charge-policy decisions and
verification, not the privileged helper's own hardware recovery. Battery
temperature and time markers are controlled fixtures. The 1,944 settings combinations are checked
inside one scenario, not counted as separate test cases.

With Swift 6 available:

```sh
python3 tests/portable/run.py
```

The exit status is nonzero if compilation fails or any assertion fails.
Generated Swift, compiler diagnostics, JSON-lines results and extraction hashes
are written under `.build/portable-regressions/`.

The audited upstream revision can be used as a negative control:

```sh
python3 tests/portable/run.py \
  --source-ref 06c5a8199f5c0657374e667073b3aa6a75f50df8 \
  --output .build/portable-baseline
```

That run intentionally fails the existing thermal, resume-threshold and top-up
regressions. New profile/request-state checks are enabled only when those APIs
exist in the extracted revision. Common behavior scenarios stay identical.

This does **not** compile the complete macOS app, run its complete XCTest suite,
validate authentication or signing, exercise real power-management APIs, or
establish compatibility with any Mac. The corresponding native tests in
`OpenDenteTests/BatteryCareRegressionTests.swift` must also run on macOS.
