# Claude Code Guidelines for micro_api

## Development Server Management
- **Reuse the same background shell** when restarting the Racket server to avoid shell proliferation
- Track the server shell ID and kill/restart in the same context
- Server runs on port 4321: `racket server.rkt`

## Project Structure
- `server.rkt` - Main server with routing and existing endpoints
- `academy.rkt` - Curl Academy module (20 levels teaching curl)
- Cookie state stored in `/var/www/curl-tut/academy-cookies.json`

## Testing
- Test academy levels sequentially with curl
- Base URL: `http://localhost:4321`
