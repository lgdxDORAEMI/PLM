import unittest

from httpx import ASGITransport, AsyncClient

from app.core.config import build_allowed_origin_regex
from app.main import app


class AppSmokeTest(unittest.IsolatedAsyncioTestCase):
    async def test_status_endpoints(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://localhost"
        ) as client:
            for path, expected in (
                ("/", {"message": "PLM API", "status": "ok"}),
                ("/health", {"status": "ok"}),
            ):
                response = await client.get(path)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json(), expected)

    async def test_cors_origins(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://localhost"
        ) as client:
            for origin, allowed in (
                ("http://localhost:54321", True),
                ("http://127.0.0.1:3000", True),
                ("https://example.com", False),
                ("http://localhost.example.com:3000", False),
            ):
                response = await client.options(
                    "/health",
                    headers={
                        "Origin": origin,
                        "Access-Control-Request-Method": "GET",
                        "Access-Control-Request-Headers": "Authorization",
                    },
                )
                self.assertEqual(response.status_code, 200 if allowed else 400)
                self.assertEqual(
                    response.headers.get("access-control-allow-origin"),
                    origin if allowed else None,
                )

    def test_production_origin_regex(self) -> None:
        pattern = build_allowed_origin_regex("https://lgdxdoraemi.github.io/")
        self.assertRegex("https://lgdxdoraemi.github.io", rf"^{pattern}$")
        self.assertNotRegex("https://example.com", rf"^{pattern}$")
