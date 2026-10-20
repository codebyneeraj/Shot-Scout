from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_no_app_key_set_means_open(monkeypatch):
    monkeypatch.delenv("APP_KEY", raising=False)
    assert client.post("/scene-images", json={"scenes": []}).status_code == 422  # reaches validation


def test_app_key_required_when_set(monkeypatch):
    monkeypatch.setenv("APP_KEY", "secret")
    assert client.post("/scene-images", json={"scenes": []}).status_code == 401
    assert client.post("/scene-images", json={"scenes": []}, headers={"x-app-key": "wrong"}).status_code == 401
    assert client.post("/scene-images", json={"scenes": []}, headers={"x-app-key": "secret"}).status_code == 422
    assert client.get("/health").status_code == 200  # wake-up pings need no key
