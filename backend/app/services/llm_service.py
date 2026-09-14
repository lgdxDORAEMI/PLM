from abc import ABC, abstractmethod

from app.core.config import Settings


class LLMService(ABC):
    """업체별 구현은 이 인터페이스를 상속한다."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    @abstractmethod
    async def generate(self, prompt: str) -> str:
        raise NotImplementedError
