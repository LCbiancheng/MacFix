"""FastAPI 服务：提供 /health 与 /chat（SSE 流式）。

Phase 0：纯对话（无工具）。Phase 1 起由 LangGraph Agent 接管。
"""
from __future__ import annotations

import json
import uuid
from collections.abc import AsyncIterator

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from .config import load_config
from .llm import build_chat_model

SYSTEM_PROMPT = (
    "你是 MacFix 智能助手，擅长诊断并解决 macOS 常见问题。"
    "回答应简洁、准确、可执行；涉及系统操作时先说明影响。"
)

app = FastAPI(title="MacFix Agent")


class ChatRequest(BaseModel):
    session_id: str | None = None
    message: str


def _sse(event: str, data: dict | str) -> str:
    payload = data if isinstance(data, str) else json.dumps(data, ensure_ascii=False)
    return f"event: {event}\ndata: {payload}\n\n"


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/chat")
async def chat(req: ChatRequest) -> StreamingResponse:
    try:
        config = load_config()
        model = build_chat_model(config)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(e)) from e

    session_id = req.session_id or uuid.uuid4().hex
    messages = [
        ("system", SYSTEM_PROMPT),
        ("human", req.message),
    ]

    async def gen() -> AsyncIterator[str]:
        yield _sse("meta", {"session_id": session_id})
        try:
            async for chunk in model.astream(messages):
                text = chunk.content
                if text:
                    yield _sse("token", {"text": text})
        except Exception as e:  # noqa: BLE001
            yield _sse("error", {"message": str(e)})
            return
        yield _sse("done", {})

    return StreamingResponse(gen(), media_type="text/event-stream")