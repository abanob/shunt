import httpx
import pytest

import gateway


class FakeResponse:
    def __init__(self, data, status=200):
        self._data = data
        self.status_code = status
        self.text = str(data)

    def raise_for_status(self):
        if self.status_code >= 400:
            raise httpx.HTTPStatusError("bad", request=None, response=self)

    def json(self):
        return self._data


class FakeClient:
    def __init__(self, response=None, exc=None):
        self.response = response
        self.exc = exc
        self.calls = []

    def post(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if self.exc:
            raise self.exc
        return self.response

    def get(self, url, **kwargs):
        return self.post(url, **kwargs)


@pytest.fixture(autouse=True)
def clean_env(monkeypatch):
    for name in ("PRIVATE_SAFE_GROUPS", "LLM_GATEWAY_URL", "LLM_GATEWAY_KEY", "LITELLM_MASTER_KEY"):
        monkeypatch.delenv(name, raising=False)


def test_private_refused_by_default():
    # Arrange
    client = FakeClient()

    # Act
    result = gateway.ask("secret", "fast", private=True, client=client)

    # Assert
    assert result.startswith("Refused")
    assert "PRIVATE_SAFE_GROUPS" in result
    assert client.calls == []


def test_private_allowed_for_listed_group(monkeypatch):
    # Arrange
    monkeypatch.setenv("PRIVATE_SAFE_GROUPS", " code , fast ")
    client = FakeClient(FakeResponse({"model": "m", "choices": [{"message": {"content": "ok"}}]}))

    # Act
    result = gateway.ask("secret", "code", private=True, client=client)

    # Assert
    assert result == "ok\n\n[answered by: m]"


def test_private_refused_for_unlisted_group(monkeypatch):
    # Arrange
    monkeypatch.setenv("PRIVATE_SAFE_GROUPS", "code")

    # Act
    result = gateway.ask("secret", "fast", private=True, client=FakeClient())

    # Assert
    assert result.startswith("Refused")


def test_build_payload_includes_system_and_max_tokens():
    # Arrange
    expected = {
        "model": "fast",
        "messages": [{"role": "system", "content": "s"}, {"role": "user", "content": "p"}],
        "max_tokens": 5,
    }

    # Act
    payload = gateway.build_payload("p", "fast", "s", 5)

    # Assert
    assert payload == expected


def test_ask_sends_auth_and_reports_model(monkeypatch):
    # Arrange
    monkeypatch.setenv("LLM_GATEWAY_KEY", "k")
    client = FakeClient(FakeResponse({"model": "groq/x", "choices": [{"message": {"content": "hi"}}]}))

    # Act
    result = gateway.ask("p", client=client)

    # Assert
    url, kwargs = client.calls[0]
    assert url == "http://localhost:4000/v1/chat/completions"
    assert kwargs["headers"] == {"Authorization": "Bearer k"}
    assert "groq/x" in result


def test_proxy_down_message():
    # Arrange
    client = FakeClient(exc=httpx.ConnectError("refused"))

    # Act
    result = gateway.ask("p", client=client)

    # Assert
    assert "not reachable" in result


def test_http_error_message():
    # Arrange
    client = FakeClient(FakeResponse("rate limited", status=429))

    # Act
    result = gateway.ask("p", client=client)

    # Assert
    assert "429" in result


def test_groups_sorted_unique():
    # Arrange
    client = FakeClient(FakeResponse({"data": [{"id": "fast"}, {"id": "code"}, {"id": "fast"}]}))

    # Act
    result = gateway.groups(client=client)

    # Assert
    assert result == ["code", "fast"]
