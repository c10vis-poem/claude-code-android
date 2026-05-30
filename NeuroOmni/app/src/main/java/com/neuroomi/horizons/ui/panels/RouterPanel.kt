@file:OptIn(ExperimentalMaterial3Api::class)

package com.neuroomi.horizons.ui.panels

import androidx.compose.material3.ExperimentalMaterial3Api

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.neuroomi.horizons.model.FrontierProvider
import com.neuroomi.horizons.model.InstanceProfile

@Composable
fun RouterPanel(
    modifier: Modifier = Modifier,
    instanceProfile: InstanceProfile = InstanceProfile.Personal,
    activeProvider: FrontierProvider = FrontierProvider.VertexClaude,
    onProfileChange: (InstanceProfile) -> Unit = {},
    onProviderChange: (FrontierProvider) -> Unit = {}
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Instance Profile",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            InstanceProfile.entries.forEach { profile ->
                FilterChip(
                    selected = instanceProfile == profile,
                    onClick = { onProfileChange(profile) },
                    label = { Text(profile.displayName, style = MaterialTheme.typography.labelSmall) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = profile.accentColor.copy(alpha = 0.15f),
                        selectedLabelColor = profile.accentColor,
                        selectedLeadingIconColor = profile.accentColor
                    )
                )
            }
        }

        HorizontalDivider(color = MaterialTheme.colorScheme.outline)

        Text(
            "Active Provider",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            FrontierProvider.entries.forEach { provider ->
                ProviderRow(
                    provider = provider,
                    selected = activeProvider == provider,
                    accentColor = instanceProfile.accentColor,
                    onSelect = { onProviderChange(provider) }
                )
            }
        }
    }
}

@Composable
private fun ProviderRow(
    provider: FrontierProvider,
    selected: Boolean,
    accentColor: androidx.compose.ui.graphics.Color,
    onSelect: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = provider.displayName,
            style = MaterialTheme.typography.bodyLarge,
            color = if (selected) accentColor else MaterialTheme.colorScheme.onSurfaceVariant
        )
        RadioButton(
            selected = selected,
            onClick = onSelect,
            colors = RadioButtonDefaults.colors(selectedColor = accentColor)
        )
    }
}
