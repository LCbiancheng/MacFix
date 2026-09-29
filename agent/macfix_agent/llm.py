"""LLM 供应商抽象。

基于 langchain-openai 的 ChatOpenAI，通过 base_url 指向不同厂家的 OpenAI 兼容端点。
"""
from __future__ import annotations

from langchain_openai import ChatOpenAI

from .config import Config


def build_chat_model(config: Config) -> ChatOpenAI:
    provider = config.active
    if not provider.api_key:
        raise ValueError(
            f"供应商「{config.provider}」尚未配置 API Key，请在应用设置中填写。"
        )
    return ChatOpenAI(
        model=provider.model,
        base_url=provider.base_url,
        api_key=provider.api_key,
        temperature=0.3,
        streaming=True,
    )