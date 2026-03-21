
==============================================
  EmaxForge v0.5 Beta - Test Suite
  2026-03-19 06:31:22
==============================================

📦 Running Swift XCTest suite...
[0/1] Planning build
[1/1] Compiling plugin GenerateManual
[2/2] Compiling plugin GenerateDoccReference
Building for debugging...
[2/6] Write swift-version--58304C5D6DBC2206.txt
Build complete! (1.51s)
Test Suite 'All tests' started at 2026-03-19 06:31:24.713.
Test Suite 'EmulotionPackageTests.xctest' started at 2026-03-19 06:31:24.713.
Test Suite 'BankImportTests' started at 2026-03-19 06:31:24.713.
Test Case '-[EmaxForgeTests.BankImportTests testBankNameMaxLength]' started.
Test Case '-[EmaxForgeTests.BankImportTests testBankNameMaxLength]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testBankNameNullTerminated]' started.
Test Case '-[EmaxForgeTests.BankImportTests testBankNameNullTerminated]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testCatalogHolds32Entries]' started.
Test Case '-[EmaxForgeTests.BankImportTests testCatalogHolds32Entries]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testClusterSizes]' started.
Test Case '-[EmaxForgeTests.BankImportTests testClusterSizes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testEB2MagicBytes]' started.
Test Case '-[EmaxForgeTests.BankImportTests testEB2MagicBytes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testFATBuildChain]' started.
Test Case '-[EmaxForgeTests.BankImportTests testFATBuildChain]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testFATEndOfChainValue]' started.
Test Case '-[EmaxForgeTests.BankImportTests testFATEndOfChainValue]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testFATFreeClusterValue]' started.
Test Case '-[EmaxForgeTests.BankImportTests testFATFreeClusterValue]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testFirstBankSlotOffset]' started.
Test Case '-[EmaxForgeTests.BankImportTests testFirstBankSlotOffset]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testLastBankSlotOffset]' started.
Test Case '-[EmaxForgeTests.BankImportTests testLastBankSlotOffset]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testOSEntryIsAtSlot0]' started.
Test Case '-[EmaxForgeTests.BankImportTests testOSEntryIsAtSlot0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BankImportTests testSyntheticBankData]' started.
Test Case '-[EmaxForgeTests.BankImportTests testSyntheticBankData]' passed (0.000 seconds).
Test Suite 'BankImportTests' passed at 2026-03-19 06:31:24.715.
	 Executed 12 tests, with 0 failures (0 unexpected) in 0.001 (0.002) seconds
Test Suite 'BootDiskTests' started at 2026-03-19 06:31:24.715.
Test Case '-[EmaxForgeTests.BootDiskTests testBootSignatureFormat]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testBootSignatureFormat]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testBootSignatureValidation]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testBootSignatureValidation]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testClusterSizeForDiskSize]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testClusterSizeForDiskSize]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testFATEntry0]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testFATEntry0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testFATEntry1NonZeroForBootDisk]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testFATEntry1NonZeroForBootDisk]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testInvalidBootSignature]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testInvalidBootSignature]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testMultiImageFilenames]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testMultiImageFilenames]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testSCSIID1FilenameFormat]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testSCSIID1FilenameFormat]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testSCSIIDFilenameFormat]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testSCSIIDFilenameFormat]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testValidDiskSizes]' started.
Test Case '-[EmaxForgeTests.BootDiskTests testValidDiskSizes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.BootDiskTests testVerifyBootDiskIfExists]' started.
/Users/senioradvisor/clawd/EmaxForge/Tests/EmaxForgeTests/BootDiskTests.swift:148: -[EmaxForgeTests.BootDiskTests testVerifyBootDiskIfExists] : Test skipped - No test boot disk found at /var/folders/80/yt06bzzj2r3_5d9gvr6g67mc0000gn/T/EmaxForgeTests/TEST_HD00.hda
Test Case '-[EmaxForgeTests.BootDiskTests testVerifyBootDiskIfExists]' skipped (0.001 seconds).
Test Suite 'BootDiskTests' passed at 2026-03-19 06:31:24.718.
	 Executed 11 tests, with 1 test skipped and 0 failures (0 unexpected) in 0.003 (0.003) seconds
Test Suite 'DiskParserTests' started at 2026-03-19 06:31:24.718.
Test Case '-[EmaxForgeTests.DiskParserTests testDSKExtensionRecognised]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testDSKExtensionRecognised]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testExtensionLowercased]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testExtensionLowercased]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testFD00ParsesAsScsiID0]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testFD00ParsesAsScsiID0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testFD10ParsesAsScsiID1Index0]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testFD10ParsesAsScsiID1Index0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testFloppyZuluSCSINameFormat]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testFloppyZuluSCSINameFormat]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testHD10ParsesAsScsiID1Index0]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testHD10ParsesAsScsiID1Index0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testHD11ParsesAsScsiID1Index1]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testHD11ParsesAsScsiID1Index1]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testHD1_0_MyDiskHasLabel]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testHD1_0_MyDiskHasLabel]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testHD1_0ParsesScsiID1Index0]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testHD1_0ParsesScsiID1Index0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testHD20ParsesAsScsiID2Index0]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testHD20ParsesAsScsiID2Index0]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testHFEExtensionRecognised]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testHFEExtensionRecognised]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testNoPrefixMatchYieldsNilScsiID]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testNoPrefixMatchYieldsNilScsiID]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testSingleCharStemDoesNotCrash]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testSingleCharStemDoesNotCrash]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.DiskParserTests testZuluSCSINameFormat]' started.
Test Case '-[EmaxForgeTests.DiskParserTests testZuluSCSINameFormat]' passed (0.000 seconds).
Test Suite 'DiskParserTests' passed at 2026-03-19 06:31:24.719.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'FloppyTests' started at 2026-03-19 06:31:24.719.
Test Case '-[EmaxForgeTests.FloppyTests testAll800KBytesAreZeroForBlankFloppy]' started.
Test Case '-[EmaxForgeTests.FloppyTests testAll800KBytesAreZeroForBlankFloppy]' passed (0.004 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testCreateBlankFloppyFile]' started.
Test Case '-[EmaxForgeTests.FloppyTests testCreateBlankFloppyFile]' passed (0.001 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testDetectDoubleDensity800K]' started.
Test Case '-[EmaxForgeTests.FloppyTests testDetectDoubleDensity800K]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testDetectDoubleDensityWithTolerance]' started.
Test Case '-[EmaxForgeTests.FloppyTests testDetectDoubleDensityWithTolerance]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testDetectHighDensity1440K]' started.
Test Case '-[EmaxForgeTests.FloppyTests testDetectHighDensity1440K]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testDetectSingleDensity180K]' started.
Test Case '-[EmaxForgeTests.FloppyTests testDetectSingleDensity180K]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testDoubleDensityBytes]' started.
Test Case '-[EmaxForgeTests.FloppyTests testDoubleDensityBytes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testDSKIsFloppy]' started.
Test Case '-[EmaxForgeTests.FloppyTests testDSKIsFloppy]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testFDParsedAsFloppyImage]' started.
Test Case '-[EmaxForgeTests.FloppyTests testFDParsedAsFloppyImage]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testFDParsedIndex]' started.
Test Case '-[EmaxForgeTests.FloppyTests testFDParsedIndex]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testFloppyExtensions]' started.
Test Case '-[EmaxForgeTests.FloppyTests testFloppyExtensions]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testFloppyPrefixIsFD]' started.
Test Case '-[EmaxForgeTests.FloppyTests testFloppyPrefixIsFD]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testHDIsNotFloppy]' started.
Test Case '-[EmaxForgeTests.FloppyTests testHDIsNotFloppy]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testHDPrefixIsHD]' started.
Test Case '-[EmaxForgeTests.FloppyTests testHDPrefixIsHD]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testHFEIsFloppy]' started.
Test Case '-[EmaxForgeTests.FloppyTests testHFEIsFloppy]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testHFEMagicBytes]' started.
Test Case '-[EmaxForgeTests.FloppyTests testHFEMagicBytes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testHighDensityBytes]' started.
Test Case '-[EmaxForgeTests.FloppyTests testHighDensityBytes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testSingleDensityBytes]' started.
Test Case '-[EmaxForgeTests.FloppyTests testSingleDensityBytes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.FloppyTests testUnrecognisedSizeReturnsNil]' started.
Test Case '-[EmaxForgeTests.FloppyTests testUnrecognisedSizeReturnsNil]' passed (0.000 seconds).
Test Suite 'FloppyTests' passed at 2026-03-19 06:31:24.725.
	 Executed 19 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds
Test Suite 'ImageCreatorTests' started at 2026-03-19 06:31:24.725.
Test Case '-[EmaxForgeTests.ImageCreatorTests testAllFiveSizesCreateCorrectly]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testAllFiveSizesCreateCorrectly]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testBootSignatureConstants]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testBootSignatureConstants]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testBootSignatureDetectionInvalid]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testBootSignatureDetectionInvalid]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testBootSignatureDetectionValid]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testBootSignatureDetectionValid]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testCatalogEntrySize]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testCatalogEntrySize]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testCatalogOffset]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testCatalogOffset]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testCreateSyntheticValidDisk]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testCreateSyntheticValidDisk]' passed (0.066 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testDiskSizes]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testDiskSizes]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testFATEndOfChainMarker]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testFATEndOfChainMarker]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testFATEntry0Value]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testFATEntry0Value]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testSCSIFilenameScsiID1]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testSCSIFilenameScsiID1]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testSCSIFilenameZeroPadded]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testSCSIFilenameZeroPadded]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testSCSIFilenameZuluFormat]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testSCSIFilenameZuluFormat]' passed (0.000 seconds).
Test Case '-[EmaxForgeTests.ImageCreatorTests testTemplateFilesExist]' started.
Test Case '-[EmaxForgeTests.ImageCreatorTests testTemplateFilesExist]' passed (0.001 seconds).
Test Suite 'ImageCreatorTests' passed at 2026-03-19 06:31:24.795.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.069 (0.070) seconds
Test Suite 'IntegrationTests' started at 2026-03-19 06:31:24.795.
Test Case '-[EmaxForgeTests.IntegrationTests testBootDiskCreationPerformance]' started.
/Users/senioradvisor/clawd/EmaxForge/Tests/EmaxForgeTests/IntegrationTests.swift:107: Test Case '-[EmaxForgeTests.IntegrationTests testBootDiskCreationPerformance]' measured [Time, seconds] average: 0.000, relative standard deviation: 133.889%, values: [0.000122, 0.000019, 0.000012, 0.000010, 0.000010, 0.000010, 0.000009, 0.000034, 0.000013, 0.000010], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , polarity: prefers smaller, maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
Test Case '-[EmaxForgeTests.IntegrationTests testBootDiskCreationPerformance]' passed (0.445 seconds).
Test Case '-[EmaxForgeTests.IntegrationTests testDesktopBootDiskIfExists]' started.
Test Case '-[EmaxForgeTests.IntegrationTests testDesktopBootDiskIfExists]' passed (0.046 seconds).
Test Case '-[EmaxForgeTests.IntegrationTests testZuluSCSIConfigIfExists]' started.
Test Case '-[EmaxForgeTests.IntegrationTests testZuluSCSIConfigIfExists]' passed (0.000 seconds).
Test Suite 'IntegrationTests' passed at 2026-03-19 06:31:25.286.
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.491 (0.491) seconds
Test Suite 'EmulotionPackageTests.xctest' passed at 2026-03-19 06:31:25.286.
	 Executed 73 tests, with 1 test skipped and 0 failures (0 unexpected) in 0.570 (0.573) seconds
Test Suite 'All tests' passed at 2026-03-19 06:31:25.286.
	 Executed 73 tests, with 1 test skipped and 0 failures (0 unexpected) in 0.570 (0.573) seconds
✅ Performance test completed
✅ Testing: HD10.hda
  ✓ Size: 238 MB
  ✓ Boot signature: 0x78 0x82
  ✓ FAT entry 0: 0x8000
  ✓ FAT entry 1: 0x7FFF
  ⚠️  OS catalog entry not found (might be blank disk)
✅ All integration tests passed for HD10.hda
✅ Testing: zuluscsi.ini
  ✓ [SCSI1] section found
  ✓ HD10.hda reference found
✅ ZuluSCSI config validation passed
◇ Test run started.
↳ Testing Library Version: 1501
↳ Target Platform: arm64e-apple-macos14.0
✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.
✅ Swift tests: PASSED

🐍 Running CLI E2E tests...
[1m============================= test session starts ==============================[0m
platform darwin -- Python 3.14.2, pytest-9.0.2, pluggy-1.6.0 -- /Users/senioradvisor/clawd/EmaxForge/agent-harness/venv/bin/python3.14
cachedir: .pytest_cache
rootdir: /Users/senioradvisor/clawd/EmaxForge/agent-harness
[1mcollecting ... [0mcollected 35 items

tests/test_e2e_full.py::TestCreateBootDisk::test_boot_disk_fat_entry_0 [32mPASSED[0m[32m [  2%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_boot_disk_per_size_signatures [32mPASSED[0m[32m [  5%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_boot_disk_zuluscsi_name [32mPASSED[0m[32m [  8%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_create_239mb_boot_disk [32mPASSED[0m[32m [ 11%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_create_481mb_boot_disk [32mPASSED[0m[32m [ 14%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_create_633mb_boot_disk [32mPASSED[0m[32m [ 17%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_create_962mb_boot_disk [32mPASSED[0m[32m [ 20%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_create_96mb_boot_disk [32mPASSED[0m[32m [ 22%][0m
tests/test_e2e_full.py::TestCreateBootDisk::test_invalid_size_rejected [32mPASSED[0m[32m [ 25%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_180k_single_density_geometry [32mPASSED[0m[32m [ 28%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_all_raw_floppy_sizes [32mPASSED[0m[32m [ 31%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_floppy_json_fields [32mPASSED[0m[32m [ 34%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_hfe_classified_as_floppy [32mPASSED[0m[32m [ 37%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_hfe_magic_bytes [32mPASSED[0m[32m  [ 40%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_hfe_roundtrip_conversion [32mPASSED[0m[32m [ 42%][0m
tests/test_e2e_full.py::TestFloppyWorkflow::test_list_images_classifies_types [32mPASSED[0m[32m [ 45%][0m
tests/test_e2e_full.py::TestMultiDiskSetup::test_create_three_disk_setup [32mPASSED[0m[32m [ 48%][0m
tests/test_e2e_full.py::TestBankOperations::test_create_all_templates [32mPASSED[0m[32m [ 51%][0m
tests/test_e2e_full.py::TestBankOperations::test_export_bank_roundtrip [32mPASSED[0m[32m [ 54%][0m
tests/test_e2e_full.py::TestBankOperations::test_import_bank_and_list [32mPASSED[0m[32m [ 57%][0m
tests/test_e2e_full.py::TestBankOperations::test_list_templates [32mPASSED[0m[32m   [ 60%][0m
tests/test_e2e_full.py::TestCatalogAndFAT::test_analyze_fat_on_boot_disk [32mPASSED[0m[32m [ 62%][0m
tests/test_e2e_full.py::TestCatalogAndFAT::test_catalog_summary_on_boot_disk [32mPASSED[0m[32m [ 65%][0m
tests/test_e2e_full.py::TestCatalogAndFAT::test_list_catalog_with_os [32mPASSED[0m[32m [ 68%][0m
tests/test_e2e_full.py::TestCatalogAndFAT::test_visualize_chain [32mPASSED[0m[32m   [ 71%][0m
tests/test_e2e_full.py::TestZuluSCSIConfig::test_generate_and_validate [32mPASSED[0m[32m [ 74%][0m
tests/test_e2e_full.py::TestZuluSCSIConfig::test_scan_finds_hda_images [32mPASSED[0m[32m [ 77%][0m
tests/test_e2e_full.py::TestVerifyBootDisk::test_verify_fake_valid_disk [32mPASSED[0m[32m [ 80%][0m
tests/test_e2e_full.py::TestVerifyBootDisk::test_verify_real_template [32mPASSED[0m[32m [ 82%][0m
tests/test_e2e_full.py::TestVerifyBootDisk::test_verify_returns_all_check_names [32mPASSED[0m[32m [ 85%][0m
tests/test_e2e_full.py::TestBNTIdxAddressing::test_bnt_bank_flags_are_0x0081 [32mPASSED[0m[32m [ 88%][0m
tests/test_e2e_full.py::TestBNTIdxAddressing::test_bnt_bank_idx_step_is_0x0200 [32mPASSED[0m[32m [ 91%][0m
tests/test_e2e_full.py::TestBNTIdxAddressing::test_bnt_clusters_are_contiguous_and_non_overlapping [32mPASSED[0m[32m [ 94%][0m
tests/test_e2e_full.py::TestBNTIdxAddressing::test_bnt_idx_matches_emaxii_01_reference [32mPASSED[0m[32m [ 97%][0m
tests/test_e2e_full.py::TestBNTIdxAddressing::test_bnt_os_entry_idx_is_0x7800 [32mPASSED[0m[32m [100%][0m

[32m============================= [32m[1m35 passed[0m[32m in 18.64s[0m[32m ==============================[0m
✅ CLI E2E tests: PASSED

🍎 Running AppleScript / GUI tests...
[1m============================= test session starts ==============================[0m
platform darwin -- Python 3.14.2, pytest-9.0.2, pluggy-1.6.0 -- /Users/senioradvisor/clawd/EmaxForge/agent-harness/venv/bin/python3.14
cachedir: .pytest_cache
rootdir: /Users/senioradvisor/clawd/EmaxForge/agent-harness
[1mcollecting ... [0mcollected 15 items

tests/test_applescript_automation.py::TestAppleScriptFiles::test_all_expected_scripts_exist [32mPASSED[0m[32m [  6%][0m
tests/test_applescript_automation.py::TestAppleScriptFiles::test_script_directory_exists [32mPASSED[0m[32m [ 13%][0m
tests/test_applescript_automation.py::TestAppleScriptFiles::test_scripts_are_non_empty [32mPASSED[0m[32m [ 20%][0m
tests/test_applescript_automation.py::TestAppleScriptFiles::test_scripts_have_tell_application [32mPASSED[0m[32m [ 26%][0m
tests/test_applescript_automation.py::TestOsascriptAvailability::test_osascript_version [32mPASSED[0m[32m [ 33%][0m
tests/test_applescript_automation.py::TestOsascriptAvailability::test_simple_arithmetic [32mPASSED[0m[32m [ 40%][0m
tests/test_applescript_automation.py::TestOsascriptAvailability::test_string_result [32mPASSED[0m[32m [ 46%][0m
tests/test_applescript_automation.py::TestGUISmoke::test_app_frontmost [31mFAILED[0m[31m [ 53%][0m
tests/test_applescript_automation.py::TestGUISmoke::test_app_has_windows [31mFAILED[0m[31m [ 60%][0m
tests/test_applescript_automation.py::TestGUISmoke::test_app_is_accessible [32mPASSED[0m[31m [ 66%][0m
tests/test_applescript_automation.py::TestBootDiskWizardScript::test_boot_disk_wizard_creates_file [33mSKIPPED[0m[31m [ 73%][0m
tests/test_applescript_automation.py::TestBootDiskWizardScript::test_script_syntax_valid [32mPASSED[0m[31m [ 80%][0m
tests/test_applescript_automation.py::TestFloppyWizardScript::test_floppy_wizard_creates_file [33mSKIPPED[0m[31m [ 86%][0m
tests/test_applescript_automation.py::TestFloppyWizardScript::test_script_syntax_valid [32mPASSED[0m[31m [ 93%][0m
tests/test_applescript_automation.py::TestVerifyImageScript::test_script_syntax_valid [32mPASSED[0m[31m [100%][0m

=================================== FAILURES ===================================
[31m[1m_______________________ TestGUISmoke.test_app_frontmost ________________________[0m
[1m[31mtests/test_applescript_automation.py[0m:181: in test_app_frontmost
    [0m[96mself[39;49;00m.assertIn([33m"[39;49;00m[33mtrue[39;49;00m[33m"[39;49;00m, out.lower())[90m[39;49;00m
[1m[31mE   AssertionError: 'true' not found in 'false'[0m
[31m[1m______________________ TestGUISmoke.test_app_has_windows _______________________[0m
[1m[31mtests/test_applescript_automation.py[0m:167: in test_app_has_windows
    [0m[96mself[39;49;00m.assertGreater(count, [94m0[39;49;00m, [33m"[39;49;00m[33mNo windows found[39;49;00m[33m"[39;49;00m)[90m[39;49;00m
[1m[31mE   AssertionError: 0 not greater than 0 : No windows found[0m
[36m[1m=========================== short test summary info ============================[0m
[31mFAILED[0m tests/test_applescript_automation.py::[1mTestGUISmoke::test_app_frontmost[0m - AssertionError: 'true' not found in 'false'
[31mFAILED[0m tests/test_applescript_automation.py::[1mTestGUISmoke::test_app_has_windows[0m - AssertionError: 0 not greater than 0 : No windows found
[31m=================== [31m[1m2 failed[0m, [32m11 passed[0m, [33m2 skipped[0m[31m in 2.97s[0m[31m ====================[0m
❌ AppleScript tests: FAILURES

⚠️  Running edge case tests...
[1m============================= test session starts ==============================[0m
platform darwin -- Python 3.14.2, pytest-9.0.2, pluggy-1.6.0 -- /Users/senioradvisor/clawd/EmaxForge/agent-harness/venv/bin/python3.14
cachedir: .pytest_cache
rootdir: /Users/senioradvisor/clawd/EmaxForge/agent-harness
[1mcollecting ... [0mcollected 28 items

tests/test_edge_cases.py::TestCorruptedBootSignature::test_corrupted_after_creation [32mPASSED[0m[32m [  3%][0m
tests/test_edge_cases.py::TestCorruptedBootSignature::test_pc_boot_sig_detected [32mPASSED[0m[32m [  7%][0m
tests/test_edge_cases.py::TestCorruptedBootSignature::test_wrong_sig_is_reported_in_checks [32mPASSED[0m[32m [ 10%][0m
tests/test_edge_cases.py::TestCorruptedBootSignature::test_zero_boot_sig_fails [32mPASSED[0m[32m [ 14%][0m
tests/test_edge_cases.py::TestInvalidFATEntries::test_fat0_ffff_fails_check [32mPASSED[0m[32m [ 17%][0m
tests/test_edge_cases.py::TestInvalidFATEntries::test_fat0_zero_fails_check [32mPASSED[0m[32m [ 21%][0m
tests/test_edge_cases.py::TestInvalidFATEntries::test_fat_entry0_correct_value [32mPASSED[0m[32m [ 25%][0m
tests/test_edge_cases.py::TestMissingFiles::test_export_bank_empty_slot [32mPASSED[0m[32m [ 28%][0m
tests/test_edge_cases.py::TestMissingFiles::test_import_bank_missing_bank_file [32mPASSED[0m[32m [ 32%][0m
tests/test_edge_cases.py::TestMissingFiles::test_import_bank_missing_disk [32mPASSED[0m[32m [ 35%][0m
tests/test_edge_cases.py::TestMissingFiles::test_list_images_nonexistent_dir [32mPASSED[0m[32m [ 39%][0m
tests/test_edge_cases.py::TestMissingFiles::test_validate_nonexistent_config [32mPASSED[0m[32m [ 42%][0m
tests/test_edge_cases.py::TestMissingFiles::test_verify_nonexistent_disk [32mPASSED[0m[32m [ 46%][0m
tests/test_edge_cases.py::TestInvalidDiskSizes::test_create_boot_disk_invalid_size [32mPASSED[0m[32m [ 50%][0m
tests/test_edge_cases.py::TestInvalidDiskSizes::test_create_boot_disk_invalid_size_python [32mPASSED[0m[32m [ 53%][0m
tests/test_edge_cases.py::TestInvalidDiskSizes::test_create_floppy_invalid_size [32mPASSED[0m[32m [ 57%][0m
tests/test_edge_cases.py::TestInvalidDiskSizes::test_create_floppy_invalid_size_python [32mPASSED[0m[32m [ 60%][0m
tests/test_edge_cases.py::TestMissingCatalog::test_disk_without_catalog_fails_check [32mPASSED[0m[32m [ 64%][0m
tests/test_edge_cases.py::TestMissingCatalog::test_disk_without_os_chain_fails [32mPASSED[0m[32m [ 67%][0m
tests/test_edge_cases.py::TestInvalidTemplates::test_unknown_template_name [32mPASSED[0m[32m [ 71%][0m
tests/test_edge_cases.py::TestInvalidTemplates::test_unknown_template_python [32mPASSED[0m[32m [ 75%][0m
tests/test_edge_cases.py::TestHFEErrors::test_convert_invalid_hfe_fails [32mPASSED[0m[32m [ 78%][0m
tests/test_edge_cases.py::TestHFEErrors::test_convert_invalid_hfe_python [32mPASSED[0m[32m [ 82%][0m
tests/test_edge_cases.py::TestHFEErrors::test_empty_file_rejected [32mPASSED[0m[32m [ 85%][0m
tests/test_edge_cases.py::TestUnrecognizedDiskSize::test_weird_size_fails_file_size_check [32mPASSED[0m[32m [ 89%][0m
tests/test_edge_cases.py::TestIdempotency::test_floppy_creation_idempotent [32mPASSED[0m[32m [ 92%][0m
tests/test_edge_cases.py::TestIdempotency::test_list_images_does_not_modify [32mPASSED[0m[32m [ 96%][0m
tests/test_edge_cases.py::TestIdempotency::test_verify_does_not_modify_disk [32mPASSED[0m[32m [100%][0m

[32m============================== [32m[1m28 passed[0m[32m in 3.77s[0m[32m ==============================[0m
✅ Edge case tests: PASSED

⏱️  Running performance benchmarks...
[1m============================= test session starts ==============================[0m
platform darwin -- Python 3.14.2, pytest-9.0.2, pluggy-1.6.0 -- /Users/senioradvisor/clawd/EmaxForge/agent-harness/venv/bin/python3.14
cachedir: .pytest_cache
rootdir: /Users/senioradvisor/clawd/EmaxForge/agent-harness
[1mcollecting ... [0mcollected 20 items

tests/test_performance.py::TestBootDiskCreationSpeed::test_all_sizes_benchmark_summary [32mPASSED[0m[32m [  5%][0m
tests/test_performance.py::TestBootDiskCreationSpeed::test_create_239mb_speed [32mPASSED[0m[32m [ 10%][0m
tests/test_performance.py::TestBootDiskCreationSpeed::test_create_481mb_speed [32mPASSED[0m[32m [ 15%][0m
tests/test_performance.py::TestBootDiskCreationSpeed::test_create_633mb_speed [32mPASSED[0m[32m [ 20%][0m
tests/test_performance.py::TestBootDiskCreationSpeed::test_create_962mb_speed [32mPASSED[0m[32m [ 25%][0m
tests/test_performance.py::TestBootDiskCreationSpeed::test_create_96mb_speed [32mPASSED[0m[32m [ 30%][0m
tests/test_performance.py::TestDiskParsingSpeed::test_list_images_speed [32mPASSED[0m[32m [ 35%][0m
tests/test_performance.py::TestDiskParsingSpeed::test_verify_239mb_speed [32mPASSED[0m[32m [ 40%][0m
tests/test_performance.py::TestDiskParsingSpeed::test_verify_962mb_speed [32mPASSED[0m[32m [ 45%][0m
tests/test_performance.py::TestFATAnalysisSpeed::test_analyze_fat_239mb_speed [32mPASSED[0m[32m [ 50%][0m
tests/test_performance.py::TestFATAnalysisSpeed::test_analyze_fat_962mb_speed [32mPASSED[0m[32m [ 55%][0m
tests/test_performance.py::TestFloppyCreationSpeed::test_create_1440k_raw_speed [32mPASSED[0m[32m [ 60%][0m
tests/test_performance.py::TestFloppyCreationSpeed::test_create_180k_raw_speed [32mPASSED[0m[32m [ 65%][0m
tests/test_performance.py::TestFloppyCreationSpeed::test_create_800k_hfe_speed [32mPASSED[0m[32m [ 70%][0m
tests/test_performance.py::TestFloppyCreationSpeed::test_create_800k_raw_speed [32mPASSED[0m[32m [ 75%][0m
tests/test_performance.py::TestBankTemplateSpeed::test_create_empty_100_preset_speed [32mPASSED[0m[32m [ 80%][0m
tests/test_performance.py::TestBankTemplateSpeed::test_create_init_template_speed [32mPASSED[0m[32m [ 85%][0m
tests/test_performance.py::TestBankTemplateSpeed::test_list_templates_speed [32mPASSED[0m[32m [ 90%][0m
tests/test_performance.py::TestZuluSCSIConfigSpeed::test_generate_config_speed [32mPASSED[0m[32m [ 95%][0m
tests/test_performance.py::TestZuluSCSIConfigSpeed::test_validate_config_speed [32mPASSED[0m[32m [100%][0m

[32m============================= [32m[1m20 passed[0m[32m in 10.61s[0m[32m ==============================[0m
✅ Performance tests: PASSED

🔬 Running existing unit tests (cli_anything/emaxforge/tests/)...
[1m============================= test session starts ==============================[0m
platform darwin -- Python 3.14.2, pytest-9.0.2, pluggy-1.6.0 -- /Users/senioradvisor/clawd/EmaxForge/agent-harness/venv/bin/python3.14
cachedir: .pytest_cache
rootdir: /Users/senioradvisor/clawd/EmaxForge/agent-harness
[1mcollecting ... [0mcollected 41 items

cli_anything/emaxforge/tests/test_core.py::TestVerifyBootDisk::test_bad_fat_entry_fails [32mPASSED[0m[32m [  2%][0m
cli_anything/emaxforge/tests/test_core.py::TestVerifyBootDisk::test_checks_list_contains_expected_keys [32mPASSED[0m[32m [  4%][0m
cli_anything/emaxforge/tests/test_core.py::TestVerifyBootDisk::test_missing_file_raises [32mPASSED[0m[32m [  7%][0m
cli_anything/emaxforge/tests/test_core.py::TestVerifyBootDisk::test_valid_disk_passes_all_checks [32mPASSED[0m[32m [  9%][0m
cli_anything/emaxforge/tests/test_core.py::TestVerifyBootDisk::test_wrong_boot_signature_fails [32mPASSED[0m[32m [ 12%][0m
cli_anything/emaxforge/tests/test_core.py::TestListImages::test_empty_directory [32mPASSED[0m[32m [ 14%][0m
cli_anything/emaxforge/tests/test_core.py::TestListImages::test_identifies_floppy_files [32mPASSED[0m[32m [ 17%][0m
cli_anything/emaxforge/tests/test_core.py::TestListImages::test_lists_hda_files [32mPASSED[0m[32m [ 19%][0m
cli_anything/emaxforge/tests/test_core.py::TestListImages::test_missing_directory_raises [32mPASSED[0m[32m [ 21%][0m
cli_anything/emaxforge/tests/test_core.py::TestCreateFloppy::test_all_valid_sizes [32mPASSED[0m[32m [ 24%][0m
cli_anything/emaxforge/tests/test_core.py::TestCreateFloppy::test_create_180k_single_density [32mPASSED[0m[32m [ 26%][0m
cli_anything/emaxforge/tests/test_core.py::TestCreateFloppy::test_create_hfe_floppy [32mPASSED[0m[32m [ 29%][0m
cli_anything/emaxforge/tests/test_core.py::TestCreateFloppy::test_create_raw_floppy_800k [32mPASSED[0m[32m [ 31%][0m
cli_anything/emaxforge/tests/test_core.py::TestCreateFloppy::test_invalid_size_raises [32mPASSED[0m[32m [ 34%][0m
cli_anything/emaxforge/tests/test_core.py::TestFloppySizeDetection::test_detect_1440k [32mPASSED[0m[32m [ 36%][0m
cli_anything/emaxforge/tests/test_core.py::TestFloppySizeDetection::test_detect_800k [32mPASSED[0m[32m [ 39%][0m
cli_anything/emaxforge/tests/test_core.py::TestFloppySizeDetection::test_unknown_size_returns_none [32mPASSED[0m[32m [ 41%][0m
cli_anything/emaxforge/tests/test_core.py::TestListFloppies::test_finds_fd_prefixed_files [32mPASSED[0m[32m [ 43%][0m
cli_anything/emaxforge/tests/test_core.py::TestListFloppies::test_finds_hfe_files [32mPASSED[0m[32m [ 46%][0m
cli_anything/emaxforge/tests/test_core.py::TestListFloppies::test_missing_directory_raises [32mPASSED[0m[32m [ 48%][0m
cli_anything/emaxforge/tests/test_core.py::TestConvertHFE::test_convert_roundtrip [32mPASSED[0m[32m [ 51%][0m
cli_anything/emaxforge/tests/test_core.py::TestConvertHFE::test_invalid_hfe_raises [32mPASSED[0m[32m [ 53%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_create_floppy_cmd [32mPASSED[0m[32m [ 56%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_create_floppy_json [32mPASSED[0m[32m [ 58%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_help_runs [32mPASSED[0m[32m [ 60%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_list_images_cmd [32mPASSED[0m[32m [ 63%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_verify_boot_invalid_exits_1 [32mPASSED[0m[32m [ 65%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_verify_boot_valid [32mPASSED[0m[32m [ 68%][0m
cli_anything/emaxforge/tests/test_core.py::TestCLISubprocess::test_version_runs [32mPASSED[0m[32m [ 70%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestFloppyWorkflow::test_all_floppy_sizes [32mPASSED[0m[32m [ 73%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestFloppyWorkflow::test_create_floppy_json_output [32mPASSED[0m[32m [ 75%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestFloppyWorkflow::test_create_hfe_floppy_has_magic [32mPASSED[0m[32m [ 78%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestFloppyWorkflow::test_create_list_raw_floppy [32mPASSED[0m[32m [ 80%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestHFEConversion::test_convert_hfe_to_img [32mPASSED[0m[32m [ 82%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestBootDiskVerification::test_verify_checks_all_fields [32mPASSED[0m[32m [ 85%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestBootDiskVerification::test_verify_invalid_disk_exits_nonzero [32mPASSED[0m[32m [ 87%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestBootDiskVerification::test_verify_valid_disk_passes [32mPASSED[0m[32m [ 90%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestListImages::test_boot_disk_flagged [32mPASSED[0m[32m [ 92%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestListImages::test_mixed_hd_fd_directory [32mPASSED[0m[32m [ 95%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestAppleScriptSmoke::test_launch_script_returns_ready_or_timeout [33mSKIPPED[0m[32m [ 97%][0m
cli_anything/emaxforge/tests/test_full_e2e.py::TestAppleScriptSmoke::test_script_files_exist [32mPASSED[0m[32m [100%][0m

[32m======================== [32m[1m40 passed[0m, [33m1 skipped[0m[32m in 3.56s[0m[32m =========================[0m
✅ Existing unit tests: PASSED

📋 Running spec compliance validation...
[1m============================= test session starts ==============================[0m
platform darwin -- Python 3.14.2, pytest-9.0.2, pluggy-1.6.0 -- /Users/senioradvisor/clawd/EmaxForge/agent-harness/venv/bin/python3.14
cachedir: .pytest_cache
rootdir: /Users/senioradvisor/clawd/EmaxForge/agent-harness
[1mcollecting ... [0mcollected 9 items

tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_boot_signatures_are_unique [32mPASSED[0m[32m [ 11%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_catalog_os_entry_present [32mPASSED[0m[32m [ 22%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_compliance_239mb [32mPASSED[0m[32m [ 33%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_compliance_481mb [32mPASSED[0m[32m [ 44%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_compliance_633mb [32mPASSED[0m[32m [ 55%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_compliance_962mb [32mPASSED[0m[32m [ 66%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_compliance_96mb [32mPASSED[0m[32m [ 77%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_disk_sizes_match_spec [32mPASSED[0m[32m [ 88%][0m
tests/compliance/validate_spec_compliance.py::TestSpecCompliance::test_fat_entry0_constant [32mPASSED[0m[32m [100%][0m

[32m============================== [32m[1m9 passed[0m[32m in 12.47s[0m[32m ==============================[0m
✅ Compliance: PASSED

--- Compliance Summary ---

==================================================
  EMAX II Spec Compliance Report
==================================================

  [PASS] 96 MB  
      ✓ file_size: OK
      ✓ boot_signature: OK
      ✓ fat_entry_0: OK
      ✓ fat_entry_1_nonzero: OS chain present
      ✓ catalog_os_entry: OS entry: 'Designed by S&M.'

  [PASS] 239 MB  
      ✓ file_size: OK
      ✓ boot_signature: OK
      ✓ fat_entry_0: OK
      ✓ fat_entry_1_nonzero: OS chain present
      ✓ catalog_os_entry: OS entry: 'EMAX2 Software'

  [PASS] 481 MB  
      ✓ file_size: OK
      ✓ boot_signature: OK
      ✓ fat_entry_0: OK
      ✓ fat_entry_1_nonzero: OS chain present
      ✓ catalog_os_entry: OS entry: 'ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ'

  [PASS] 633 MB  
      ✓ file_size: OK
      ✓ boot_signature: OK
      ✓ fat_entry_0: OK
      ✓ fat_entry_1_nonzero: OS chain present
      ✓ catalog_os_entry: OS entry: 'ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ'

  [PASS] 962 MB  
      ✓ file_size: OK
      ✓ boot_signature: OK
      ✓ fat_entry_0: OK
      ✓ fat_entry_1_nonzero: OS chain present
      ✓ catalog_os_entry: OS entry: 'ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ'

==================================================
  Compliance: 100.0%  (25/25 checks passed)
==================================================


📊 Generating combined test report...
✅ Report written: /Users/senioradvisor/clawd/EmaxForge/TEST_REPORT.md

==============================================
  ⚠️  TESTS COMPLETE — SOME FAILURES (see above)
  Report: TEST_REPORT.md
==============================================

