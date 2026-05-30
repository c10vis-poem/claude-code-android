package com.neuroomi.horizons.model

data class ChatMessage(
    val id: Long,
    val role: Role,
    val content: String,
    val providerLabel: String = ""
) {
    enum class Role { User, Assistant }
}
