@main
struct RegressionRunner {
    @MainActor
    static func main() async {
        var failures = 0
        var total = 0
        func run(_ name: String, _ body: (Scenario) throws -> Void) {
            total += 1
            let scenario = Scenario()
            defer { scenario.clearDefaults() }
            var result = ["test": name, "status": "pass"]
            do { try body(scenario) }
            catch {
                failures += 1
                result["status"] = "fail"
                result["reason"] = String(describing: error)
            }
            let json = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            print(String(data: json, encoding: .utf8)!)
        }
        func runAsync(_ name: String, _ body: @MainActor (Scenario) async throws -> Void) async {
            total += 1
            let scenario = Scenario()
            defer { scenario.clearDefaults() }
            var result = ["test": name, "status": "pass"]
            do { try await body(scenario) }
            catch {
                failures += 1
                result["status"] = "fail"
                result["reason"] = String(describing: error)
            }
            let json = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            print(String(data: json, encoding: .utf8)!)
        }

        run("thermal_hot_path_retries_unconfirmed_inhibit") { s in
            s.evaluate(state(charging: true, temperature: 38))
            s.controller.calls = []
            s.manager.lastInhibitTime = Date().addingTimeInterval(-16)
            s.evaluate(state(charging: true, temperature: 38))
            try expect(s.manager.mode == .heatProtection, "Thermal pause must persist")
            try expect(s.controller.inhibitCount == 1, "Unconfirmed inhibit must be retried while hot")
        }
        run("thermal_cooldown_path_retries_unconfirmed_inhibit") { s in
            s.evaluate(state(charging: true, temperature: 38))
            s.controller.calls = []
            s.manager.lastInhibitTime = Date().addingTimeInterval(-16)
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-30)
            s.evaluate(state(charging: true, temperature: 30))
            try expect(s.manager.mode == .heatProtection, "Cooldown must hold the pause")
            try expect(s.controller.inhibitCount == 1, "Cooldown must still verify the inhibit")
        }
        run("thermal_retry_debounce_bounds_writes") { s in
            s.evaluate(state(charging: true, temperature: 38))
            s.controller.calls = []
            s.manager.lastInhibitTime = Date().addingTimeInterval(-5)
            s.evaluate(state(charging: true, temperature: 38))
            try expect(s.controller.inhibitCount == 0, "Do not retry inside the debounce window")
        }
        run("thermal_exhaustion_reports_once_and_stops_writes") { s in
            s.evaluate(state(charging: true, temperature: 38))
            s.controller.calls = []
            s.manager.inhibitRetryCount = 3
            s.manager.lastInhibitTime = Date().addingTimeInterval(-16)
            s.evaluate(state(charging: true, temperature: 38))
            s.evaluate(state(charging: true, temperature: 38))
            try expect(s.manager.didNotifyInhibitExhausted, "Failure feedback is reachable while hot")
            try expect(NotificationService.shared.sent.filter { $0 == .inhibitFailed }.count == 1,
                       "Report one failure per verification cycle")
            try expect(s.controller.inhibitCount == 0, "Stop writing after retry budget is exhausted")
        }
        run("thermal_hardware_confirmation_clears_pending_retry") { s in
            s.evaluate(state(charging: true, temperature: 38))
            s.manager.inhibitRetryCount = 2
            s.manager.lastInhibitTime = Date().addingTimeInterval(-3)
            s.evaluate(state(charging: false, temperature: 38))
            try expect(s.manager.inhibitRetryCount == 0, "Confirmed stop clears retry count")
            try expect(s.manager.lastInhibitTime == nil, "Confirmed stop ends verification cycle")
        }
        run("paused_positive_control_still_retries") { s in
            s.evaluate(state(90, charging: true))
            s.controller.calls = []
            s.manager.lastInhibitTime = Date().addingTimeInterval(-16)
            s.evaluate(state(90, charging: true))
            try expect(s.controller.inhibitCount == 1, "Ordinary ceiling verification must still work")
        }
        run("minimum_limit_maximum_sailing_range_resumes_at_nine_percent") { s in
            s.settings.chargeLimit = 20
            s.settings.sailingRange = 25
            s.evaluate(state(20))
            s.controller.calls = []
            s.evaluate(state(9))
            try expect(s.manager.mode == .charging, "Battery must resume charging before empty")
            try expect(s.controller.calls.contains(.enable), "Resume must request charging")
        }
        run("all_allowed_sailing_thresholds_remain_positive_and_below_limit") { s in
            for limit in 20...100 {
                s.settings.chargeLimit = limit
                for range in 2...25 {
                    s.settings.sailingRange = range
                    try expect(s.settings.sailingLowerBound >= 10, "Resume threshold below 10%")
                    try expect(s.settings.sailingLowerBound < limit, "Resume threshold must be below ceiling")
                }
            }
        }
        run("top_up_resumes_after_thermal_cooldown_preserving_ceiling") { s in
            s.manager.startTopUp()
            s.evaluate(state(85, charging: true, temperature: 38))
            try expect(s.manager.mode == .heatProtection, "Heat must take priority")
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-30)
            s.evaluate(state(85, temperature: 30))
            try expect(s.manager.mode == .heatProtection, "Do not bypass five-minute cooldown")
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-301)
            s.controller.calls = []
            s.evaluate(state(85, temperature: 30))
            try expect(s.manager.mode == .topUp, "Temporary full-charge request must survive thermal pause")
            try expect(s.controller.calls.contains(.enable), "Resume top-up charging after cooldown")
            try expect(s.settings.chargeLimit == 80, "Temporary override must not change saved ceiling")
        }
        run("unplugging_restores_ceiling_on_reconnect") { s in
            s.manager.startTopUp()
            s.evaluate(state(100))
            try expect(s.manager.mode == .topUp, "Top-up remains until unplugged or cancelled")
            s.evaluate(state(100, plugged: false))
            try expect(s.manager.mode == .onBattery, "Unplugging ends top-up")
            s.evaluate(state(99))
            try expect(s.manager.mode == .paused, "Normal ceiling is restored after reconnect")
        }
        run("cancel_during_thermal_pause_does_not_resume_top_up") { s in
            s.manager.startTopUp()
            s.evaluate(state(85, temperature: 38))
            s.manager.cancelTopUp()
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-301)
            s.evaluate(state(85, temperature: 30))
            try expect(s.manager.mode == .paused, "Cancelled top-up must not return after cooling")
        }
        run("reset_restores_ceiling_in_next_evaluation") { s in
            s.manager.startTopUp()
            s.manager.resetToDefaults()
            try expect(s.manager.mode == .idle, "Reset returns to idle")
            s.evaluate(state(95))
            try expect(s.manager.mode == .paused, "Reset clears any full-charge override")
        }
        run("starting_top_up_while_hot_never_briefly_enables_charging") { s in
            s.battery.batteryState = state(85, temperature: 38)
            s.manager.startTopUp()
            try expect(s.manager.mode == .heatProtection, "Start action must respect the latest hot reading")
            try expect(!s.controller.calls.contains(.enable), "Do not briefly enable charging before thermal check")
        }
        run("starting_top_up_during_cooldown_preserves_thermal_pause") { s in
            s.evaluate(state(75, temperature: 38))
            let cooldown = Date().addingTimeInterval(-30)
            s.manager.heatProtectionTimer = cooldown
            s.battery.batteryState = state(75, temperature: 30)
            s.controller.calls = []
            s.manager.startTopUp()
            try expect(s.manager.mode == .heatProtection, "Start action cannot bypass cooldown")
            try expect(s.manager.heatProtectionTimer == cooldown, "Retain the current cooldown window")
            try expect(!s.controller.calls.contains(.enable), "Do not enable charging during cooldown")
        }
        run("missing_temperature_cannot_release_thermal_pause") { s in
            s.manager.startTopUp()
            s.evaluate(state(85, temperature: 38))
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-301)
            s.controller.calls = []
            s.evaluate(state(85, temperature: nil))
            try expect(s.manager.mode == .heatProtection, "Missing sensor data is not evidence of cooling")
            try expect(!s.controller.calls.contains(.enable), "Do not resume with missing temperature")
        }
        run("nonfinite_temperature_cannot_release_thermal_pause") { s in
            s.evaluate(state(75, temperature: 38))
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-301)
            s.controller.calls = []
            for temperature in [Double.nan, Double.infinity, -Double.infinity] {
                s.evaluate(state(75, temperature: temperature))
                try expect(s.manager.mode == .heatProtection, "Nonfinite readings cannot prove cooling")
            }
            try expect(!s.controller.calls.contains(.enable), "Do not resume with nonfinite temperature")
        }
        run("unvalidated_helper_receives_no_magsafe_led_commands") { s in
            s.manager.isHelperInstalled = false
            s.manager.helperVersion = HelperConstants.helperVersion
            s.settings.controlMagSafeLED = true
            s.evaluate(state(90))
            try expect(s.controller.calls.isEmpty, "LED writes must obey the helper validation gate")
        }
        await runAsync("failed_inhibit_preserves_thermal_cooldown_and_pending_top_up") { s in
            s.manager.startTopUp()
            s.controller.failInhibit = true
            s.evaluate(state(85, charging: true, temperature: 38))
            for _ in 0..<10 { await Task.yield() }
            try expect(s.manager.mode == .heatProtection, "Inhibit failure must retain the thermal state")
            s.controller.failInhibit = false
            s.controller.calls = []
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-30)
            s.evaluate(state(85, temperature: 30))
            try expect(s.manager.mode == .heatProtection, "Failure must not shorten cooldown")
            try expect(!s.controller.calls.contains(.enable), "Do not resume top-up before cooldown expires")
            s.manager.heatProtectionTimer = Date().addingTimeInterval(-301)
            s.evaluate(state(85, temperature: 30))
            try expect(s.manager.mode == .topUp, "Pending top-up resumes once cooldown is complete")
        }
        await runAsync("nonthermal_inhibit_failure_positive_control_reaches_idle") { s in
            s.settings.heatProtectionEnabled = false
            s.controller.failInhibit = true
            s.evaluate(state(90))
            for _ in 0..<10 { await Task.yield() }
            try expect(s.manager.mode == .idle, "Asynchronous failure handler must actually run")
        }

        #if PERSONAL_FEATURES
        run("top_up_intent_visible_during_heat_pause") { s in
            s.manager.startTopUp()
            s.evaluate(state(85, temperature: 38))
            try expect(s.manager.topUpRequested, "UI must retain the cancellable pending top-up")
        }
        run("cancel_top_up_clears_intent_while_retaining_heat_protection") { s in
            s.manager.startTopUp()
            s.evaluate(state(85, temperature: 38))
            s.manager.cancelTopUp()
            try expect(!s.manager.topUpRequested, "Cancel clears request during heat protection")
            try expect(s.manager.mode == .heatProtection, "Cancel must not bypass thermal pause")
        }
        run("unplug_during_thermal_pause_clears_top_up_intent") { s in
            s.manager.startTopUp()
            s.evaluate(state(85, temperature: 38))
            s.evaluate(state(85, plugged: false, temperature: 38))
            try expect(!s.manager.topUpRequested, "Unplugging clears pending full-charge request")
        }
        run("reset_clears_top_up_intent") { s in
            s.manager.startTopUp()
            s.manager.resetToDefaults()
            try expect(!s.manager.topUpRequested, "Reset must clear pending top-up")
        }
        run("termination_reset_clears_top_up_intent") { s in
            s.manager.startTopUp()
            s.manager.resetToDefaultsSync()
            try expect(!s.manager.topUpRequested, "Termination reset must clear pending top-up")
        }
        run("unavailable_helper_cannot_start_top_up") { s in
            s.manager.isHelperInstalled = false
            s.manager.startTopUp()
            try expect(!s.manager.topUpRequested, "Unavailable control must not create an override")
            try expect(s.controller.calls.isEmpty, "No hardware commands without helper")
        }
        run("starting_discharge_clears_top_up_intent") { s in
            s.manager.startTopUp()
            s.manager.startDischarge()
            try expect(!s.manager.topUpRequested, "Explicit discharge replaces the pending top-up")
            try expect(s.manager.mode == .discharging, "Discharge command remains active")
        }
        run("profiles_configure_documented_limits_and_natural_sailing") { s in
            let profiles: [(ChargeProfile, Int, Int)] = [(.desk, 70, 60), (.everyday, 80, 70), (.travel, 90, 80)]
            for (profile, limit, resume) in profiles {
                s.settings.automaticDischarge = true
                s.settings.heatProtectionEnabled = false
                s.settings.sailingModeEnabled = false
                s.settings.apply(profile: profile)
                try expect(s.settings.chargeLimit == limit, "Profile ceiling mismatch")
                try expect(s.settings.sailingLowerBound == resume, "Profile resume threshold mismatch")
                try expect(profile.chargeLimit == limit && profile.resumeAt == resume, "Profile labels match behavior")
                try expect(s.settings.heatProtectionEnabled && s.settings.sailingModeEnabled, "Profile protections enabled")
                try expect(!s.settings.automaticDischarge, "Profiles must not start forced discharge")
                try expect(s.settings.selectedProfile == profile, "Applied profile is identified")
            }
        }
        run("custom_ceiling_is_identified_as_custom") { s in
            s.settings.apply(profile: .everyday)
            s.settings.chargeLimit = 83
            try expect(s.settings.selectedProfile == nil, "Custom settings must not display preset selected")
        }
        run("custom_range_is_identified_as_custom") { s in
            s.settings.apply(profile: .everyday)
            s.settings.sailingRange = 5
            try expect(s.settings.selectedProfile == nil, "Range changes must clear selected preset")
        }
        run("lowering_ceiling_with_profile_does_not_force_discharge") { s in
            s.settings.apply(profile: .desk)
            s.evaluate(state(95))
            try expect(s.manager.mode == .paused, "Above-ceiling battery waits naturally")
            try expect(!s.controller.calls.contains(.forceDischarge(true)), "Profile must not create forced cycles")
        }
        #endif

        print("{\"summary\":{\"tests\":\(total),\"passed\":\(total - failures),\"failed\":\(failures)}}")
        if failures > 0 { exit(1) }
    }
}
