export interface User {
  id: string;
  username: string;
  email: string;
  avatar_url?: string;
}

export interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
}

class AuthService {
  private baseUrl = 'http://localhost:4000/api';
  
  async register(username: string, email: string, password: string): Promise<{ user: User; token: string }> {
    const response = await fetch(`${this.baseUrl}/users/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user: {
          username,
          email,
          password,
        }
      })
    });

    if (!response.ok) {
      const error = await response.json();
      
      // Extract specific validation errors if available
      if (error.errors && typeof error.errors === 'object') {
        const errorMessages = [];
        for (const [field, messages] of Object.entries(error.errors)) {
          if (Array.isArray(messages)) {
            errorMessages.push(...messages.map(msg => `${field}: ${msg}`));
          }
        }
        if (errorMessages.length > 0) {
          throw new Error(errorMessages.join(', '));
        }
      }
      
      throw new Error(error.error || 'Registration failed');
    }

    const data = await response.json();
    
    return {
      user: data.user,
      token: data.token
    };
  }

  async login(email: string, password: string): Promise<{ user: User; token: string }> {
    const response = await fetch(`${this.baseUrl}/users/log_in`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user: {
          email,
          password,
        }
      })
    });

    if (!response.ok) {
      const error = await response.json();
      
      // Extract specific validation errors if available
      if (error.errors && typeof error.errors === 'object') {
        const errorMessages = [];
        for (const [field, messages] of Object.entries(error.errors)) {
          if (Array.isArray(messages)) {
            errorMessages.push(...messages.map(msg => `${field}: ${msg}`));
          }
        }
        if (errorMessages.length > 0) {
          throw new Error(errorMessages.join(', '));
        }
      }
      
      throw new Error(error.error || 'Login failed');
    }

    const data = await response.json();
    
    return {
      user: data.user,
      token: data.token
    };
  }

  async logout(): Promise<void> {
    const response = await fetch(`${this.baseUrl}/users/log_out`, {
      method: 'DELETE',
    });

    if (!response.ok) {
      throw new Error('Logout failed');
    }
  }

  async getCurrentUser(token?: string): Promise<User | null> {
    try {
      const headers: HeadersInit = {};
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
      
      const response = await fetch(`${this.baseUrl}/users/me`, {
        headers,
      });

      if (!response.ok) {
        return null;
      }

      const data = await response.json();
      return data.user || data;
    } catch (error) {
      console.error('Failed to get current user:', error);
      return null;
    }
  }

  // Get session token for WebSocket connection
  // With token-based auth, we just return the stored token
  getSessionToken(token: string | null): string | null {
    return token;
  }
}

export const authService = new AuthService();