import { env } from '$env/dynamic/public';

// Get app name from environment variable, fallback to "TickTickClock"
export const APP_NAME = env.PUBLIC_APP_NAME || 'TickTickClock';