<script lang="ts">
	import { onMount } from 'svelte';
	import { Socket } from 'phoenix';
	import { authStore } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { APP_NAME } from '$lib/config';
	import AICapabilitiesList from '$lib/components/AICapabilitiesList.svelte';
	
	let socket: Socket | null = null;
	let channel: any = null;
	let messages: any[] = [];
	let newMessage = '';
	let currentRoom = '';
	let isConnected = false;
	let publicRooms: any[] = [];
	let privateRooms: any[] = [];
	let showCreateRoom = false;
	let newRoomName = '';
	let newRoomDescription = '';
	let isPrivateRoom = false;
	let roomMembers: any[] = [];
	let showParticipants = false;
	let showInviteModal = false;
	let showCreatePrivateRoom = false;
	let searchQuery = '';
	let searchResults: any[] = [];
	let selectedUsers: any[] = [];
	let privateRoomName = '';
	let privateRoomDescription = '';
	let showDeleteConfirmation = false;
	let isCreatingRoom = false;
	let showAICapabilities = false;
	let availableCapabilities: any[] = [];
	let isProcessingAI = false;
	
	$: user = $authStore.user;
	$: token = $authStore.token;
	$: isLoading = $authStore.isLoading;
	$: canManage = user && currentRoom && publicRooms && privateRooms && roomMembers ? canManageRoom() : false;
	

	
	onMount(async () => {
		await authStore.initialize();
		
		// Redirect to login if not authenticated
		if (!$authStore.user && !$authStore.isLoading) {
			goto('/login');
			return;
		}
		
		if ($authStore.user && $authStore.token) {
			await loadRooms();
			initializeSocket();
		}
	});
	
	// Reactive statement to handle auth state changes
	$: if (!isLoading && !user) {
		goto('/login');
	}
	
	// Only initialize socket and load rooms once when user and token are available
	// and socket is not yet initialized
	$: if (user && token && !socket && !isLoading) {
		initializeSocketAndRooms();
	}
	
	async function initializeSocketAndRooms() {
		// Prevent multiple calls by checking if socket already exists
		if (socket) return;
		
		await loadRooms();
		initializeSocket();
	}
	
	function initializeSocket() {
		if (!token || !user) return;
		
		// Initialize Phoenix Socket
		socket = new Socket('ws://localhost:4000/socket', {
			params: { token: token }
		});
		
		socket.connect();
		
		socket.onOpen(() => {
			console.log('Connected to server');
			isConnected = true;
		});
		
		socket.onError((error) => {
			console.error('Socket error:', error);
			isConnected = false;
		});
		
		socket.onClose(() => {
			console.log('Disconnected from server');
			isConnected = false;
		});
		
		// Join the first available room if none selected
		const allRooms = [...publicRooms, ...privateRooms];
		if (!currentRoom && allRooms.length > 0) {
			currentRoom = allRooms[0].id;
		}
		
		if (currentRoom) {
			joinRoom(currentRoom);
		}
	}
	
	function joinRoom(roomId: string) {
		if (channel) {
			channel.leave();
		}
		
		if (!socket) return;
		
		channel = socket.channel(`room:${roomId}`, {});
		
		channel.join()
			.receive('ok', (resp: any) => {
				console.log('Joined room successfully', resp);
				currentRoom = roomId;
				loadRoomMembers();
			})
			.receive('error', (resp: any) => {
				console.error('Unable to join room', resp);
			});
		
		// Listen for messages
		channel.on('message_received', (payload: any) => {
			messages = [...messages, payload];
			scrollToBottom();
		});
		
		channel.on('messages_loaded', (payload: any) => {
			messages = payload.messages || [];
			scrollToBottom();
		});
		
		channel.on('members_updated', (payload: any) => {
			roomMembers = payload.members || [];
		});
		
		channel.on('user_joined', (payload: any) => {
			console.log('User joined:', payload);
			// Add user to members list if not already present
			if (payload.user && !roomMembers.find(m => m.user_id === payload.user.id)) {
				roomMembers = [...roomMembers, {
					user_id: payload.user.id,
					username: payload.user.username,
					avatar_url: payload.user.avatar_url,
					role: 'member',
					joined_at: payload.timestamp
				}];
			}
		});
		
		channel.on('user_left', (payload: any) => {
			console.log('User left:', payload);
			// Remove user from members list
			if (payload.user) {
				roomMembers = roomMembers.filter(m => m.user_id !== payload.user.id);
			}
		});
		
		channel.on('typing_indicator', (payload: any) => {
			console.log('Typing indicator:', payload);
		});
	}
	
	function sendMessage() {
		if (!newMessage.trim() || !channel) return;
		
		const content = newMessage.trim();
		
		// Check if this is an AI command or natural language request
		if (isAICommand(content)) {
			handleAICommand(content);
		} else {
			// Regular message
			channel.push('send_message', {
				content: content,
				message_type: 'text'
			})
			.receive('ok', (resp: any) => {
				console.log('Message sent', resp);
				newMessage = '';
			})
			.receive('error', (resp: any) => {
				console.error('Error sending message', resp);
			});
		}
	}
	
	function isAICommand(content: string): boolean {
		// Check for capability commands (start with /)
		if (content.startsWith('/')) {
			return true;
		}
		
		// Check for natural language AI triggers
		const aiTriggers = ['ai:', 'ask:', 'analyze:', 'summarize:', 'help:', '@ai', '@assistant'];
		return aiTriggers.some(trigger => content.toLowerCase().startsWith(trigger));
	}

	function extractCommandAndContent(content: string): { commandType: string, cleanContent: string } {
		const lowerContent = content.toLowerCase();
		
		if (lowerContent.startsWith('analyze:')) {
			return {
				commandType: 'analyze',
				cleanContent: content.replace(/^analyze:\s*/i, '')
			};
		} else if (lowerContent.startsWith('summarize:')) {
			return {
				commandType: 'summarize',
				cleanContent: content.replace(/^summarize:\s*/i, '')
			};
		} else if (lowerContent.startsWith('ai:')) {
			return {
				commandType: 'ai',
				cleanContent: content.replace(/^ai:\s*/i, '')
			};
		} else if (lowerContent.startsWith('ask:')) {
			return {
				commandType: 'ask',
				cleanContent: content.replace(/^ask:\s*/i, '')
			};
		} else if (lowerContent.startsWith('@ai') || lowerContent.startsWith('@assistant')) {
			return {
				commandType: 'ai',
				cleanContent: content.replace(/^(@ai|@assistant)\s*/i, '')
			};
		} else {
			return {
				commandType: 'general',
				cleanContent: content
			};
		}
	}
	
	async function handleAICommand(content: string) {
		if (!token || !currentRoom) return;
		
		isProcessingAI = true;
		
		// Display the user's command in chat
		channel.push('send_message', {
			content: content,
			message_type: 'ai_command'
		});
		
		// Show AI is processing
		channel.push('send_message', {
			content: '🤖 **AI Assistant**: Processing your request...',
			message_type: 'ai_response'
		});
		
		try {
			if (content.startsWith('/')) {
				// Handle capability command
				await handleCapabilityCommand(content);
			} else {
				// Handle natural language request
				await handleNaturalLanguageRequest(content);
			}
		} catch (error: any) {
			console.error('AI command error:', error);
			channel.push('send_message', {
				content: '🤖 **AI Assistant**: ❌ Sorry, I encountered an error processing your request.',
				message_type: 'ai_response'
			});
		} finally {
			isProcessingAI = false;
			newMessage = '';
		}
	}
	
	async function handleCapabilityCommand(content: string) {
		const parts = content.slice(1).split(' '); // Remove '/' and split
		const capabilityId = parts[0];
		const args = parts.slice(1).join(' ');
		
		// Handle built-in commands first
		if (capabilityId === 'help') {
			await handleNaturalLanguageRequest('help');
			return;
		}
		
		const capability = availableCapabilities.find(c => c.id === capabilityId);
		if (!capability) {
			channel.push('send_message', {
				content: `🤖 **AI Assistant**: ❌ Unknown capability "${capabilityId}". Type "/help" to see available capabilities.`,
				message_type: 'ai_response'
			});
			return;
		}
		
		// Build payload for capability execution
		const payload: any = {
			room_id: currentRoom,
			user_id: user?.id
		};
		
		// Add content if provided
		if (args.trim()) {
			payload.content = args.trim();
		}
		
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
			// The backend handles sending the result to chat
		} else {
			channel.push('send_message', {
				content: `🤖 **AI Assistant**: ❌ Failed to execute "${capabilityId}": ${result.error}`,
				message_type: 'ai_response'
			});
		}
	}
	
	async function handleNaturalLanguageRequest(content: string) {
		// Extract command type and clean content
		const { commandType, cleanContent } = extractCommandAndContent(content);
		
		const response = await fetch('/api/ai/natural', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${token}`
			},
			body: JSON.stringify({
				message: cleanContent,
				context: {
					user_id: user?.id,
					room_id: currentRoom,
					room_name: [...publicRooms, ...privateRooms].find(r => r.id === currentRoom)?.name,
					timestamp: new Date().toISOString(),
					command_type: commandType
				}
			})
		});
		
		const result = await response.json();
		
		if (result.success) {
			channel.push('send_message', {
				content: `🤖 **AI Assistant**: ${result.message}`,
				message_type: 'ai_response'
			});
		} else {
			channel.push('send_message', {
				content: `🤖 **AI Assistant**: ❌ ${result.message || 'Sorry, I encountered an error processing your request.'}`,
				message_type: 'ai_response'
			});
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
	
	function handleKeyPress(event: KeyboardEvent) {
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			sendMessage();
		}
	}
	
	function scrollToBottom() {
		setTimeout(() => {
			const messagesContainer = document.getElementById('messages-container');
			if (messagesContainer) {
				messagesContainer.scrollTop = messagesContainer.scrollHeight;
			}
		}, 100);
	}
	
	async function loadRooms() {
		if (!token) return;
		
		try {
			// Fetch public rooms and user rooms in parallel
			const [publicResponse, userResponse] = await Promise.all([
				fetch('http://localhost:4000/api/rooms/public', {
					headers: {
						'Authorization': `Bearer ${token}`,
						'Content-Type': 'application/json'
					}
				}),
				fetch('http://localhost:4000/api/rooms', {
					headers: {
						'Authorization': `Bearer ${token}`,
						'Content-Type': 'application/json'
					}
				})
			]);
			
			if (publicResponse.ok && userResponse.ok) {
				const publicData = await publicResponse.json();
				const userData = await userResponse.json();
				
				// Set public rooms
				publicRooms = publicData.rooms || [];
				
				// Filter private rooms from user rooms (exclude public ones to avoid duplicates)
				const userRooms = userData.rooms || [];
				const newPrivateRooms = userRooms.filter((room: any) => room.is_private);
				
				// Remove duplicates by ID to prevent duplicate rooms
				const uniquePrivateRooms = newPrivateRooms.filter((room: any, index: number, self: any[]) =>
					index === self.findIndex((r: any) => r.id === room.id)
				);
				
				privateRooms = uniquePrivateRooms;
			} else {
				console.error('Failed to load rooms:', publicResponse.status, userResponse.status);
				// Fallback to seeded room UUIDs
				publicRooms = [
					{ id: '550e8400-e29b-41d4-a716-446655440000', name: 'General', is_private: false },
					{ id: '550e8400-e29b-41d4-a716-446655440001', name: 'Random', is_private: false },
					{ id: '550e8400-e29b-41d4-a716-446655440002', name: 'Tech Talk', is_private: false }
				];
				privateRooms = [];
			}
		} catch (error) {
			console.error('Error loading rooms:', error);
			// Fallback to seeded room UUIDs
			publicRooms = [
				{ id: '550e8400-e29b-41d4-a716-446655440000', name: 'General', is_private: false },
				{ id: '550e8400-e29b-41d4-a716-446655440001', name: 'Random', is_private: false },
				{ id: '550e8400-e29b-41d4-a716-446655440002', name: 'Tech Talk', is_private: false }
			];
			privateRooms = [];
		}
	}
	
	async function createRoom() {
		if (!newRoomName.trim() || !token) return;
		
		try {
			const response = await fetch('http://localhost:4000/api/rooms', {
				method: 'POST',
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					name: newRoomName.trim(),
					description: newRoomDescription.trim(),
					is_private: isPrivateRoom
				})
			});
			
			if (response.ok) {
				const data = await response.json();
				// Add room to appropriate list
				if (data.room.is_private) {
					const existingPrivateRoom = privateRooms.find(room => room.id === data.room.id);
					if (!existingPrivateRoom) {
						privateRooms = [...privateRooms, data.room];
					}
				} else {
					const existingPublicRoom = publicRooms.find(room => room.id === data.room.id);
					if (!existingPublicRoom) {
						publicRooms = [...publicRooms, data.room];
					}
				}
				showCreateRoom = false;
				newRoomName = '';
				newRoomDescription = '';
				isPrivateRoom = false;
				
				// Join the newly created room
				joinRoom(data.room.id);
			} else {
				console.error('Failed to create room:', response.status);
			}
		} catch (error) {
			console.error('Error creating room:', error);
		}
	}
	
	function formatTime(timestamp: string) {
		return new Date(timestamp).toLocaleTimeString([], { 
			hour: '2-digit', 
			minute: '2-digit' 
		});
	}

	async function loadRoomMembers() {
		if (!token || !currentRoom) return;
		
		try {
			const response = await fetch(`http://localhost:4000/api/rooms/${currentRoom}/members`, {
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				}
			});
			
			if (response.ok) {
				const data = await response.json();
				roomMembers = data.members || [];
			}
		} catch (error) {
			console.error('Error loading room members:', error);
		}
	}

	async function searchUsers() {
		if (!token || !searchQuery.trim()) {
			searchResults = [];
			return;
		}
		
		try {
			const response = await fetch(`http://localhost:4000/api/users/search?q=${encodeURIComponent(searchQuery)}`, {
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				}
			});
			
			if (response.ok) {
				const data = await response.json();
				searchResults = data.users || [];
			}
		} catch (error) {
			console.error('Error searching users:', error);
		}
	}

	async function inviteUser(userId: string) {
		if (!token || !currentRoom) return;
		
		try {
			const response = await fetch(`http://localhost:4000/api/rooms/${currentRoom}/invite`, {
				method: 'POST',
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ user_id: userId })
			});
			
			if (response.ok) {
				await loadRoomMembers();
				showInviteModal = false;
				searchQuery = '';
				searchResults = [];
			} else {
				const error = await response.json();
				console.error('Error inviting user:', error);
			}
		} catch (error) {
			console.error('Error inviting user:', error);
		}
	}

	async function removeUser(userId: string) {
		if (!token || !currentRoom) return;
		
		try {
			const response = await fetch(`http://localhost:4000/api/rooms/${currentRoom}/remove`, {
				method: 'DELETE',
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ user_id: userId })
			});
			
			if (response.ok) {
				await loadRoomMembers();
			} else {
				const error = await response.json();
				console.error('Error removing user:', error);
			}
		} catch (error) {
			console.error('Error removing user:', error);
		}
	}

	function toggleUserSelection(user: any) {
		const index = selectedUsers.findIndex(u => u.id === user.id);
		if (index >= 0) {
			selectedUsers = selectedUsers.filter(u => u.id !== user.id);
		} else {
			selectedUsers = [...selectedUsers, user];
		}
	}

	async function createPrivateRoomWithUsers() {
		if (!privateRoomName.trim() || !token || selectedUsers.length === 0 || isCreatingRoom) return;
		
		isCreatingRoom = true;
		try {
			const response = await fetch('http://localhost:4000/api/rooms/private', {
				method: 'POST',
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					name: privateRoomName.trim(),
					description: privateRoomDescription.trim(),
					user_ids: selectedUsers.map(u => u.id)
				})
			});
			
			if (response.ok) {
				const data = await response.json();
				
				// Check if room already exists to prevent duplicates
				const existingRoom = privateRooms.find(room => room.id === data.room.id);
				if (!existingRoom) {
					privateRooms = [...privateRooms, data.room];
				}
				
				showCreatePrivateRoom = false;
				privateRoomName = '';
				privateRoomDescription = '';
				selectedUsers = [];
				searchQuery = '';
				searchResults = [];
				
				// Join the newly created room
				joinRoom(data.room.id);
			} else {
				const error = await response.json();
				console.error('Error creating private room:', error);
			}
		} catch (error) {
			console.error('Error creating private room:', error);
		} finally {
			isCreatingRoom = false;
		}
	}

	function canManageRoom() {
		if (!user || !currentRoom) return false;
		const currentRoomData = [...publicRooms, ...privateRooms].find(r => r.id === currentRoom);
		const currentMember = roomMembers.find(m => m.user_id === user.id);
		return currentRoomData?.created_by === user.id || currentMember?.role === 'admin';
	}

	async function deleteRoom() {
		if (!token || !currentRoom) return;
		
		try {
			const response = await fetch(`http://localhost:4000/api/rooms/${currentRoom}`, {
				method: 'DELETE',
				headers: {
					'Authorization': `Bearer ${token}`
				}
			});
			
			if (response.ok) {
				// Remove room from lists
				publicRooms = publicRooms.filter(r => r.id !== currentRoom);
				privateRooms = privateRooms.filter(r => r.id !== currentRoom);
				
				// Close confirmation modal
				showDeleteConfirmation = false;
				
				// Leave the channel if connected
				if (channel) {
					channel.leave();
					channel = null;
				}
				
				// Clear current room and messages
				currentRoom = '';
				messages = [];
				roomMembers = [];
				
				// Redirect to first available room or clear state
				const availableRooms = [...publicRooms, ...privateRooms];
				if (availableRooms.length > 0) {
					joinRoom(availableRooms[0].id);
				}
			} else {
				const error = await response.json();
				console.error('Error deleting room:', error);
				alert('Failed to delete room: ' + (error.error || 'Unknown error'));
			}
		} catch (error) {
			console.error('Error deleting room:', error);
			alert('Failed to delete room. Please try again.');
		}
	}
	
	function getAvatarColor(message: any): string {
		if (message.message_type === 'ai_response') {
			return 'bg-blue-500';
		} else if (message.message_type === 'ai_command') {
			return 'bg-purple-500';
		}
		return 'bg-blue-500';
	}
	
	function getAvatarContent(message: any): string {
		if (message.message_type === 'ai_response') {
			return '🤖';
		} else if (message.message_type === 'ai_command') {
			return '⚡';
		}
		return message.user?.username?.charAt(0).toUpperCase() || 'U';
	}
	
	function getDisplayName(message: any): string {
		if (message.message_type === 'ai_response') {
			return 'AI Assistant';
		} else if (message.message_type === 'ai_command') {
			return message.user?.username || 'Unknown User';
		}
		return message.user?.username || 'Unknown User';
	}
	
	function formatMarkdown(content: string): string {
		// Simple markdown formatting for AI responses
		return content
			.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
			.replace(/\*(.*?)\*/g, '<em>$1</em>')
			.replace(/`(.*?)`/g, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm">$1</code>')
			.replace(/^• (.+)$/gm, '<li class="ml-4">$1</li>')
			.replace(/\n/g, '<br/>');
	}
</script>

{#if isLoading}
	<div class="flex h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<svg class="animate-spin h-12 w-12 text-indigo-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
				<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
				<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
			</svg>
			<p class="text-gray-600">Loading...</p>
		</div>
	</div>
{:else if !user}
	<div class="flex h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<p class="text-gray-600 mb-4">Please sign in to continue</p>
			<a href="/login" class="text-indigo-600 hover:text-indigo-500">Go to Login</a>
		</div>
	</div>
{:else}
	<div class="flex h-screen bg-white">
		<!-- Sidebar -->
		<div class="w-64 bg-gray-800 text-white">
			<div class="p-4 border-b border-gray-700">
				<h1 class="text-xl font-bold">{APP_NAME}</h1>
				<p class="text-sm text-gray-300">Welcome, {user?.username || 'Guest'}</p>
				<button
					on:click={() => authStore.logout()}
					class="mt-2 text-xs text-gray-400 hover:text-white transition-colors"
				>
					Sign out
				</button>
			</div>
			
			<div class="p-4">
				<div class="flex items-center justify-between mb-2">
					<h3 class="text-sm font-semibold text-gray-300 uppercase tracking-wider">
						Public Rooms
					</h3>
					<div class="flex items-center space-x-2">
						<span class="text-xs text-gray-500 bg-gray-700 px-2 py-1 rounded">
							{publicRooms.length}
						</span>
						<button
							on:click={() => showCreateRoom = true}
							class="text-gray-400 hover:text-white transition-colors p-1 rounded"
							title="Create Room"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
							</svg>
						</button>
					</div>
				</div>
				<div class="space-y-1">
					{#each publicRooms as room}
						<button
							class="w-full text-left px-3 py-2 rounded-md text-sm hover:bg-gray-700 transition-colors {currentRoom === room.id ? 'bg-gray-700' : ''}"
							on:click={() => joinRoom(room.id)}
						>
							# {room.name}
							{#if room.is_private}
								<svg class="inline w-3 h-3 ml-1 opacity-50" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
								</svg>
							{/if}
						</button>
					{/each}
					{#if publicRooms.length === 0}
						<p class="text-xs text-gray-500 px-3 py-2">No public rooms available</p>
					{/if}
				</div>
			</div>
			
			<!-- Private Rooms Section -->
			<div class="p-4 border-t border-gray-700">
				<div class="flex items-center justify-between mb-2">
					<h3 class="text-sm font-semibold text-gray-300 uppercase tracking-wider">
						Private Rooms
					</h3>
					<div class="flex items-center space-x-2">
						<span class="text-xs text-gray-500 bg-gray-700 px-2 py-1 rounded">
							{privateRooms.length}
						</span>
						<button
							on:click={() => showCreatePrivateRoom = true}
							class="text-gray-400 hover:text-white transition-colors p-1 rounded"
							title="Create Private Room"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
							</svg>
						</button>
					</div>
				</div>
				<div class="space-y-1">
					{#each privateRooms as room}
						<button
							class="w-full text-left px-3 py-2 rounded-md text-sm hover:bg-gray-700 transition-colors {currentRoom === room.id ? 'bg-gray-700' : ''}"
							on:click={() => joinRoom(room.id)}
						>
							<svg class="inline w-3 h-3 mr-1 opacity-50" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path>
							</svg>
							{room.name}
						</button>
					{/each}
					{#if privateRooms.length === 0}
						<p class="text-xs text-gray-500 px-3 py-2">No private rooms available</p>
					{/if}
				</div>
			</div>
			
			<div class="absolute bottom-4 left-4 right-4">
				<div class="flex items-center space-x-2">
					<div class="w-2 h-2 rounded-full {isConnected ? 'bg-green-400' : 'bg-red-400'}"></div>
					<span class="text-xs text-gray-400">
						{isConnected ? 'Connected' : 'Disconnected'}
					</span>
				</div>
			</div>
		</div>
		
		<!-- Main Chat Area -->
		<div class="flex-1 flex flex-col">
			<!-- Chat Header -->
			<div class="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
				<h2 class="text-lg font-semibold text-gray-900">
					# {[...publicRooms, ...privateRooms].find(r => r.id === currentRoom)?.name || currentRoom}
				</h2>
				<div class="flex items-center space-x-3">
					<button
						on:click={() => {
							showAICapabilities = !showAICapabilities;
							if (showAICapabilities && availableCapabilities.length === 0) {
								loadCapabilities();
							}
						}}
						class="flex items-center space-x-2 px-3 py-1 text-sm {showAICapabilities ? 'text-blue-600 bg-blue-50' : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'} rounded-md transition-colors"
						title="Toggle AI Capabilities"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
						</svg>
						<span>🤖 AI</span>
					</button>
					
					<button
						on:click={() => showParticipants = true}
						class="flex items-center space-x-2 px-3 py-1 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-md transition-colors"
						title="View Participants"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-2.239"></path>
						</svg>
						<span>{roomMembers.length} participant{roomMembers.length !== 1 ? 's' : ''}</span>
					</button>

					{#if canManage}
						<button
							on:click={() => showInviteModal = true}
							class="flex items-center space-x-1 px-3 py-1 text-sm text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-md transition-colors"
							title="Invite Users"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
							</svg>
							<span>Invite</span>
						</button>
						<button
							on:click={() => showDeleteConfirmation = true}
							class="flex items-center space-x-1 px-3 py-1 text-sm text-red-600 hover:text-red-800 hover:bg-red-50 rounded-md transition-colors"
							title="Delete Room"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
							</svg>
							<span>Delete</span>
						</button>
					{/if}
				</div>
			</div>
			
			<!-- Messages -->
			<div 
				id="messages-container" 
				class="flex-1 overflow-y-auto p-6 space-y-4"
			>
				{#each messages as message}
					<div class="flex items-start space-x-3 {message.message_type === 'ai_response' ? 'bg-blue-50 -mx-2 px-2 py-2 rounded-lg' : ''} {message.message_type === 'ai_command' ? 'bg-purple-50 -mx-2 px-2 py-2 rounded-lg' : ''}">
						<div class="w-8 h-8 {getAvatarColor(message)} rounded-full flex items-center justify-center text-white text-sm font-medium">
							{getAvatarContent(message)}
						</div>
						<div class="flex-1">
							<div class="flex items-center space-x-2 mb-1">
								<span class="font-medium text-gray-900">
									{getDisplayName(message)}
								</span>
								{#if message.message_type === 'ai_command'}
									<span class="text-xs bg-purple-200 text-purple-800 px-2 py-1 rounded-full">AI Command</span>
								{:else if message.message_type === 'ai_response'}
									<span class="text-xs bg-blue-200 text-blue-800 px-2 py-1 rounded-full">AI Response</span>
								{/if}
								<span class="text-xs text-gray-500">
									{formatTime(message.created_at)}
								</span>
							</div>
							<div class="text-gray-700 {message.message_type === 'ai_response' ? 'prose prose-sm max-w-none' : ''}">
								{#if message.content.includes('**') || message.content.includes('•') || message.content.includes('`')}
									{@html formatMarkdown(message.content)}
								{:else}
									{message.content}
								{/if}
							</div>
						</div>
					</div>
				{/each}
			</div>
			
			<!-- Message Input -->
			<div class="bg-white border-t border-gray-200 p-4">
				{#if isProcessingAI}
					<div class="mb-2 text-sm text-blue-600 flex items-center">
						<svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						AI is processing your request...
					</div>
				{/if}
				
				<div class="flex space-x-4">
					<div class="flex-1">
						<textarea
							bind:value={newMessage}
							on:keydown={handleKeyPress}
							placeholder={isProcessingAI ? "AI is processing..." : "Type a message... (Use /command for AI capabilities, or ai: for natural language)"}
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
							rows="1"
							disabled={isProcessingAI}
						></textarea>
						
						{#if newMessage.startsWith('/') || newMessage.toLowerCase().startsWith('ai:') || newMessage.toLowerCase().startsWith('ask:') || newMessage.toLowerCase().startsWith('@ai')}
							<div class="mt-1 text-xs text-blue-600">
								🤖 AI command detected - this will be processed by the AI assistant
							</div>
						{/if}
					</div>
					<button
						on:click={sendMessage}
						disabled={!newMessage.trim() || !isConnected || isProcessingAI}
						class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{isProcessingAI ? '⏳' : 'Send'}
					</button>
				</div>
				
				{#if currentRoom}
					<div class="mt-2 text-xs text-gray-500">
						💡 Try: <button class="text-blue-600 hover:underline" on:click={() => newMessage = 'ai: summarize recent messages'}>ai: summarize recent messages</button> • 
						<button class="text-blue-600 hover:underline" on:click={() => newMessage = '/help'}>Show AI capabilities (/help)</button>
					</div>
				{/if}
			</div>
		</div>
		
		<!-- AI Capabilities Panel (Collapsible) -->
		<div class="w-80 bg-gray-50 border-l border-gray-200 flex flex-col" class:hidden={!showAICapabilities}>
			<div class="p-4 border-b border-gray-200">
				<div class="flex items-center justify-between">
					<h2 class="text-lg font-semibold text-gray-900">🤖 AI Capabilities</h2>
					<button
						on:click={() => showAICapabilities = false}
						class="text-gray-400 hover:text-gray-600"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				<p class="text-sm text-gray-600 mt-1">Available AI tools and commands</p>
			</div>
			
			<div class="flex-1 overflow-y-auto p-4">
				<AICapabilitiesList 
					{currentRoom}
					{availableCapabilities}
					onCapabilitySelect={(capability) => {
						// Insert capability command into message input
						newMessage = `/${capability.id} `;
						document.querySelector('textarea')?.focus();
					}}
					onLoadCapabilities={loadCapabilities}
				/>
			</div>
		</div>
	</div>

	<!-- Participants Modal -->
	{#if showParticipants}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
			<div class="bg-white rounded-lg p-6 w-full max-w-md mx-4 max-h-96 flex flex-col">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-lg font-semibold text-gray-900">Room Participants</h3>
					<button
						on:click={() => showParticipants = false}
						class="text-gray-400 hover:text-gray-600"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<div class="flex-1 overflow-y-auto space-y-2">
					{#each roomMembers as member}
						<div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
							<div class="flex items-center space-x-3">
								<div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center text-white text-sm font-medium">
									{member.username?.charAt(0).toUpperCase() || 'U'}
								</div>
								<div>
									<div class="font-medium text-gray-900">{member.username}</div>
									<div class="text-xs text-gray-500 capitalize">{member.role}</div>
								</div>
							</div>
							{#if canManage && member.user_id !== user?.id}
								<button
									on:click={() => removeUser(member.user_id)}
									class="text-red-600 hover:text-red-800 text-sm"
									title="Remove user"
								>
									Remove
								</button>
							{/if}
						</div>
					{/each}
					{#if roomMembers.length === 0}
						<p class="text-gray-500 text-center py-4">No participants found</p>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	<!-- Invite User Modal -->
	{#if showInviteModal}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
			<div class="bg-white rounded-lg p-6 w-full max-w-md mx-4 max-h-96 flex flex-col">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-lg font-semibold text-gray-900">Invite Users</h3>
					<button
						on:click={() => { showInviteModal = false; searchQuery = ''; searchResults = []; }}
						class="text-gray-400 hover:text-gray-600"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<div class="mb-4">
					<input
						type="text"
						bind:value={searchQuery}
						on:input={searchUsers}
						placeholder="Search users by username or email..."
						class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					>
				</div>
				
				<div class="flex-1 overflow-y-auto space-y-2">
					{#each searchResults as searchUser}
						{#if !roomMembers.find(m => m.user_id === searchUser.id)}
							<div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
								<div class="flex items-center space-x-3">
									<div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white text-sm font-medium">
										{searchUser.username?.charAt(0).toUpperCase() || 'U'}
									</div>
									<div>
										<div class="font-medium text-gray-900">{searchUser.username}</div>
										<div class="text-xs text-gray-500">{searchUser.email}</div>
									</div>
								</div>
								<button
									on:click={() => inviteUser(searchUser.id)}
									class="px-3 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700"
								>
									Invite
								</button>
							</div>
						{/if}
					{/each}
					{#if searchQuery && searchResults.length === 0}
						<p class="text-gray-500 text-center py-4">No users found</p>
					{:else if !searchQuery}
						<p class="text-gray-500 text-center py-4">Start typing to search for users</p>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	<!-- Create Private Room Modal -->
	{#if showCreatePrivateRoom}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
			<div class="bg-white rounded-lg p-6 w-full max-w-lg mx-4 max-h-[90vh] flex flex-col">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-lg font-semibold text-gray-900">Create Private Room</h3>
					<button
						on:click={() => { 
							showCreatePrivateRoom = false; 
							privateRoomName = ''; 
							privateRoomDescription = ''; 
							selectedUsers = []; 
							searchQuery = ''; 
							searchResults = []; 
						}}
						class="text-gray-400 hover:text-gray-600"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<form on:submit|preventDefault={createPrivateRoomWithUsers} class="space-y-4 flex-1 flex flex-col">
					<div>
						<label for="privateRoomName" class="block text-sm font-medium text-gray-700 mb-1">
							Room Name *
						</label>
						<input
							id="privateRoomName"
							type="text"
							bind:value={privateRoomName}
							placeholder="Enter room name"
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							required
						>
					</div>
					
					<div>
						<label for="privateRoomDescription" class="block text-sm font-medium text-gray-700 mb-1">
							Description
						</label>
						<textarea
							id="privateRoomDescription"
							bind:value={privateRoomDescription}
							placeholder="Enter room description (optional)"
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
							rows="2"
						></textarea>
					</div>
					
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">
							Search and Select Users *
						</label>
						<input
							type="text"
							bind:value={searchQuery}
							on:input={searchUsers}
							placeholder="Search users to invite..."
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						>
					</div>
					
					{#if selectedUsers.length > 0}
						<div>
							<label class="block text-sm font-medium text-gray-700 mb-2">
								Selected Users ({selectedUsers.length})
							</label>
							<div class="flex flex-wrap gap-2 max-h-20 overflow-y-auto">
								{#each selectedUsers as selectedUser}
									<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
										{selectedUser.username}
										<button
											type="button"
											on:click={() => toggleUserSelection(selectedUser)}
											class="ml-1 text-blue-600 hover:text-blue-800"
										>
											×
										</button>
									</span>
								{/each}
							</div>
						</div>
					{/if}
					
					<div class="flex-1 overflow-y-auto">
						{#if searchResults.length > 0}
							<label class="block text-sm font-medium text-gray-700 mb-2">
								Search Results
							</label>
							<div class="space-y-2 max-h-32 overflow-y-auto">
								{#each searchResults as searchUser}
									{#if searchUser.id !== user?.id}
										<div class="flex items-center justify-between p-2 bg-gray-50 rounded">
											<div class="flex items-center space-x-2">
												<div class="w-6 h-6 bg-green-500 rounded-full flex items-center justify-center text-white text-xs font-medium">
													{searchUser.username?.charAt(0).toUpperCase() || 'U'}
												</div>
												<span class="text-sm">{searchUser.username}</span>
											</div>
											<button
												type="button"
												on:click={() => toggleUserSelection(searchUser)}
												class="text-xs px-2 py-1 rounded {selectedUsers.find(u => u.id === searchUser.id) ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}"
											>
												{selectedUsers.find(u => u.id === searchUser.id) ? 'Selected' : 'Select'}
											</button>
										</div>
									{/if}
								{/each}
							</div>
						{/if}
					</div>
					
					<div class="flex justify-end space-x-3 pt-4 border-t">
						<button
							type="button"
							on:click={() => { 
								showCreatePrivateRoom = false; 
								privateRoomName = ''; 
								privateRoomDescription = ''; 
								selectedUsers = []; 
								searchQuery = ''; 
								searchResults = []; 
							}}
							class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={!privateRoomName.trim() || selectedUsers.length === 0}
							class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Create Room
						</button>
					</div>
				</form>
			</div>
		</div>
	{/if}

	<!-- Create Room Modal -->
	{#if showCreateRoom}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
			<div class="bg-white rounded-lg p-6 w-full max-w-md mx-4">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-lg font-semibold text-gray-900">Create New Room</h3>
					<button
						on:click={() => showCreateRoom = false}
						class="text-gray-400 hover:text-gray-600"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<form on:submit|preventDefault={createRoom} class="space-y-4">
					<div>
						<label for="roomName" class="block text-sm font-medium text-gray-700 mb-1">
							Room Name *
						</label>
						<input
							id="roomName"
							type="text"
							bind:value={newRoomName}
							placeholder="Enter room name"
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							required
						>
					</div>
					
					<div>
						<label for="roomDescription" class="block text-sm font-medium text-gray-700 mb-1">
							Description
						</label>
						<textarea
							id="roomDescription"
							bind:value={newRoomDescription}
							placeholder="Enter room description (optional)"
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
							rows="2"
						></textarea>
					</div>
					
					<div class="flex items-center">
						<input
							id="isPrivate"
							type="checkbox"
							bind:checked={isPrivateRoom}
							class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
						>
						<label for="isPrivate" class="ml-2 block text-sm text-gray-700">
							Private room (invite only)
						</label>
					</div>
					
					<div class="flex justify-end space-x-3 pt-4">
						<button
							type="button"
							on:click={() => showCreateRoom = false}
							class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
						>
							Cancel
						</button>
						<button
							type="submit"
							disabled={!newRoomName.trim()}
							class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Create Room
						</button>
					</div>
				</form>
			</div>
		</div>
	{/if}

	<!-- Delete Room Confirmation Modal -->
	{#if showDeleteConfirmation}
		<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
			<div class="bg-white rounded-lg p-6 w-full max-w-md mx-4">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-lg font-semibold text-gray-900">Delete Room</h3>
					<button
						on:click={() => showDeleteConfirmation = false}
						class="text-gray-400 hover:text-gray-600"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
						</svg>
					</button>
				</div>
				
				<div class="mb-6">
					<div class="flex items-center mb-3">
						<svg class="w-6 h-6 text-red-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
						</svg>
						<h4 class="text-red-800 font-medium">Are you sure you want to delete this room?</h4>
					</div>
					<p class="text-gray-600 text-sm">
						This action cannot be undone. All messages and room data will be permanently deleted.
					</p>
					<p class="text-gray-800 font-medium mt-2">
						Room: "{[...publicRooms, ...privateRooms].find(r => r.id === currentRoom)?.name || 'Unknown Room'}"
					</p>
				</div>
				
				<div class="flex justify-end space-x-3">
					<button
						type="button"
						on:click={() => showDeleteConfirmation = false}
						class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
					>
						Cancel
					</button>
					<button
						type="button"
						on:click={deleteRoom}
						class="px-4 py-2 text-sm font-medium text-white bg-red-600 border border-transparent rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
					>
						Delete Room
					</button>
				</div>
			</div>
		</div>
	{/if}
{/if}