import unittest
import sys
import os

# Add config directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'config'))

from migrate_secrets import run_migration

class TestMigration(unittest.TestCase):
    def test_migration_logic(self):
        config = {
            "models": {
                "providers": {
                    "minimax": {
                        "apiKey": "mm-plaintext-123"
                    },
                    "nvidia": {
                        "apiKey": "nvapi-plaintext-456"
                    }
                }
            }
        }
        
        result = run_migration(config)
        
        # Assertions
        self.assertIn("secrets", result["updated_config"])
        self.assertEqual(result["updated_config"]["secrets"]["providers"]["default"], {"source": "env"})
        
        minimax_ref = result["updated_config"]["models"]["providers"]["minimax"]["apiKey"]
        self.assertIsInstance(minimax_ref, dict)
        self.assertEqual(minimax_ref["source"], "env")
        self.assertEqual(minimax_ref["id"], "MINIMAX_API_KEY")
        
        self.assertGreaterEqual(len(result["plan"]["targets"]), 2)
        has_minimax = any(t["path"] == "models.providers.minimax.apiKey" for t in result["plan"]["targets"])
        self.assertTrue(has_minimax)

if __name__ == '__main__':
    unittest.main()
