import { writable } from 'svelte/store';
import type { User, AuthState } from '../auth';
import { authService } from '../auth';

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>({
    user: null,
    token: null,
    isLoading: true
  });

  return {
    subscribe,
    
    async initialize() {
      update(state => ({ ...state, isLoading: true }));
      
      try {
        // Try to get stored token from localStorage
        const storedToken = localStorage.getItem('auth_token');
        if (storedToken) {
          const user = await authService.getCurrentUser(storedToken);
          if (user) {
            set({
              user,
              token: storedToken,
              isLoading: false
            });
            return;
          }
        }
        
        // No valid token found
        set({
          user: null,
          token: null,
          isLoading: false
        });
      } catch (error) {
        console.error('Failed to initialize auth:', error);
        set({
          user: null,
          token: null,
          isLoading: false
        });
      }
    },

    async register(username: string, email: string, password: string) {
      update(state => ({ ...state, isLoading: true }));
      
      try {
        const { user, token } = await authService.register(username, email, password);
        
        // Store token in localStorage
        localStorage.setItem('auth_token', token);
        
        set({
          user,
          token,
          isLoading: false
        });
        
        return { success: true };
      } catch (error) {
        update(state => ({ ...state, isLoading: false }));
        return { success: false, error: error instanceof Error ? error.message : 'Registration failed' };
      }
    },

    async login(email: string, password: string) {
      update(state => ({ ...state, isLoading: true }));
      
      try {
        const { user, token } = await authService.login(email, password);
        
        // Store token in localStorage
        localStorage.setItem('auth_token', token);
        
        set({
          user,
          token,
          isLoading: false
        });
        
        return { success: true };
      } catch (error) {
        update(state => ({ ...state, isLoading: false }));
        return { success: false, error: error instanceof Error ? error.message : 'Login failed' };
      }
    },

    async logout() {
      try {
        await authService.logout();
      } catch (error) {
        console.error('Logout error:', error);
      } finally {
        // Remove token from localStorage
        localStorage.removeItem('auth_token');
        
        set({
          user: null,
          token: null,
          isLoading: false
        });
      }
    }
  };
}

export const authStore = createAuthStore();