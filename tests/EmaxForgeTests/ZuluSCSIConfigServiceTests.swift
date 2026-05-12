import XCTest
import Foundation
@testable import EmaxForge

/// Tests for ZuluSCSIConfigService — config generation (pure string building),
/// ZuluConfig/DevicePreset defaults, and file-based read/write/exists round-trip.
final class ZuluSCSIConfigServiceTests: XCTestCase {

    // MARK: - ZuluConfig defaults

    func testZuluConfigDefaultEnableMACIsFalse() {
        let cfg = ZuluSCSIConfigService.ZuluConfig()
        XCTAssertFalse(cfg.enableMAC)
    }

    func testZuluConfigDefaultMaxSyncSpeedIs10() {
        let cfg = ZuluSCSIConfigService.ZuluConfig()
        XCTAssertEqual(cfg.maxSyncSpeed, 10)
    }

    func testZuluConfigDefaultSelectionDelayIs255() {
        let cfg = ZuluSCSIConfigService.ZuluConfig()
        XCTAssertEqual(cfg.selectionDelay, 255)
    }

    func testZuluConfigDefaultStartupDelayIsZero() {
        let cfg = ZuluSCSIConfigService.ZuluConfig()
        XCTAssertEqual(cfg.startupDelay, 0)
    }

    func testZuluConfigDefaultDevicePresetsIsEmpty() {
        let cfg = ZuluSCSIConfigService.ZuluConfig()
        XCTAssertTrue(cfg.devicePresets.isEmpty)
    }

    // MARK: - DevicePreset defaults

    func testDevicePresetDefaultVendorIsEmu() {
        let dp = ZuluSCSIConfigService.ZuluConfig.DevicePreset()
        XCTAssertEqual(dp.vendor, "E-mu")
    }

    func testDevicePresetDefaultProductIsEMAXIIHD() {
        let dp = ZuluSCSIConfigService.ZuluConfig.DevicePreset()
        XCTAssertEqual(dp.product, "EMAX II HD")
    }

    func testDevicePresetDefaultSectorSizeIs512() {
        let dp = ZuluSCSIConfigService.ZuluConfig.DevicePreset()
        XCTAssertEqual(dp.sectorSize, 512)
    }

    // MARK: - generateConfig: content checks

    func testGenerateConfigContainsSCSISection() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertTrue(output.contains("[SCSI]"), "Config must contain [SCSI] section")
    }

    func testGenerateConfigContainsEnableParity() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertTrue(output.contains("EnableParity = 1"),
                      "Config must enable SCSI parity")
    }

    func testGenerateConfigContainsSCSI1Section() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertTrue(output.contains("[SCSI1]"),
                      "Config must contain [SCSI1] section for EMAX II boot")
    }

    func testGenerateConfigContainsBlockSize512() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertTrue(output.contains("BlockSize = 512"),
                      "Config must set BlockSize = 512 (required for EMAX II)")
    }

    func testGenerateConfigContainsDeviceDisplayName() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertTrue(output.contains(DeviceType.emaxII.displayName),
                      "Config comment should mention the device name")
    }

    func testGenerateConfigIsNonEmpty() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertFalse(output.isEmpty)
    }

    func testGenerateConfigContainsNewlines() {
        let svc = ZuluSCSIConfigService()
        let output = svc.generateConfig(for: .emaxII, images: [])
        XCTAssertTrue(output.contains("\n"), "Config must have multiple lines")
    }

    // MARK: - writeConfig / readConfig / configExists round-trip

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZuluConfigTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func testConfigDoesNotExistOnFreshDir() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let svc = ZuluSCSIConfigService()
        XCTAssertFalse(svc.configExists(on: dir),
                       "Config should not exist on a fresh directory")
    }

    func testWriteConfigCreatesFile() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let svc = ZuluSCSIConfigService()

        try svc.writeConfig(content: "[SCSI]\nEnableParity = 1", to: dir)

        XCTAssertTrue(svc.configExists(on: dir), "Config file should exist after write")
    }

    func testReadConfigReturnsWrittenContent() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let svc = ZuluSCSIConfigService()
        let content = "[SCSI]\nEnableParity = 1\n[SCSI1]\nBlockSize = 512"

        try svc.writeConfig(content: content, to: dir)
        let read = svc.readConfig(from: dir)

        XCTAssertEqual(read, content)
    }

    func testReadConfigReturnsNilForMissingFile() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let svc = ZuluSCSIConfigService()
        XCTAssertNil(svc.readConfig(from: dir))
    }

    func testGenerateAndWriteAndReadRoundTrip() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let svc = ZuluSCSIConfigService()

        let content = svc.generateConfig(for: .emaxII, images: [])
        try svc.writeConfig(content: content, to: dir)
        let read = svc.readConfig(from: dir)

        XCTAssertEqual(read, content, "Round-trip should preserve generated config exactly")
    }

    func testConfigExistsReturnsTrueAfterWrite() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let svc = ZuluSCSIConfigService()

        try svc.writeConfig(content: "test", to: dir)

        XCTAssertTrue(svc.configExists(on: dir))
    }
}
