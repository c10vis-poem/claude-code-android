package com.neuroomi.horizons.model

// Flat enum for UI state — will be replaced by sealed class with auth params in Prompt 2.2
enum class FrontierProvider(val displayName: String) {
    Edge("Edge (OmniNeural)"),
    AnthropicDirect("Anthropic Direct"),
    VertexClaude("Vertex Claude"),
    VertexGemini("Vertex Gemini"),
    AIStudioGemini("AI Studio Gemini"),
    ClaudeCodeCLI("Claude Code CLI"),
    GeminiCLI("Gemini CLI")
}
