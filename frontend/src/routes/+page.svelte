<script lang="ts">
	import { onMount } from 'svelte';
	import { Socket } from 'phoenix';
	import { authStore } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	
	let socket: Socket | null = null;
	let channel: any = null;
	let messages: any[] = [];
	let newMessage = '';
	let currentRoom = '';
	let isConnected = false;
	let rooms: any[] = [];
	let showCreateRoom = false;
	let newRoomName = '';
	let newRoomDescription = '';
	let isPrivateRoom = false;
	
	$: user = $authStore.user;
	$: token = $authStore.token;
	$: isLoading = $authStore.isLoading;
	
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
	
	$: if (user && token && !socket) {
		loadRooms().then(() => {
			initializeSocket();
		});
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
		if (!currentRoom && rooms.length > 0) {
			currentRoom = rooms[0].id;
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
		
		channel.on('user_joined', (payload: any) => {
			console.log('User joined:', payload);
		});
		
		channel.on('user_left', (payload: any) => {
			console.log('User left:', payload);
		});
		
		channel.on('typing_indicator', (payload: any) => {
			console.log('Typing indicator:', payload);
		});
	}
	
	function sendMessage() {
		if (!newMessage.trim() || !channel) return;
		
		channel.push('send_message', {
			content: newMessage,
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
			const response = await fetch('http://localhost:4000/api/rooms/public', {
				headers: {
					'Authorization': `Bearer ${token}`,
					'Content-Type': 'application/json'
				}
			});
			
			if (response.ok) {
				const data = await response.json();
				rooms = data.rooms || [];
			} else {
				console.error('Failed to load rooms:', response.status);
				// Fallback to seeded room UUIDs
				rooms = [
					{ id: '550e8400-e29b-41d4-a716-446655440000', name: 'General', is_private: false },
					{ id: '550e8400-e29b-41d4-a716-446655440001', name: 'Random', is_private: false },
					{ id: '550e8400-e29b-41d4-a716-446655440002', name: 'Tech Talk', is_private: false }
				];
			}
		} catch (error) {
			console.error('Error loading rooms:', error);
			// Fallback to seeded room UUIDs
			rooms = [
				{ id: '550e8400-e29b-41d4-a716-446655440000', name: 'General', is_private: false },
				{ id: '550e8400-e29b-41d4-a716-446655440001', name: 'Random', is_private: false },
				{ id: '550e8400-e29b-41d4-a716-446655440002', name: 'Tech Talk', is_private: false }
			];
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
				rooms = [...rooms, data.room];
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
			<h1 class="text-xl font-bold">PacketFlow Chat</h1>
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
					Rooms
				</h3>
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
			<div class="space-y-1">
				{#each rooms as room}
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
		<div class="bg-white border-b border-gray-200 px-6 py-4">
			<h2 class="text-lg font-semibold text-gray-900">
				# {rooms.find(r => r.id === currentRoom)?.name || currentRoom}
			</h2>
		</div>
		
		<!-- Messages -->
		<div 
			id="messages-container" 
			class="flex-1 overflow-y-auto p-6 space-y-4"
		>
			{#each messages as message}
				<div class="flex items-start space-x-3">
					<div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center text-white text-sm font-medium">
						{message.user?.username?.charAt(0).toUpperCase() || 'U'}
					</div>
					<div class="flex-1">
						<div class="flex items-center space-x-2 mb-1">
							<span class="font-medium text-gray-900">
								{message.user?.username || 'Unknown User'}
							</span>
							<span class="text-xs text-gray-500">
								{formatTime(message.created_at)}
							</span>
						</div>
						<p class="text-gray-700">{message.content}</p>
					</div>
				</div>
			{/each}
		</div>
		
		<!-- Message Input -->
		<div class="bg-white border-t border-gray-200 p-4">
			<div class="flex space-x-4">
				<div class="flex-1">
					<textarea
						bind:value={newMessage}
						on:keydown={handleKeyPress}
						placeholder="Type a message..."
						class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
						rows="1"
					></textarea>
				</div>
				<button
					on:click={sendMessage}
					disabled={!newMessage.trim() || !isConnected}
					class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					Send
				</button>
			</div>
		</div>
	</div>
</div>

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
{/if}