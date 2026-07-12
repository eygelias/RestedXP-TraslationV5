import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA = (ROOT / "addon_companion" / "RXPNameFixer" / "RXPNameFixer.lua").read_text(encoding="utf-8")


class RuntimeIntegrationTests(unittest.TestCase):
    def test_does_not_depend_on_global_editmacro_override(self):
        # RXPGuides/Targeting.lua captures EditMacro in a local at load time.
        self.assertNotIn("EditMacro = function(", LUA)

    def test_hooks_rxp_update_macro_directly(self):
        self.assertIn('hooksecurefunc(addon.targeting, "UpdateMacro"', LUA)
        self.assertIn("SyncTargetMacro", LUA)

    def test_uses_actual_active_target_lists(self):
        self.assertIn("GetCurrentTargets", LUA)
        self.assertIn("LearnFromUnit", LUA)

    def test_updates_macro_and_target_frame_without_reload(self):
        self.assertIn("PLAYER_TARGET_CHANGED", LUA)
        self.assertIn("UpdateTargetFrame", LUA)
        self.assertIn("C_Timer.NewTicker", LUA)

    def test_tooltip_created_once_not_per_lookup(self):
        self.assertEqual(LUA.count('CreateFrame("GameTooltip", "RXPNameFixerTooltip"'), 1)
        self.assertIn("id and GetNameByID(id) or ResolveName(value)", LUA)


if __name__ == "__main__":
    unittest.main()
