from mcp.server.mcpserver import MCPServer

import gateway

mcp = MCPServer("llm-gateway")


@mcp.tool()
def ask_model(
    prompt: str,
    group: str = "fast",
    system: str | None = None,
    max_tokens: int | None = None,
    private: bool = False,
) -> str:
    return gateway.ask(prompt, group, system, max_tokens, private)


@mcp.tool()
def list_models() -> str:
    result = gateway.groups()
    return result if isinstance(result, str) else "\n".join(result)


if __name__ == "__main__":
    mcp.run(transport="stdio")
