"""
compatible error codes and messages
Based on industry-standard format error handling
"""

from enum import Enum
from typing import Optional, Dict, Any


class standard toolsErrorCode(Enum):
    """standard tools error codes (E001-E020)"""
    
    # Disk Format Errors (E001-E005)
    E001_INVALID_BOOT_SIG = ("E001", "Invalid boot signature", "Expected 0x7882 at offset 0x1FE")
    E002_INVALID_FAT_HEADER = ("E002", "Invalid FAT header", "FAT entry 0 should be 0x8000 (EMXP standard)")
    E003_INVALID_CLUSTER_SIZE = ("E003", "Invalid cluster size", "Cluster size must be 8KB, 16KB, or 32KB")
    E004_INVALID_DISK_SIZE = ("E004", "Invalid disk size", "Size must be 96, 239, 481, 633, or 962 MB")
    E005_CORRUPT_HEADER = ("E005", "Corrupt disk header", "Header data is inconsistent or damaged")
    
    # Catalog Errors (E006-E010)
    E006_INVALID_CATALOG = ("E006", "Invalid catalog entry", "Catalog structure is corrupt")
    E007_MISSING_OS = ("E007", "Missing operating system", "Boot disk requires OS in cluster 1")
    E008_INVALID_FLAGS = ("E008", "Invalid catalog flags", "FLAGS byte should be 0x0081 for active entries")
    E009_BANK_NAME_INVALID = ("E009", "Invalid bank name", "Bank name contains illegal characters")
    E010_DUPLICATE_BANK = ("E010", "Duplicate bank name", "Bank with this name already exists")
    
    # FAT Errors (E011-E015)
    E011_FAT_CHAIN_BROKEN = ("E011", "Broken FAT chain", "FAT cluster chain is corrupt or incomplete")
    E012_FAT_CIRCULAR_REF = ("E012", "Circular FAT reference", "FAT chain loops back to itself")
    E013_FAT_OUT_OF_BOUNDS = ("E013", "FAT out of bounds", "FAT entry points beyond disk capacity")
    E014_FAT_ORPHANED_CLUSTER = ("E014", "Orphaned cluster", "Cluster allocated but not referenced")
    E015_FAT_DOUBLE_ALLOC = ("E015", "Double allocation", "Cluster referenced by multiple chains")
    
    # Bank/Sample Errors (E016-E020)
    E016_BANK_TOO_LARGE = ("E016", "Bank too large", "Bank exceeds available disk space")
    E017_INVALID_SAMPLE_RATE = ("E017", "Invalid sample rate", "Sample rate must be 42000 Hz for EMAX II")
    E018_INVALID_BIT_DEPTH = ("E018", "Invalid bit depth", "Samples must be 16-bit signed")
    E019_BANK_CORRUPT = ("E019", "Bank data corrupt", "Bank file is damaged or incomplete")
    E020_SAMPLE_MISSING = ("E020", "Sample data missing", "Preset references non-existent sample")
    
    def __init__(self, code: str, title: str, description: str):
        self.code = code
        self.title = title
        self.description = description
    
    @classmethod
    def from_code(cls, code: str) -> Optional['standard toolsErrorCode']:
        """Get error by code string"""
        for error in cls:
            if error.code == code:
                return error
        return None


class ValidationError:
    """Structured validation error"""
    
    def __init__(
        self,
        error_code: standard toolsErrorCode,
        context: Optional[str] = None,
        repair_hint: Optional[str] = None,
        offset: Optional[int] = None
    ):
        self.error_code = error_code
        self.context = context
        self.repair_hint = repair_hint
        self.offset = offset
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "code": self.error_code.code,
            "title": self.error_code.title,
            "description": self.error_code.description,
            "context": self.context,
            "repair_hint": self.repair_hint,
            "offset": hex(self.offset) if self.offset is not None else None
        }
    
    def __str__(self) -> str:
        """Human-readable format"""
        msg = f"{self.error_code.code}: {self.error_code.title}"
        if self.context:
            msg += f"\n  Context: {self.context}"
        if self.offset is not None:
            msg += f"\n  Offset: {hex(self.offset)}"
        msg += f"\n  {self.error_code.description}"
        if self.repair_hint:
            msg += f"\n  Repair: {self.repair_hint}"
        return msg


# Common repair hints
REPAIR_HINTS = {
    "E001": "Rewrite boot signature: Write 0x78 0x82 at offset 0x1FE-0x1FF",
    "E002": "Repair FAT header: Write 0x0F 0x00 at FAT entry 0",
    "E003": "Re-format disk with correct cluster size",
    "E004": "Re-format disk to standard size (96/239/481/633/962 MB)",
    "E005": "Use backup header if available, or re-format disk",
    "E006": "Rebuild catalog from FAT chain analysis",
    "E007": "Import OS file (EMAX II rev 2.14) to cluster 1",
    "E008": "Set FLAGS to 0x81 0x00 (little-endian 0x0081)",
    "E009": "Rename bank to contain only A-Z, 0-9, space",
    "E010": "Rename bank to unique name",
    "E011": "Rebuild FAT chain from catalog information",
    "E012": "Break circular reference by setting end marker (0x7FFF or 0xFFFF)",
    "E013": "Truncate FAT chain at disk boundary",
    "E014": "Re-allocate cluster or mark as free",
    "E015": "Remove duplicate references",
    "E016": "Delete unnecessary banks or use larger disk",
    "E017": "Resample audio to 42000 Hz",
    "E018": "Convert audio to 16-bit signed PCM",
    "E019": "Re-import bank from original source",
    "E020": "Remove preset or import missing sample"
}


def create_error(
    error_code: standard toolsErrorCode,
    context: Optional[str] = None,
    offset: Optional[int] = None
) -> ValidationError:
    """Create validation error with auto repair hint"""
    repair_hint = REPAIR_HINTS.get(error_code.code)
    return ValidationError(error_code, context, repair_hint, offset)


# Quick error constructors
def boot_sig_error(offset: int = 0x1FE, found: int = 0) -> ValidationError:
    return create_error(
        standard toolsErrorCode.E001_INVALID_BOOT_SIG,
        context=f"Found {hex(found)} instead of 0x7882",
        offset=offset
    )


def fat_header_error(found: int = 0) -> ValidationError:
    return create_error(
        standard toolsErrorCode.E002_INVALID_FAT_HEADER,
        context=f"Found {hex(found)} instead of 0x8000",
        offset=None
    )


def cluster_size_error(found: int = 0) -> ValidationError:
    return create_error(
        standard toolsErrorCode.E003_INVALID_CLUSTER_SIZE,
        context=f"Found {found} bytes, expected 8192, 16384, or 32768"
    )


def missing_os_error() -> ValidationError:
    return create_error(
        standard toolsErrorCode.E007_MISSING_OS,
        context="Cluster 1 does not contain OS data"
    )


def flags_error(found: int = 0, offset: int = 0) -> ValidationError:
    return create_error(
        standard toolsErrorCode.E008_INVALID_FLAGS,
        context=f"Found {hex(found)} instead of 0x0081",
        offset=offset
    )
