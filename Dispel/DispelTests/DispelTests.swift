//
//  DispelTests.swift
//  DispelTests
//

import Testing
@testable import Dispel

struct DispelTests {
    @Test func delaySettingsClampToZero() {
        let manager = EventTapManager()
        defer { manager.stop() }

        manager.delayMs = -1
        manager.activationDelayMs = -5

        #expect(manager.delayMs == 0)
        #expect(manager.activationDelayMs == 0)
    }

    @Test func changingSettingsDoesNotArmSuppression() {
        let manager = EventTapManager()
        defer { manager.stop() }

        manager.isEnabled = true
        manager.delayMs = 300
        manager.activationDelayMs = 30

        #expect(manager.debugHasSuppressionWindow == false)
    }

    @Test func disablingClearsSuppressionWindow() {
        let manager = EventTapManager()
        defer { manager.stop() }

        manager.delayMs = 200
        manager.activationDelayMs = 20
        manager.isEnabled = true
        manager.debugArmSuppressionForTests()
        #expect(manager.debugHasSuppressionWindow == true)

        manager.isEnabled = false

        #expect(manager.debugHasSuppressionWindow == false)
    }
}
