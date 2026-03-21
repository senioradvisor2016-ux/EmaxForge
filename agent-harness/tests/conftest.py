"""pytest configuration for EmaxForge test suite (agent-harness/tests/)"""

import sys
from pathlib import Path

# Ensure agent-harness/ is on the path so cli_anything imports work
_harness = Path(__file__).parents[1]
if str(_harness) not in sys.path:
    sys.path.insert(0, str(_harness))
