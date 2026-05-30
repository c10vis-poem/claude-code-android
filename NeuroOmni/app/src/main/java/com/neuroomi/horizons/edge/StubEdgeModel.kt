package com.neuroomi.horizons.edge

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

// No-dependency stand-in so CI and emulators run with no model file and no token.
// Swap in OmniNeural (or any other EdgeModel impl) without touching this file.
class StubEdgeModel : EdgeModel {

    override suspend fun initialize(): Result<Unit> = Result.success(Unit)

    override fun generateStream(prompt: String): Flow<String> = flow {
        val tokens = "[ StubEdgeModel ] No model loaded. " +
            "Swap in OmniNeural via the EdgeModel interface. " +
            "Received: \"$prompt\""
        tokens.split(" ").forEach { token ->
            emit("$token ")
            delay(55L)
        }
    }

    override fun release() = Unit
}
