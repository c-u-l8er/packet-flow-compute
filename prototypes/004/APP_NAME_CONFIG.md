# App Name Configuration

The application name is now configurable through environment variables with a default fallback to "TickTickClock".

## Frontend Configuration

### Environment Variable
Set `PUBLIC_APP_NAME` in your environment or `.env` file:

```bash
PUBLIC_APP_NAME="Your Custom App Name"
```

### Default Behavior
If `PUBLIC_APP_NAME` is not set, the app will default to "TickTickClock". The environment variable is checked at runtime, so no restart is needed for changes during development.

### Usage in Frontend
The app name is used in:
- Page titles (Login, Register pages)
- Main application header
- Browser tab title

## Backend Configuration

### Environment Variable
Set `APP_NAME` in your environment:

```bash
APP_NAME="Your Custom App Name"
```

### Default Behavior
If `APP_NAME` is not set, the backend will default to "TickTickClock".

### Usage in Backend
The app name is used in:
- API response messages
- Backend status messages

## Examples

### Development
```bash
# Frontend
PUBLIC_APP_NAME="MyChat Dev"

# Backend  
APP_NAME="MyChat Dev"
```

### Production
```bash
# Frontend
PUBLIC_APP_NAME="MyChat"

# Backend
APP_NAME="MyChat"
```

## Notes

- Frontend environment variables must be prefixed with `PUBLIC_` to be accessible in the browser
- Backend uses standard environment variables without prefix
- Both environments have independent fallback to "TickTickClock"
- Changes to environment variables require application restart