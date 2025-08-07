<script lang="ts">
	import '../app.css';
	import { APP_NAME } from '$lib/config';
</script>

<svelte:head>
	<title>{APP_NAME}</title>
</svelte:head>

<main class="min-h-screen bg-gray-50">
	<slot />
</main>