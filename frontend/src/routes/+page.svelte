<script lang="ts">
	import { onMount } from 'svelte';
	import { Socket } from 'phoenix';
	
	let socket: Socket | null = null;
	let channel: any = null;
	let messages: any[] = [];
	let newMessage = '';
	let username = 'Guest';
	let currentRoom = 'General';
	let isConnected = false;
	let rooms: any[] = [];
	
	// Mock authentication - in production, this would come from Clerk
	const mockToken = 'mock-jwt-token';
	const mockUserId = 'user_123';
	
	onMount(() => {
		initializeSocket();
		loadRooms();
	});
	
	function initializeSocket() {
		// Initialize Phoenix Socket
		socket = new Socket('ws://localhost:4000/socket', {
			params: { token: mockToken }
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
		
		joinRoom(currentRoom);
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
	
	function loadRooms() {
		// Mock rooms data - these match the seeded rooms in the database
		rooms = [
			{ id: 'General', name: 'General', is_private: false },
			{ id: 'Random', name: 'Random', is_private: false },
			{ id: 'Tech Talk', name: 'Tech Talk', is_private: false }
		];
	}
	
	function formatTime(timestamp: string) {
		return new Date(timestamp).toLocaleTimeString([], { 
			hour: '2-digit', 
			minute: '2-digit' 
		});
	}
</script>

<div class="flex h-screen bg-white">
	<!-- Sidebar -->
	<div class="w-64 bg-gray-800 text-white">
		<div class="p-4 border-b border-gray-700">
			<h1 class="text-xl font-bold">PacketFlow Chat</h1>
			<p class="text-sm text-gray-300">Welcome, {username}</p>
		</div>
		
		<div class="p-4">
			<h3 class="text-sm font-semibold text-gray-300 uppercase tracking-wider mb-2">
				Rooms
			</h3>
			<div class="space-y-1">
				{#each rooms as room}
					<button
						class="w-full text-left px-3 py-2 rounded-md text-sm hover:bg-gray-700 transition-colors {currentRoom === room.id ? 'bg-gray-700' : ''}"
						on:click={() => joinRoom(room.id)}
					>
						# {room.name}
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