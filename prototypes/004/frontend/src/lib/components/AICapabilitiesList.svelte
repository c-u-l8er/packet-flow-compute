<script lang="ts">
	export let currentRoom: string = '';
	export let availableCapabilities: any[] = [];
	export let onCapabilitySelect: (capability: any) => void = () => {};
	export let onLoadCapabilities: () => void = () => {};
	
	let showDetails = false;
</script>

<div class="ai-capabilities-list h-full flex flex-col">
	<div class="flex-shrink-0 mb-4">
		<div class="flex items-center justify-between mb-3">
			<h3 class="font-semibold text-gray-800 text-sm">Available Capabilities</h3>
			<div class="flex gap-1">
				<button
					on:click={onLoadCapabilities}
					class="px-2 py-1 text-xs bg-green-600 text-white rounded hover:bg-green-700"
					title="Refresh capabilities"
				>
					↻
				</button>
				<button
					on:click={() => showDetails = !showDetails}
					class="px-2 py-1 text-xs bg-gray-600 text-white rounded hover:bg-gray-700"
				>
					{showDetails ? '▼' : '▶'}
				</button>
			</div>
		</div>
		
		<div class="text-xs text-gray-600 mb-3 p-2 bg-blue-50 rounded">
			<strong>How to use:</strong><br/>
			• Click capability names to insert commands<br/>
			• Use <code>/command</code> format in chat<br/>
			• Or use natural language with <code>ai:</code>, <code>ask:</code>, <code>@ai</code>
		</div>
	</div>
	
	{#if showDetails}
		<div class="flex-1 overflow-y-auto space-y-2">
			{#each availableCapabilities as capability}
				<div class="border border-gray-200 rounded-lg p-3 bg-white shadow-sm hover:border-gray-300 transition-colors">
					<div class="flex items-start justify-between mb-2">
						<div class="flex-1 min-w-0">
							<button
								on:click={() => onCapabilitySelect(capability)}
								class="font-medium text-blue-600 hover:text-blue-800 text-sm truncate block w-full text-left"
								title="Click to insert /{capability.id} command"
							>
								/{capability.id}
							</button>
							<p class="text-xs text-gray-600 mt-1 leading-relaxed">{capability.intent}</p>
						</div>
					</div>
					
					{#if capability.requires && capability.requires.length > 0}
						<div class="text-xs text-gray-500 mt-2 pt-2 border-t border-gray-100">
							<span class="font-medium">Required:</span> {capability.requires.join(', ')}
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
	{:else}
		<div class="flex-1 overflow-y-auto">
			<div class="grid grid-cols-1 gap-2">
				{#each availableCapabilities as capability}
					<button
						on:click={() => onCapabilitySelect(capability)}
						class="text-left p-2 text-sm bg-white border border-gray-200 rounded hover:border-blue-300 hover:bg-blue-50 transition-colors"
						title="Click to insert /{capability.id} command"
					>
						<div class="font-medium text-blue-600">/{capability.id}</div>
						<div class="text-xs text-gray-600 truncate">{capability.intent}</div>
					</button>
				{/each}
				
				{#if availableCapabilities.length === 0}
					<div class="text-center py-8">
						<p class="text-gray-500 text-sm mb-2">No capabilities loaded</p>
						<button
							on:click={onLoadCapabilities}
							class="text-blue-600 hover:text-blue-800 text-xs underline"
						>
							Click to load capabilities
						</button>
					</div>
				{/if}
			</div>
		</div>
	{/if}
	
	<!-- Quick Commands -->
	<div class="flex-shrink-0 mt-4 pt-4 border-t border-gray-200">
		<h4 class="font-medium text-gray-800 text-xs mb-2">Quick Commands</h4>
		<div class="grid grid-cols-1 gap-1">
			<button
				on:click={() => onCapabilitySelect({ id: 'help' })}
				class="text-left p-2 text-xs bg-gray-100 rounded hover:bg-gray-200 transition-colors"
			>
				<span class="font-mono text-blue-600">/help</span> - Show all capabilities
			</button>
			<button
				on:click={() => onCapabilitySelect({ id: 'ai: summarize recent messages' })}
				class="text-left p-2 text-xs bg-gray-100 rounded hover:bg-gray-200 transition-colors"
			>
				<span class="font-mono text-blue-600">ai: summarize</span> - Natural language
			</button>
		</div>
	</div>
</div>

<style>
	code {
		background-color: #f3f4f6;
		padding: 1px 4px;
		border-radius: 3px;
		font-size: 0.75rem;
	}
</style>