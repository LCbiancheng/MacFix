"""配置加载与持久化。

配置文件位置：~/Library/Application Support/MacFix/agent/config.json
API Key 只存本地，不上传 git。
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field


def app_support_dir() -> Path:
    p = Path.home() / "Library" / "Application Support" / "MacFix" / "agent"
    p.mkdir(parents=True, exist_ok=True)
    return p


def config_path() -> Path:
    return app_support_dir() / "config.json"


class Provider(BaseModel):
    base_url: str = "https://api.deepseek.com/v1"
    api_key: str = ""
    model: str = "deepseek-chat"


class AgentConfig(BaseModel):
    max_iterations: int = 12
    allow_shell: bool = True
    # confirm：危险命令需前端确认；allow：直接执行；deny：拒绝危险命令
    dangerous_command_policy: str = "confirm"


class Config(BaseModel):
    provider: str = "deepseek"  # 当前激活的供应商 key
    providers: dict[str, Provider] = Field(
        default_factory=lambda: {
            "deepseek": Provider(),
        }
    )
    agent: AgentConfig = Field(default_factory=AgentConfig)
    mcp_servers: list[dict[str, Any]] = Field(default_factory=list)

    @property
    def active(self) -> Provider:
        return self.providers.get(self.provider, self.providers["deepseek"])


def load_config() -> Config:
    path = config_path()
    data: dict[str, Any] = json.loads(Config().model_dump_json())
    if path.exists():
        try:
            data.update(json.loads(path.read_text(encoding="utf-8")))
        except Exception:
            pass
    return Config.model_validate(data)


def save_config(config: Config) -> None:
    config_path().write_text(config.model_dump_json(indent=2), encoding="utf-8")