"""
Milestone 4 Empirical Challenger Verification Suite
Verifies:
1. Docker compose configuration syntax and service topology (using JSON format)
2. .env.example variable inventory vs requirements
3. docker-compose.yml environment variable mapping and interpolation
4. gateway/Dockerfile non-root user (10001:10001), multi-stage build, static assets, and healthcheck
5. engine/Dockerfile non-root user (10001:10001), multi-stage build, and healthcheck
"""

import unittest
import os
import subprocess
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

class TestMilestone4Containerization(unittest.TestCase):

    def test_01_docker_compose_config_validity(self):
        """Verifies docker compose config validates with exit code 0."""
        result = subprocess.run(
            ["docker", "compose", "config", "--format", "json"],
            cwd=str(REPO_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        self.assertEqual(result.returncode, 0, f"docker compose config failed: {result.stderr}")
        config = json.loads(result.stdout)
        
        # Verify required services exist
        services = config.get("services", {})
        self.assertIn("gateway", services)
        self.assertIn("engine", services)
        self.assertIn("redis", services)

        # Verify network
        networks = config.get("networks", {})
        self.assertIn("weather-resilience-net", networks)

        # Verify volume
        volumes = config.get("volumes", {})
        self.assertIn("redis_data", volumes)

    def test_02_env_example_required_variables(self):
        """Verifies .env.example contains all required environment variables."""
        env_example_path = REPO_ROOT / ".env.example"
        self.assertTrue(env_example_path.exists(), ".env.example does not exist")
        content = env_example_path.read_text(encoding="utf-8")

        required_vars = [
            "PORT",
            "LINE_CHANNEL_SECRET",
            "LINE_CHANNEL_TOKEN",
            "LIFF_ENDPOINT_URL",
            "ENGINE_BASE_URL",
            "REDIS_URL",
            "GEMINI_API_KEY",
        ]

        found_vars = {}
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k = line.split("=", 1)[0].strip()
                found_vars[k] = True

        for var in required_vars:
            self.assertIn(var, found_vars, f"Required env var '{var}' missing from .env.example")

    def test_03_docker_compose_passes_required_variables(self):
        """Verifies docker-compose.yml defines and passes the required variables to respective services."""
        compose_path = REPO_ROOT / "docker-compose.yml"
        self.assertTrue(compose_path.exists(), "docker-compose.yml does not exist")

        # Test with custom environment injection
        test_env = os.environ.copy()
        test_env.update({
            "PORT": "8181",
            "ENGINE_PORT": "8180",
            "LINE_CHANNEL_SECRET": "test_challenger_secret_999",
            "LINE_CHANNEL_TOKEN": "test_challenger_token_888",
            "LIFF_ENDPOINT_URL": "https://liff.line.me/challenger_test",
            "GEMINI_API_KEY": "test_gemini_key_777",
            "REDIS_PORT": "6380",
        })

        result = subprocess.run(
            ["docker", "compose", "config", "--format", "json"],
            cwd=str(REPO_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=test_env
        )
        self.assertEqual(result.returncode, 0, f"docker compose config failed: {result.stderr}")
        cfg = json.loads(result.stdout)
        services = cfg["services"]

        # 1. Gateway verification
        gw_env = services["gateway"]["environment"]
        self.assertEqual(gw_env.get("LINE_CHANNEL_SECRET"), "test_challenger_secret_999")
        self.assertEqual(gw_env.get("LINE_CHANNEL_TOKEN"), "test_challenger_token_888")
        self.assertEqual(gw_env.get("LIFF_ENDPOINT_URL"), "https://liff.line.me/challenger_test")
        self.assertEqual(gw_env.get("ENGINE_BASE_URL"), "http://engine:8000")
        self.assertEqual(gw_env.get("REDIS_URL"), "redis://redis:6379")
        self.assertEqual(gw_env.get("PORT"), "8080")
        # Published port
        gw_ports = [str(p["published"]) for p in services["gateway"]["ports"]]
        self.assertIn("8181", gw_ports)

        # 2. Engine verification
        eng_env = services["engine"]["environment"]
        self.assertEqual(eng_env.get("GEMINI_API_KEY"), "test_gemini_key_777")
        self.assertEqual(eng_env.get("REDIS_URL"), "redis://redis:6379")
        self.assertEqual(eng_env.get("PORT"), "8000")
        eng_ports = [str(p["published"]) for p in services["engine"]["ports"]]
        self.assertIn("8180", eng_ports)

        # 3. Inter-service dependency health sequencing
        self.assertIn("condition", services["gateway"]["depends_on"]["engine"])
        self.assertEqual(services["gateway"]["depends_on"]["engine"]["condition"], "service_healthy")
        self.assertIn("condition", services["gateway"]["depends_on"]["redis"])
        self.assertEqual(services["gateway"]["depends_on"]["redis"]["condition"], "service_healthy")
        self.assertIn("condition", services["engine"]["depends_on"]["redis"])
        self.assertEqual(services["engine"]["depends_on"]["redis"]["condition"], "service_healthy")

    def test_04_gateway_dockerfile_security_and_assets(self):
        """Verifies gateway/Dockerfile defines non-root user 10001, copies static assets, and defines healthcheck."""
        df_path = REPO_ROOT / "gateway" / "Dockerfile"
        self.assertTrue(df_path.exists(), "gateway/Dockerfile does not exist")
        content = df_path.read_text(encoding="utf-8")

        # Multi-stage check
        self.assertIn("AS builder", content)
        self.assertIn("FROM alpine:", content)

        # Non-root user check (10001)
        self.assertIn("10001", content)
        self.assertIn("USER 10001:10001", content)
        self.assertIn("adduser -u 10001", content)

        # Static asset copying check
        self.assertIn("/app/static", content)
        self.assertIn("--chown=appuser:appgroup", content)

        # Healthcheck check
        self.assertIn("HEALTHCHECK", content)
        self.assertIn("http://localhost:8080/health", content)

        # Verify static directory exists on host
        static_dir = REPO_ROOT / "gateway" / "static" / "liff"
        self.assertTrue(static_dir.exists(), "gateway/static/liff does not exist")
        self.assertTrue((static_dir / "index.html").exists(), "index.html missing in static/liff")

    def test_05_engine_dockerfile_security_and_geos(self):
        """Verifies engine/Dockerfile defines non-root user 10001, copies venv, and defines healthcheck."""
        df_path = REPO_ROOT / "engine" / "Dockerfile"
        self.assertTrue(df_path.exists(), "engine/Dockerfile does not exist")
        content = df_path.read_text(encoding="utf-8")

        # Multi-stage check
        self.assertIn("AS builder", content)
        self.assertIn("AS runner", content)

        # Non-root user check (10001)
        self.assertIn("10001", content)
        self.assertIn("USER appuser", content)
        self.assertIn("useradd -u 10001", content)

        # Virtual environment and minimal C runtime
        self.assertIn("/opt/venv", content)
        self.assertIn("libgeos-c1v5", content)

        # Healthcheck check
        self.assertIn("HEALTHCHECK", content)
        self.assertIn("http://localhost:8000/health", content)

        # Symlink check
        self.assertIn("ln -sf /app/engine/main.py /app/main.py", content)

if __name__ == "__main__":
    unittest.main()
