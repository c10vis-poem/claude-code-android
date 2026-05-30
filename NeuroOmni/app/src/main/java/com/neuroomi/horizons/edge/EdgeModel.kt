package com.neuroomi.horizons.edge

import kotlinx.coroutines.flow.Flow

interface EdgeModel {
    suspend fun initialize(): Result<Unit>
    fun generateStream(prompt: String): Flow<String>
    fun release()
}
