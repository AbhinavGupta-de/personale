from __future__ import annotations

from types import TracebackType
from typing import Any, Self

import httpx

from .config import Settings


class PersonaleUnavailableError(Exception):
    """Raised when the local Personale backend cannot be reached."""


class PersonaleAPIError(Exception):
    def __init__(self, status: int, body: str) -> None:
        self.status = status
        self.body = body
        super().__init__(f"Personale API returned HTTP {status}: {body}")


class PersonaleClient:
    def __init__(
        self,
        settings: Settings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.settings = settings
        self._transport = transport
        self._http: httpx.AsyncClient | None = None

    async def __aenter__(self) -> Self:
        self._ensure_http_client()
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self.aclose()

    async def aclose(self) -> None:
        if self._http is not None:
            await self._http.aclose()
            self._http = None

    async def get(self, path: str, **params: Any) -> Any:
        if "dayStartHour" not in params:
            params["dayStartHour"] = self.settings.day_start_hour

        try:
            response = await self._ensure_http_client().get(path, params=params)
        except (httpx.ConnectError, httpx.TimeoutException) as exc:
            raise PersonaleUnavailableError(str(exc)) from exc

        if not 200 <= response.status_code < 300:
            raise PersonaleAPIError(response.status_code, response.text)

        return response.json()

    def _ensure_http_client(self) -> httpx.AsyncClient:
        if self._http is None:
            self._http = httpx.AsyncClient(
                base_url=self.settings.base_url.rstrip("/"),
                timeout=5,
                transport=self._transport,
            )
        return self._http
