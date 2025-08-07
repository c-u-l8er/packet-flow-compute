<script lang="ts">
	import { authStore } from '$lib/stores/auth';
	
	// Props passed from parent component
	export let currentRoom: string = '';
	export let publicRooms: any[] = [];
	export let privateRooms: any[] = [];
	export let onSendMessage: (content: string) => void = () => {};
	
	let aiInput = '';
	let aiResponse = '';
	let isProcessing = false;
	let availableCapabilities: any[] = [];
	let showCapabilities = false;
	let executionHistory: any[] = [];
	let capabilityInputs: { [key: string]: any } = {};
	
	$: user = $authStore.user;
	$: token = $authStore.token;
	$: allRooms = [...publicRooms, ...privateRooms];
	$: currentRoomData = allRooms.find(r => r.id === currentRoom);
	
	async function processNaturalLanguage() {
		if (!aiInput.trim() || !token) return;
		
		if (!currentRoom) {
			aiResponse = 'Please select a room first to use AI assistance.';
			return;
		}
		
		isProcessing = true;
		aiResponse = '🤖 Processing your request...';
		
		// Send user's question to chat first
		onSendMessage(`**Question for AI**: ${aiInput}`);
		
		// Show AI is thinking
		onSendMessage(`🤖 **AI Assistant**: Thinking...`);
		
		const userInput = aiInput;
		aiInput = ''; // Clear input immediately for better UX
		
		try {
			const response = await fetch('/api/ai/natural', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'Authorization': `Bearer ${token}`
				},
				body: JSON.stringify({
					message: userInput,
					context: {
						user_id: user?.id,
						room_id: currentRoom,
						room_name: currentRoomData?.name,
						timestamp: new Date().toISOString()
					}
				})
			});
			
			const result = await response.json();
			
			if (result.success) {
				// Send AI response to chat
				const chatMessage = `🤖 **AI Assistant**: ${result.message}`;
				onSendMessage(chatMessage);
				
				aiResponse = '✅ AI response sent to chat.';
				executionHistory = [
					{
						input: userInput,
						result: result,
						timestamp: new Date().toISOString()
					},
					...executionHistory.slice(0, 4) // Keep last 5 entries
				];
			} else {
				const errorMessage = `🤖 **AI Assistant**: ❌ ${result.message || 'Sorry, I encountered an error processing your request.'}`;
				onSendMessage(errorMessage);
				aiResponse = 'Error sent to chat.';
			}
		} catch (error) {
			console.error('AI processing error:', error);
			const errorMessage = `🤖 **AI Assistant**: ❌ Sorry, I couldn't process your request. Please try again.`;
			onSendMessage(errorMessage);
			aiResponse = 'Network error - see chat for details.';
		} finally {
			isProcessing = false;
		}
	}
	
	async function loadCapabilities() {
		if (!token) return;
		
		try {
			const response = await fetch('/api/ai/capabilities', {
				headers: {
					'Authorization': `Bearer ${token}`
				}
			});
			
			const result = await response.json();
			
			if (result.success) {
				availableCapabilities = result.capabilities;
			}
		} catch (error) {
			console.error('Failed to load capabilities:', error);
		}
	}
	
	async function executeCapability(capabilityId: string) {
		if (!token || !currentRoom) {
			aiResponse = 'Please select a room first and ensure you are logged in.';
			return;
		}
		
		const capability = availableCapabilities.find(c => c.id === capabilityId);
		if (!capability) return;
		
		// Show that we're processing
		isProcessing = true;
		aiResponse = `🤖 Executing ${capability.id}...`;
		
		// Build payload with required parameters
		const payload: any = {
			room_id: currentRoom,
			user_id: user?.id
		};
		
		// Add additional required parameters based on capability requirements
		if (capability.requires) {
			for (const requirement of capability.requires) {
				if (requirement === 'content') {
					const userInput = capabilityInputs[capabilityId]?.content;
					if (userInput && userInput.trim()) {
						payload.content = userInput.trim();
					} else {
						// Require content input for content-dependent capabilities
						aiResponse = `❌ Please provide content for the "${capabilityId}" capability.`;
						isProcessing = false;
						return;
					}
				} else if (requirement === 'message_count') {
					payload.message_count = capabilityInputs[capabilityId]?.message_count || 20;
				} else if (requirement === 'time_period') {
					payload.time_period = capabilityInputs[capabilityId]?.time_period || '1h';
				} else if (requirement === 'message_content') {
					// Don't provide a fallback - let the backend handle conversation context
					payload.message_content = capabilityInputs[capabilityId]?.message_content || '';
				} else if (requirement === 'conversation_context') {
					payload.conversation_context = { room_id: currentRoom };
				}
			}
		}
		
		try {
			const response = await fetch(`/api/ai/capability/${capabilityId}`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'Authorization': `Bearer ${token}`
				},
				body: JSON.stringify({
					payload,
					context: { user_id: user?.id }
				})
			});
			
			const result = await response.json();
			
			if (result.success) {
				// Update local response - the backend now handles sending to chat
				aiResponse = `✅ Capability "${capabilityId}" executed successfully. Check the chat for results.`;
				
				// Add to execution history
				executionHistory = [
					{
						input: `Executed capability: ${capabilityId}`,
						result: result,
						timestamp: new Date().toISOString()
					},
					...executionHistory.slice(0, 4) // Keep last 5 entries
				];
			} else {
				// Backend handles error messages too
				aiResponse = `❌ Failed to execute capability "${capabilityId}": ${result.error}`;
			}
		} catch (error: any) {
			console.error('Capability execution error:', error);
			aiResponse = `Network error executing "${capabilityId}": ${error.message || 'Unknown error'}`;
		} finally {
			isProcessing = false;
		}
	}
	
	function handleKeyPress(event: KeyboardEvent) {
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			processNaturalLanguage();
		}
	}
</script>

<div class="ai-interface h-full flex flex-col p-4">
	<div class="flex-shrink-0 border-b border-gray-200 pb-4 mb-4">
		<h2 class="text-lg font-bold text-gray-800 mb-1">
			🤖 AI Assistant
		</h2>
		{#if currentRoomData}
			<p class="text-xs text-gray-600">for #{currentRoomData.name}</p>
		{/if}
	</div>
	
	<!-- Natural Language Interface -->
	<div class="flex-shrink-0 mb-4">
		<label for="ai-input" class="block text-xs font-medium text-gray-700 mb-2">
			Ask me anything about your chat:
		</label>
		<div class="space-y-2">
			<textarea
				id="ai-input"
				bind:value={aiInput}
				on:keypress={handleKeyPress}
				placeholder={currentRoom ? `Analyze ${currentRoomData?.name || 'this room'}...` : "Select a room first"}
				class="w-full p-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
				rows="3"
				disabled={isProcessing}
			></textarea>
			<button
				on:click={processNaturalLanguage}
				disabled={isProcessing || !aiInput.trim() || !currentRoom}
				class="w-full px-3 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
				title={!currentRoom ? 'Select a room first' : 'Send question to AI'}
			>
				{isProcessing ? '🤔 Processing...' : '✨ Ask AI'}
			</button>
		</div>
	</div>
	
	<!-- AI Response -->
	{#if aiResponse}
		<div class="flex-shrink-0 mb-4 p-3 bg-white rounded-md border border-gray-200">
			<h3 class="font-semibold text-gray-800 mb-2 text-sm">AI Response:</h3>
			<div class="text-xs text-gray-700 whitespace-pre-wrap max-h-32 overflow-y-auto">{aiResponse}</div>
		</div>
	{/if}
	
	<!-- Capabilities Section -->
	<div class="flex-1 flex flex-col overflow-hidden">
		<div class="flex-shrink-0 border-t pt-4">
			<div class="flex items-center justify-between mb-3">
				<h3 class="font-semibold text-gray-800 text-sm">Capabilities</h3>
				<div class="flex gap-1">
					<button
						on:click={loadCapabilities}
						class="px-2 py-1 text-xs bg-green-600 text-white rounded hover:bg-green-700"
						title="Refresh capabilities"
					>
						↻
					</button>
					<button
						on:click={() => showCapabilities = !showCapabilities}
						class="px-2 py-1 text-xs bg-gray-600 text-white rounded hover:bg-gray-700"
					>
						{showCapabilities ? '▼' : '▶'}
					</button>
				</div>
			</div>
			
			{#if showCapabilities}
				<div class="flex-1 overflow-y-auto space-y-3 pr-1" style="max-height: calc(100vh - 400px);">
					{#each availableCapabilities as capability}
						<div class="border border-gray-200 rounded-lg p-3 bg-white shadow-sm hover:border-gray-300 transition-colors">
							<div class="flex items-start justify-between mb-2">
								<div class="flex-1 min-w-0">
									<h4 class="font-medium text-gray-800 text-sm truncate" title={capability.id}>
										{capability.id}
									</h4>
									<p class="text-xs text-gray-600 mt-1 leading-relaxed">{capability.intent}</p>
								</div>
								<button
									on:click={() => executeCapability(capability.id)}
									disabled={isProcessing || !currentRoom}
									class="ml-2 px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700 flex-shrink-0 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
									title={!currentRoom ? 'Select a room first' : 'Execute capability'}
								>
									{isProcessing ? '⏳' : '▶️'} Run
								</button>
							</div>
							
							<!-- Dynamic input fields for capabilities that need extra parameters -->
							{#if capability.requires && capability.requires.length > 0}
								<div class="space-y-2 mt-3 pt-2 border-t border-gray-100">
									{#if capability.requires.includes('content')}
										{@const inputId = capability.id}
										{#if !capabilityInputs[inputId]}
											{@const _ = (capabilityInputs[inputId] = {})}
										{/if}
										<div>
											<label for="content-{capability.id}" class="block text-xs font-medium text-gray-700 mb-1">Message Content:</label>
											<input
												id="content-{capability.id}"
												type="text"
												placeholder="Enter message content..."
												bind:value={capabilityInputs[inputId].content}
												class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
											/>
										</div>
									{/if}
									
									{#if capability.requires.includes('message_count')}
										{@const inputId = capability.id}
										{#if !capabilityInputs[inputId]}
											{@const _ = (capabilityInputs[inputId] = { message_count: 20 })}
										{/if}
										<div>
											<label for="count-{capability.id}" class="block text-xs font-medium text-gray-700 mb-1">Message Count:</label>
											<input
												id="count-{capability.id}"
												type="number"
												placeholder="20"
												min="1"
												max="100"
												bind:value={capabilityInputs[inputId].message_count}
												class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
											/>
										</div>
									{/if}
									
									{#if capability.requires.includes('time_period')}
										{@const inputId = capability.id}
										{#if !capabilityInputs[inputId]}
											{@const _ = (capabilityInputs[inputId] = { time_period: '1h' })}
										{/if}
										<div>
											<label for="time-{capability.id}" class="block text-xs font-medium text-gray-700 mb-1">Time Period:</label>
											<select
												id="time-{capability.id}"
												bind:value={capabilityInputs[inputId].time_period}
												class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
											>
												<option value="1h">1 hour</option>
												<option value="6h">6 hours</option>
												<option value="1d">1 day</option>
												<option value="1w">1 week</option>
											</select>
										</div>
									{/if}
									
									<div class="text-xs text-gray-500 pt-1">
										<span class="font-medium">Required:</span> {capability.requires.join(', ')}
									</div>
								</div>
							{:else}
								<div class="text-xs text-gray-500 mt-2 pt-2 border-t border-gray-100">
									<span class="font-medium">Required:</span> None
								</div>
							{/if}
						</div>
					{/each}
					
					{#if availableCapabilities.length === 0}
						<div class="text-center py-8">
							<p class="text-gray-500 text-sm mb-2">No capabilities loaded</p>
							<p class="text-gray-400 text-xs">Click the refresh button (↻) to load available capabilities</p>
						</div>
					{/if}
				</div>
			{/if}
		</div>
		
		<!-- Execution History -->
		{#if executionHistory.length > 0}
			<div class="flex-shrink-0 border-t pt-3 mt-3">
				<h3 class="font-semibold text-gray-800 mb-2 text-sm">Recent Interactions</h3>
				<div class="space-y-2 max-h-40 overflow-y-auto pr-1">
					{#each executionHistory as entry}
						<div class="text-xs border border-gray-200 rounded-lg p-2 bg-white shadow-sm">
							<div class="font-medium text-gray-700 line-clamp-2 mb-1">"{entry.input}"</div>
							<div class="text-gray-500 text-xs">
								{new Date(entry.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
							</div>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>