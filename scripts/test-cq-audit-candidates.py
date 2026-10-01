#!/usr/bin/env python3
"""Exercise read-only CQ candidate selection against disposable SQLite stores."""

import importlib.machinery
import importlib.util
import json
from datetime import date
from pathlib import Path
import sqlite3
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "dot_local/bin/executable_cq-audit-candidates"
loader = importlib.machinery.SourceFileLoader("cq_audit_candidates", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
audit = importlib.util.module_from_spec(spec)
loader.exec_module(audit)


class CandidateAuditTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db_path = Path(self.temp.name) / "cq.db"
        with sqlite3.connect(self.db_path) as db:
            db.execute("CREATE TABLE knowledge_units (id TEXT PRIMARY KEY, data TEXT NOT NULL)")
            for index in range(11):
                unit_id = f"ku_{index:032x}"
                data = {"id": unit_id, "domains": ["generic"], "insight": {"summary": f"unit {index}"}}
                db.execute("INSERT INTO knowledge_units VALUES (?, ?)", (unit_id, json.dumps(data)))
            for index, domains in enumerate((["kb-scope-projects", "kb-projection:source"], ["kb-projection:other"])):
                unit_id = f"projected_{index}"
                db.execute("INSERT INTO knowledge_units VALUES (?, ?)", (unit_id, json.dumps({"id": unit_id, "domains": domains})))

    def test_excludes_projection_units_and_rotates_five_each_weekday(self):
        first = audit.candidates(self.db_path, date(2026, 9, 28))
        second = audit.candidates(self.db_path, date(2026, 9, 29))
        self.assertEqual(11, first["eligible_count"])
        self.assertEqual(5, len(first["entries"]))
        self.assertEqual(5, len(second["entries"]))
        first_ids = {entry["id"] for entry in first["entries"]}
        second_ids = {entry["id"] for entry in second["entries"]}
        self.assertTrue(first_ids.isdisjoint(second_ids))
        self.assertNotIn("projected_0", first_ids | second_ids)
        self.assertNotIn("projected_1", first_ids | second_ids)

    def test_weekend_uses_fridays_batch(self):
        friday = audit.candidates(self.db_path, date(2026, 10, 2))
        saturday = audit.candidates(self.db_path, date(2026, 10, 3))
        self.assertEqual([entry["id"] for entry in friday["entries"]], [entry["id"] for entry in saturday["entries"]])

    def test_read_only_database_is_not_modified(self):
        with sqlite3.connect(self.db_path) as db:
            before = db.execute("SELECT id, data FROM knowledge_units ORDER BY id").fetchall()
        audit.candidates(self.db_path, date(2026, 9, 28))
        with sqlite3.connect(self.db_path) as db:
            after = db.execute("SELECT id, data FROM knowledge_units ORDER BY id").fetchall()
        self.assertEqual(before, after)

    def test_missing_database_fails_without_creating_it(self):
        missing = Path(self.temp.name) / "missing.db"
        with self.assertRaises(sqlite3.OperationalError):
            audit.candidates(missing, date(2026, 9, 28))
        self.assertFalse(missing.exists())

    def test_invalid_unit_metadata_fails_closed(self):
        with sqlite3.connect(self.db_path) as db:
            db.execute("INSERT INTO knowledge_units VALUES (?, ?)", ("broken", "{}"))
        with self.assertRaises(ValueError):
            audit.candidates(self.db_path, date(2026, 9, 28))


if __name__ == "__main__":
    unittest.main()
