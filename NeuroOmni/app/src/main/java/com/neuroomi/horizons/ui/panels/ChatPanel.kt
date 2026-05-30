@file:OptIn(ExperimentalMaterial3Api::class)

package com.neuroomi.horizons.ui.panels

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.neuroomi.horizons.edge.EdgeModel
import com.neuroomi.horizons.model.ChatMessage
import com.neuroomi.horizons.model.FrontierProvider
import com.neuroomi.horizons.model.InstanceProfile
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

@Composable
fun ChatPanel(
    modifier: Modifier = Modifier,
    instanceProfile: InstanceProfile = InstanceProfile.Personal,
    activeProvider: FrontierProvider = FrontierProvider.VertexClaude,
    isEdgeMode: Boolean = false,
    onEdgeModeToggle: (Boolean) -> Unit = {},
    edgeModel: EdgeModel
) {
    var messages by remember { mutableStateOf<List<ChatMessage>>(emptyList()) }
    var inputText by remember { mutableStateOf("") }
    // Non-null while a stream is in flight; null otherwise
    var streamingContent by remember { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Scroll to the streaming item whenever a new token arrives
    LaunchedEffect(streamingContent) {
        if (streamingContent != null) listState.scrollToItem(messages.size)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        ProviderToggleRow(
            isEdgeMode = isEdgeMode,
            cloudProvider = activeProvider,
            onToggle = onEdgeModeToggle,
            accentColor = instanceProfile.accentColor
        )

        HorizontalDivider(color = MaterialTheme.colorScheme.outline)

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(messages, key = { it.id }) { msg ->
                MessageBubble(message = msg, accentColor = instanceProfile.accentColor)
            }
            // Streaming assistant message — shown while flow is in flight
            streamingContent?.let { partial ->
                item(key = "streaming") {
                    MessageBubble(
                        message = ChatMessage(
                            id = -1L,
                            role = ChatMessage.Role.Assistant,
                            content = partial
                        ),
                        accentColor = instanceProfile.accentColor,
                        isStreaming = true
                    )
                }
            }
        }

        HorizontalDivider(color = MaterialTheme.colorScheme.outline)

        InputRow(
            text = inputText,
            onTextChange = { inputText = it },
            enabled = streamingContent == null,
            onSend = {
                val prompt = inputText.trim()
                if (prompt.isEmpty()) return@InputRow
                messages = messages + ChatMessage(
                    id = System.currentTimeMillis(),
                    role = ChatMessage.Role.User,
                    content = prompt
                )
                inputText = ""
                scope.launch { listState.scrollToItem(messages.size - 1) }

                if (isEdgeMode) {
                    scope.launch {
                        var accumulated = ""
                        streamingContent = ""
                        edgeModel.generateStream(prompt).collect { token ->
                            accumulated += token
                            streamingContent = accumulated
                        }
                        // Commit completed response to the stable list
                        messages = messages + ChatMessage(
                            id = System.currentTimeMillis(),
                            role = ChatMessage.Role.Assistant,
                            content = accumulated.trim()
                        )
                        streamingContent = null
                    }
                }
            },
            accentColor = instanceProfile.accentColor
        )
    }
}

@Composable
private fun ProviderToggleRow(
    isEdgeMode: Boolean,
    cloudProvider: FrontierProvider,
    onToggle: (Boolean) -> Unit,
    accentColor: Color
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = if (isEdgeMode) FrontierProvider.Edge.displayName else cloudProvider.displayName,
            style = MaterialTheme.typography.labelSmall,
            color = if (isEdgeMode) accentColor else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Edge",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.width(6.dp))
            Switch(
                checked = isEdgeMode,
                onCheckedChange = onToggle,
                colors = SwitchDefaults.colors(
                    checkedThumbColor = accentColor,
                    checkedTrackColor = accentColor.copy(alpha = 0.4f)
                )
            )
        }
    }
}

@Composable
private fun MessageBubble(
    message: ChatMessage,
    accentColor: Color,
    isStreaming: Boolean = false
) {
    val isUser = message.role == ChatMessage.Role.User
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Surface(
            shape = RoundedCornerShape(
                topStart = 12.dp,
                topEnd = 12.dp,
                bottomStart = if (isUser) 12.dp else 2.dp,
                bottomEnd = if (isUser) 2.dp else 12.dp
            ),
            color = if (isUser) accentColor.copy(alpha = 0.18f)
                    else MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.widthIn(max = 300.dp)
        ) {
            // Trailing block cursor while streaming
            val display = if (isStreaming) "${message.content}▋" else message.content
            Text(
                text = display,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun InputRow(
    text: String,
    onTextChange: (String) -> Unit,
    enabled: Boolean,
    onSend: () -> Unit,
    accentColor: Color
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(8.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        OutlinedTextField(
            value = text,
            onValueChange = onTextChange,
            enabled = enabled,
            placeholder = {
                Text("Message…", color = MaterialTheme.colorScheme.onSurfaceVariant)
            },
            modifier = Modifier.weight(1f),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { onSend() }),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = accentColor,
                unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                cursorColor = accentColor,
                focusedTextColor = MaterialTheme.colorScheme.onSurface,
                unfocusedTextColor = MaterialTheme.colorScheme.onSurface
            ),
            maxLines = 4,
            shape = RoundedCornerShape(12.dp)
        )
        Spacer(Modifier.width(8.dp))
        FilledIconButton(
            onClick = onSend,
            enabled = enabled && text.isNotBlank(),
            colors = IconButtonDefaults.filledIconButtonColors(
                containerColor = accentColor,
                disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Icon(Icons.Filled.Send, contentDescription = "Send")
        }
    }
}
