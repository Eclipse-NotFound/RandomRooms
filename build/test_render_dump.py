"""Regression tests for real DUMP formats, including version changes/truncation."""
import unittest
from render_dump import parse_log, metrics


def dump(tag="[RR:v6.6]", name="syn_100", extra="", end=True):
    grid = [["_"] * 48 for _ in range(25)]
    grid[24] = ["J"] * 48
    lines = [f"DUMP-BEGIN {name}{extra}"]
    lines += ["DUMP-ROW " + ".".join(row) for row in grid]
    lines += ["DUMP-OBJ player 4 23", "DUMP-BACK vents 8 22"]
    if end:
        lines.append("DUMP-END")
    return "\r\n".join(tag + " " + line for line in lines) + "\r\n"


class DumpTest(unittest.TestCase):
    def test_versions_attributes_and_full_batch(self):
        text = dump("[RR:0.0.1-M0]", "old") + dump(extra=" b24=23,24,")
        rooms, warnings = parse_log(text)
        self.assertEqual([r["name"] for r in rooms], ["old", "syn_100"])
        self.assertEqual(rooms[1]["attributes"], {"b24": "23,24,"})
        self.assertEqual(warnings, [])

    def test_latest_session_does_not_fall_back_to_old_success(self):
        text = dump(name="old") + "[RR:v6.7] RRDiag init, fileStream=x\n"
        rooms, _ = parse_log(text + dump(name="partial", end=False))
        self.assertEqual(rooms, [])

    def test_truncated_and_malformed_blocks_are_not_counted(self):
        text = dump(name="good") + dump(name="bad").replace("DUMP-ROW _.", "DUMP-ROW ", 1)
        rooms, warnings = parse_log(text + dump(name="partial", end=False))
        self.assertEqual([r["name"] for r in rooms], ["good"])
        self.assertEqual(len(warnings), 2)

    def test_anchor_and_below_are_distinct(self):
        rooms, _ = parse_log(dump())
        result = metrics(rooms[0])
        self.assertEqual(result["anchor_cells"], {"_": 1})
        self.assertEqual(result["below_anchor_cells"], {"J": 1})
        self.assertEqual(result["no_solid_support_candidates"], [])


if __name__ == "__main__":
    unittest.main()
