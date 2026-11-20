"""Awareness hook must not send the PC hostname to LLMs by default."""

from __future__ import annotations

import importlib.util
import os
import sys
import unittest
from pathlib import Path


def _load_plugin():
    root = Path(__file__).resolve().parents[2]
    path = root / "assets" / "pistisai" / "hermes" / "plugins" / "pistisai" / "__init__.py"
    spec = importlib.util.spec_from_file_location("pistisai_plugin", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules["pistisai_plugin"] = mod
    spec.loader.exec_module(mod)
    return mod


class AwarenessHostOptInTest(unittest.TestCase):
    def setUp(self):
        self.mod = _load_plugin()
        for key in (
            "AIGENT_AWARENESS_DISABLE",
            "AIGENT_AWARENESS_HOST",
            "AIGENT_DEVICE",
            "AIGENT_SESSION",
            "AIGENT_LOCATION",
            "AIGENT_CONNECTION",
        ):
            os.environ.pop(key, None)

    def test_hostname_omitted_by_default(self):
        result = self.mod._on_pre_llm_call(platform="api_server", sender_id="u1")
        self.assertIsNotNone(result)
        ctx = result["context"]
        self.assertNotIn("Host (PC):", ctx)

    def test_hostname_included_when_opted_in(self):
        os.environ["AIGENT_AWARENESS_HOST"] = "1"
        result = self.mod._on_pre_llm_call(platform="api_server", sender_id="u1")
        self.assertIsNotNone(result)
        self.assertIn("Host (PC):", result["context"])


if __name__ == "__main__":
    unittest.main()
