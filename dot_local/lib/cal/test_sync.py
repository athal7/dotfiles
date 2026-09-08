"""Tests for cal.sync pure logic and events_for filtering."""

import unittest
from unittest.mock import patch

# Import sync module functions directly.
# We patch the ical dependency before calling events_for.
from cal.sync import (
    is_ooo_event,
    mirror_key,
    mirror_title,
    in_inbound_window,
    is_excluded,
    is_locally_ignored,
    events_for,
    mirrors_for,
    MARKER,
)


# ---------------------------------------------------------------------------
# is_ooo_event
# ---------------------------------------------------------------------------

class TestIsOooEvent(unittest.TestCase):
    """OOO detection via EventKit availability='Unavailable'."""

    def test_unavailable_is_ooo(self):
        self.assertTrue(is_ooo_event({"availability": "Unavailable"}))

    def test_unavailable_lowercase(self):
        """ical CLI emits lowercase availability strings."""
        self.assertTrue(is_ooo_event({"availability": "unavailable"}))

    def test_busy_is_not_ooo(self):
        self.assertFalse(is_ooo_event({"availability": "Busy"}))

    def test_free_is_not_ooo(self):
        self.assertFalse(is_ooo_event({"availability": "Free"}))

    def test_tentative_is_not_ooo(self):
        self.assertFalse(is_ooo_event({"availability": "Tentative"}))

    def test_missing_availability_is_not_ooo(self):
        self.assertFalse(is_ooo_event({"title": "Out of Office"}))

    def test_empty_availability_is_not_ooo(self):
        self.assertFalse(is_ooo_event({"availability": ""}))

    def test_none_availability_is_not_ooo(self):
        self.assertFalse(is_ooo_event({}))


# ---------------------------------------------------------------------------
# mirror_key
# ---------------------------------------------------------------------------

class TestMirrorKey(unittest.TestCase):
    """Dedup keys: OOO mirrors use date ranges; busy-blocks use datetimes."""

    def test_ooo_mirror_uses_date_range(self):
        m = {
            "notes": f"{MARKER}[ooo]",
            "start_date": "2026-06-15T00:00:00Z",
            "end_date": "2026-06-20T00:00:00Z",
        }
        self.assertEqual(mirror_key(m), ("2026-06-15", "2026-06-20"))

    def test_ooo_single_day(self):
        m = {
            "notes": f"{MARKER}[ooo]",
            "start_date": "2026-06-15T00:00:00Z",
            "end_date": "2026-06-15T00:00:00Z",
        }
        self.assertEqual(mirror_key(m), ("2026-06-15", "2026-06-15"))

    def test_busy_block_mirror_uses_datetimes(self):
        m = {
            "notes": MARKER,
            "start_date": "2026-06-15T09:00:00Z",
            "end_date": "2026-06-15T10:00:00Z",
        }
        self.assertEqual(mirror_key(m), ("2026-06-15T09:00:00Z", "2026-06-15T10:00:00Z"))

    def test_busy_block_no_ooo_suffix(self):
        m = {
            "notes": f"{MARKER} extra notes",
            "start_date": "2026-06-15T09:00:00Z",
            "end_date": "2026-06-15T10:00:00Z",
        }
        self.assertEqual(mirror_key(m), ("2026-06-15T09:00:00Z", "2026-06-15T10:00:00Z"))


# ---------------------------------------------------------------------------
# mirror_title
# ---------------------------------------------------------------------------

class TestMirrorTitle(unittest.TestCase):
    """Title mapping for mirror events."""

    def test_passthrough_returns_source_title(self):
        event = {"title": "Sprint Planning"}
        self.assertEqual(mirror_title(event, {}, "Busy", passthrough=True), "Sprint Planning")

    def test_default_title_when_no_match(self):
        event = {"title": "Design Review"}
        self.assertEqual(mirror_title(event, {"lunch": "Lunch"}, "Busy"), "Busy")

    def test_title_mapping_case_insensitive(self):
        event = {"title": "Team Lunch"}
        self.assertEqual(mirror_title(event, {"lunch": "Lunch"}, "Busy"), "Lunch")

    def test_title_mapping_case_insensitive_upper(self):
        event = {"title": "TEAM LUNCH"}
        self.assertEqual(mirror_title(event, {"lunch": "Lunch"}, "Busy"), "Lunch")


# ---------------------------------------------------------------------------
# in_inbound_window
# ---------------------------------------------------------------------------

class TestInInboundWindow(unittest.TestCase):
    """Inbound time-window gating."""

    def test_within_hours(self):
        event = {"start_date": "2026-06-15T10:00:00-07:00"}
        self.assertTrue(in_inbound_window(event, None, inbound_start=9, inbound_end=17))

    def test_before_start_hour(self):
        event = {"start_date": "2026-06-15T03:00:00-07:00"}
        self.assertFalse(in_inbound_window(event, None, inbound_start=9, inbound_end=17))

    def test_after_end_hour(self):
        event = {"start_date": "2026-06-15T17:00:00-07:00"}
        self.assertFalse(in_inbound_window(event, None, inbound_start=9, inbound_end=17))

    def test_no_window_restricts_all(self):
        """No window means no restriction."""
        event = {"start_date": "2026-06-15T03:00:00-07:00"}
        self.assertTrue(in_inbound_window(event, None))

    def test_inbound_days_exclude_weekend(self):
        event = {"start_date": "2026-06-14T10:00:00-07:00"}  # Saturday
        self.assertFalse(in_inbound_window(event, None, inbound_days=["mon", "tue", "wed", "thu", "fri"]))

    def test_inbound_days_include_weekday(self):
        event = {"start_date": "2026-06-15T10:00:00-07:00"}  # Monday
        self.assertTrue(in_inbound_window(event, None, inbound_days=["mon", "tue", "wed", "thu", "fri"]))


# ---------------------------------------------------------------------------
# is_excluded
# ---------------------------------------------------------------------------

class TestIsExcluded(unittest.TestCase):
    """syncExclude filtering."""

    def test_exact_title_match(self):
        event = {"title": "Focus Time"}
        self.assertTrue(is_excluded(event, "work", {"Focus Time": "work"}))

    def test_case_insensitive(self):
        event = {"title": "FOCUS TIME"}
        self.assertTrue(is_excluded(event, "work", {"Focus Time": "work"}))

    def test_wildcard_matches_any_source(self):
        event = {"title": "Focus Time"}
        self.assertTrue(is_excluded(event, "personal", {"Focus Time": "*"}))

    def test_no_match(self):
        event = {"title": "Standup"}
        self.assertFalse(is_excluded(event, "work", {"Focus Time": "work"}))


# ---------------------------------------------------------------------------
# is_locally_ignored
# ---------------------------------------------------------------------------

class TestIsLocallyIgnored(unittest.TestCase):
    """Per-calendar ignore pattern filtering."""

    def test_substring_match(self):
        event = {"title": "CSA Delivery Weekly"}
        self.assertTrue(is_locally_ignored(event, ["CSA Delivery"]))

    def test_case_insensitive(self):
        event = {"title": "cSA dELIVERY"}
        self.assertTrue(is_locally_ignored(event, ["CSA Delivery"]))

    def test_no_match(self):
        event = {"title": "Team Meeting"}
        self.assertFalse(is_locally_ignored(event, ["CSA Delivery"]))

    def test_empty_patterns(self):
        event = {"title": "Anything"}
        self.assertFalse(is_locally_ignored(event, []))

    def test_none_patterns(self):
        event = {"title": "Anything"}
        self.assertFalse(is_locally_ignored(event, None))


# ---------------------------------------------------------------------------
# events_for (with mocked ical)
# ---------------------------------------------------------------------------

class TestEventsFor(unittest.TestCase):
    """Filtering logic for events_for. Uses mocked ical calls."""

    def setUp(self):
        self.base_event = {
            "title": "Standup",
            "start_date": "2026-06-15T09:00:00Z",
            "end_date": "2026-06-15T09:30:00Z",
            "all_day": False,
            "availability": "Busy",
            "status": "confirmed",
            "notes": "",
        }
        self.src_cal = {
            "name": "Work",
            "ooo_all_day": True,
        }
        self.cal_entries = {"work": self.src_cal}
        self.sync_exclude = {}

    def _mock_ical(self, events):
        """Return a mock that yields *events* for any ical('list', ...) call."""
        return events

    def _run_events_for(self, events, src_label="work", cal_entries=None):
        """Helper: call events_for with mocked ical."""
        with patch("cal.sync.ical", side_effect=lambda *a, **k: events):
            return events_for(
                "Work", src_label,
                "2026-06-15", "2026-06-20",
                None, self.sync_exclude,
                cal_entries=cal_entries or self.cal_entries,
            )

    def test_normal_event_included(self):
        events = [self._event("Standup")]
        result = self._run_events_for(events)
        self.assertEqual(len(result), 1)

    def test_managed_mirror_excluded(self):
        """Events with MARKER in notes must be excluded."""
        event = self._event("Busy", notes=MARKER)
        result = self._run_events_for([event])
        self.assertEqual(len(result), 0)

    def test_managed_mirror_with_ooo_suffix_excluded(self):
        event = self._event("Busy", notes=f"{MARKER}[ooo]")
        result = self._run_events_for([event])
        self.assertEqual(len(result), 0)

    def test_free_availability_excluded(self):
        event = self._event("Free Time", availability="free")
        result = self._run_events_for([event])
        self.assertEqual(len(result), 0)

    def test_cancelled_event_excluded(self):
        event = self._event("Standup", status="cancelled")
        result = self._run_events_for([event])
        self.assertEqual(len(result), 0)

    def test_excluded_event_filtered(self):
        event = self._event("Focus Time")
        sync_exclude = {"Focus Time": "work"}
        with patch("cal.sync.ical", side_effect=lambda *a, **k: [event]):
            result = events_for(
                "Work", "work",
                "2026-06-15", "2026-06-20",
                None, sync_exclude,
                cal_entries=self.cal_entries,
            )
        self.assertEqual(len(result), 0)

    def test_locally_ignored_event_filtered(self):
        event = self._event("CSA Delivery")
        cal_entries = {"work": {**self.src_cal, "ignore_patterns": ["CSA Delivery"]}}
        with patch("cal.sync.ical", side_effect=lambda *a, **k: [event]):
            result = events_for(
                "Work", "work",
                "2026-06-15", "2026-06-20",
                None, self.sync_exclude,
                ignore_patterns=["CSA Delivery"],
                cal_entries=cal_entries,
            )
        self.assertEqual(len(result), 0)

    def test_all_day_non_ooo_excluded_when_ooo_all_day_true(self):
        """Non-OOO all-day events should be excluded."""
        event = self._event("All Day Event", all_day=True, availability="Busy")
        result = self._run_events_for([event])
        self.assertEqual(len(result), 0)

    def test_ooo_all_day_event_included(self):
        """OOO events with availability=Unavailable are included when ooo_all_day is true."""
        event = self._event("Out of Office", availability="Unavailable", all_day=True)
        result = self._run_events_for([event])
        self.assertEqual(len(result), 1)

    def test_ooo_timed_event_included(self):
        """Timed OOO events are also included when ooo_all_day is true."""
        event = self._event("Out of Office", availability="Unavailable", all_day=False)
        result = self._run_events_for([event])
        self.assertEqual(len(result), 1)

    def test_ooo_excluded_when_ooo_all_day_false(self):
        """OOO events should NOT be included when ooo_all_day is disabled."""
        cal_entries = {"work": {**self.src_cal, "ooo_all_day": False}}
        event = self._event("Out of Office", availability="Unavailable", all_day=True)
        result = self._run_events_for([event], cal_entries=cal_entries)
        self.assertEqual(len(result), 0)

    def test_mixed_events_filtered_correctly(self):
        """Normal events pass, mirrors and free events are excluded."""
        events = [
            self._event("Standup"),
            self._event("Busy", notes=MARKER),
            self._event("Free Time", availability="free"),
            self._event("Lunch"),
        ]
        result = self._run_events_for(events)
        titles = {e["title"] for e in result}
        self.assertEqual(titles, {"Standup", "Lunch"})

    def test_ooo_multi_day_event_included(self):
        """Multi-day OOO events (e.g. vacation) are included."""
        event = self._event("Vacation", availability="Unavailable", all_day=True,
                            start_date="2026-06-15T00:00:00Z", end_date="2026-06-20T00:00:00Z")
        result = self._run_events_for([event])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["title"], "Vacation")

    def _event(self, title, **overrides):
        base = {
            "title": title,
            "start_date": "2026-06-15T09:00:00Z",
            "end_date": "2026-06-15T09:30:00Z",
            "all_day": False,
            "availability": "Busy",
            "status": "confirmed",
            "notes": "",
        }
        base.update(overrides)
        return base


# ---------------------------------------------------------------------------
# mirrors_for
# ---------------------------------------------------------------------------

class TestMirrorsFor(unittest.TestCase):
    """Mirror event detection."""

    def test_managed_mirror_detected(self):
        event = {"notes": MARKER, "title": "Busy"}
        with patch("cal.sync.ical", return_value=[event]):
            result = mirrors_for("Personal", "2026-06-15", "2026-06-20")
        self.assertEqual(len(result), 1)

    def test_ooo_mirror_detected(self):
        event = {"notes": f"{MARKER}[ooo]", "title": "Out of Office"}
        with patch("cal.sync.ical", return_value=[event]):
            result = mirrors_for("Personal", "2026-06-15", "2026-06-20")
        self.assertEqual(len(result), 1)

    def test_real_event_not_detected(self):
        event = {"notes": "", "title": "Standup"}
        with patch("cal.sync.ical", return_value=[event]):
            result = mirrors_for("Personal", "2026-06-15", "2026-06-20")
        self.assertEqual(len(result), 0)

    def test_partial_marker_not_detected(self):
        """Notes that merely contain MARKER as substring but don't start with it."""
        event = {"notes": f"prefix {MARKER}", "title": "Busy"}
        with patch("cal.sync.ical", return_value=[event]):
            result = mirrors_for("Personal", "2026-06-15", "2026-06-20")
        self.assertEqual(len(result), 0)


if __name__ == "__main__":
    unittest.main()
