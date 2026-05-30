package com.neuroomi.horizons

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.neuroomi.horizons.edge.EdgeModel
import com.neuroomi.horizons.edge.StubEdgeModel
import com.neuroomi.horizons.model.FrontierProvider
import com.neuroomi.horizons.model.InstanceProfile
import com.neuroomi.horizons.ui.panels.ChatPanel
import com.neuroomi.horizons.ui.panels.DiagnosticsPanel
import com.neuroomi.horizons.ui.panels.RouterPanel
import com.neuroomi.horizons.ui.panels.TerminalPanel

private enum class Panel { Chat, Router, Terminal, Diagnostics }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HorizonsApp() {
    var selectedPanel  by remember { mutableStateOf(Panel.Chat) }
    var instanceProfile by remember { mutableStateOf(InstanceProfile.Personal) }
    var activeProvider  by remember { mutableStateOf(FrontierProvider.VertexClaude) }
    var isEdgeMode      by remember { mutableStateOf(false) }

    // EdgeModel lives here so it survives panel navigation.
    // Replace StubEdgeModel with OmniNeural (or any EdgeModel impl) in one line.
    val edgeModel: EdgeModel = remember { StubEdgeModel() }
    LaunchedEffect(edgeModel) { edgeModel.initialize() }
    DisposableEffect(edgeModel) { onDispose { edgeModel.release() } }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Horizons",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                },
                actions = {
                    FilterChip(
                        selected = true,
                        onClick = {
                            instanceProfile = when (instanceProfile) {
                                InstanceProfile.Personal -> InstanceProfile.RedAgent
                                InstanceProfile.RedAgent -> InstanceProfile.Collab
                                InstanceProfile.Collab   -> InstanceProfile.Personal
                            }
                        },
                        label = {
                            Text(
                                instanceProfile.displayName,
                                style = MaterialTheme.typography.labelSmall
                            )
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = instanceProfile.accentColor.copy(alpha = 0.15f),
                            selectedLabelColor = instanceProfile.accentColor
                        ),
                        modifier = Modifier.padding(end = 8.dp)
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                tonalElevation = 0.dp
            ) {
                val navColors = NavigationBarItemDefaults.colors(
                    selectedIconColor   = instanceProfile.accentColor,
                    selectedTextColor   = instanceProfile.accentColor,
                    indicatorColor      = instanceProfile.accentColor.copy(alpha = 0.12f),
                    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                )
                NavigationBarItem(
                    selected = selectedPanel == Panel.Chat,
                    onClick  = { selectedPanel = Panel.Chat },
                    icon     = { Icon(Icons.Default.Chat,      contentDescription = null) },
                    label    = { Text("Chat") },
                    colors   = navColors
                )
                NavigationBarItem(
                    selected = selectedPanel == Panel.Router,
                    onClick  = { selectedPanel = Panel.Router },
                    icon     = { Icon(Icons.Default.Tune,      contentDescription = null) },
                    label    = { Text("Router") },
                    colors   = navColors
                )
                NavigationBarItem(
                    selected = selectedPanel == Panel.Terminal,
                    onClick  = { selectedPanel = Panel.Terminal },
                    icon     = { Icon(Icons.Default.Code,      contentDescription = null) },
                    label    = { Text("Terminal") },
                    colors   = navColors
                )
                NavigationBarItem(
                    selected = selectedPanel == Panel.Diagnostics,
                    onClick  = { selectedPanel = Panel.Diagnostics },
                    icon     = { Icon(Icons.Default.Analytics, contentDescription = null) },
                    label    = { Text("Diag") },
                    colors   = navColors
                )
            }
        }
    ) { innerPadding ->
        when (selectedPanel) {
            Panel.Chat -> ChatPanel(
                modifier        = Modifier.padding(innerPadding),
                instanceProfile = instanceProfile,
                activeProvider  = activeProvider,
                isEdgeMode      = isEdgeMode,
                onEdgeModeToggle = { isEdgeMode = it },
                edgeModel       = edgeModel
            )
            Panel.Router -> RouterPanel(
                modifier        = Modifier.padding(innerPadding),
                instanceProfile = instanceProfile,
                activeProvider  = activeProvider,
                onProfileChange  = { instanceProfile = it },
                onProviderChange = { activeProvider = it }
            )
            Panel.Terminal -> TerminalPanel(
                modifier = Modifier.padding(innerPadding)
            )
            Panel.Diagnostics -> DiagnosticsPanel(
                modifier = Modifier.padding(innerPadding)
            )
        }
    }
}
