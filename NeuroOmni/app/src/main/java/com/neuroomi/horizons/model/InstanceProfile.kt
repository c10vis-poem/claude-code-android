package com.neuroomi.horizons.model

import androidx.compose.ui.graphics.Color
import com.neuroomi.horizons.ui.theme.ProfileBlue
import com.neuroomi.horizons.ui.theme.ProfileRed
import com.neuroomi.horizons.ui.theme.ProfileYellow

enum class InstanceProfile(val displayName: String, val accentColor: Color) {
    Personal("Personal", ProfileBlue),
    RedAgent("Red Agent", ProfileRed),
    Collab("Collab", ProfileYellow)
}
