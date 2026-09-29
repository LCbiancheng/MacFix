"""uvicorn 启动入口。

运行：uv run python -m macfix_agent
"""
from __future__ import annotations

import uvicorn


def main() -> None:
    uvicorn.run(
        "macfix_agent.server:app",
        host="127.0.0.1",
        port=8765,
        log_level="info",
    )


if __name__ == "__main__":
    main()