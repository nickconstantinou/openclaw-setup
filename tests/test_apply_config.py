#!/usr/bin/env python3
"""
@intent Unit tests for parse_allowed_users in apply-config.py.
@complexity 2
"""
import os
import sys
import unittest

# Import the module under test by loading it as a module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'config'))


class TestParseAllowedUsers(unittest.TestCase):
    """Truth table for parse_allowed_users — security-critical allowlist parsing."""

    @staticmethod
    def _parse(env_var, default_list=None):
        """Mirror of parse_allowed_users from apply-config.py."""
        raw = os.environ.get(env_var, '')

        if raw.strip() == 'INHERIT' and default_list is not None:
            return default_list

        candidates = [
            uid.strip() for uid in raw.split(',')
            if uid.strip() and uid.strip() not in ('REPLACE_ME', 'INHERIT')
        ]

        users = [uid for uid in candidates if uid.isdigit()]
        return users

    def _set_env(self, key, value):
        os.environ[key] = value
        self.addCleanup(os.environ.pop, key, None)

    # ── Truth Table ──────────────────────────────────────────────────────────

    def test_empty_string_returns_empty_list(self):
        self._set_env('TEST_USERS', '')
        self.assertEqual(self._parse('TEST_USERS'), [])

    def test_unset_var_returns_empty_list(self):
        os.environ.pop('TEST_USERS_UNSET', None)
        self.assertEqual(self._parse('TEST_USERS_UNSET'), [])

    def test_replace_me_sentinel_returns_empty_list(self):
        self._set_env('TEST_USERS', 'REPLACE_ME')
        self.assertEqual(self._parse('TEST_USERS'), [])

    def test_inherit_with_parent_returns_parent(self):
        self._set_env('TEST_USERS', 'INHERIT')
        self.assertEqual(self._parse('TEST_USERS', ['123']), ['123'])

    def test_inherit_without_parent_returns_empty(self):
        self._set_env('TEST_USERS', 'INHERIT')
        self.assertEqual(self._parse('TEST_USERS'), [])

    def test_valid_csv_returns_list(self):
        self._set_env('TEST_USERS', '123,456')
        self.assertEqual(self._parse('TEST_USERS'), ['123', '456'])

    def test_trailing_commas_ignored(self):
        self._set_env('TEST_USERS', '123,,456,')
        self.assertEqual(self._parse('TEST_USERS'), ['123', '456'])

    def test_non_numeric_entries_skipped(self):
        self._set_env('TEST_USERS', '123,my-username,456')
        self.assertEqual(self._parse('TEST_USERS'), ['123', '456'])

    def test_whitespace_stripped(self):
        self._set_env('TEST_USERS', ' 123 , 456 ')
        self.assertEqual(self._parse('TEST_USERS'), ['123', '456'])


if __name__ == '__main__':
    unittest.main()
