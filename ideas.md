I'm mulling around the idea of making an API that teaches you how to use `curl` properly, given that I forget often, and I think it's an underrated tool.

The most familiar format I have for this is something like hackerrank, where you progress through levels. We could go from something basic like simple GETs to more advanced things like cookies, multipart uploads, etc.

## TENTATIVE PROGRESSION

Level 0: Discovery
GET /
{
  "message": "Welcome to Curl Academy! Your journey begins...",
  "instruction": "Start your training with GET /level/1",
  "command": "curl <http://your-server.com/level/1>",
  "total_levels": 20
}

Level 1: First GET
GET /level/1
{
  "lesson": "GET retrieves data from servers",
  "instruction": "Add query parameters to filter results",
  "challenge": "GET /level/2?name=yourname&ready=true",
  "hint": "curl '<http://your-server.com/level/2?name=alice&ready=true>'"
}

Level 2: Query Params
GET /level/2?name=<name>&ready=true
{
  "success": true,
  "lesson": "Query parameters pass data in URLs",
  "parsed": {"name": "alice", "ready": "true"},
  "your_id": "alice_7f3a2",
  "instruction": "POST your first data to /level/3",
  "required": {"field": "id", "value": "alice_7f3a2"},
  "hint": "curl -X POST -d 'id=alice_7f3a2' ..."
}

Level 3: POST Basics
POST /level/3 with id=alice_7f3a2
{
  "success": true,
  "lesson": "POST sends data to create resources",
  "resource_created": "/users/alice_7f3a2",
  "instruction": "Update your resource with PUT to /level/4/alice_7f3a2",
  "required_field": "status=active",
  "hint": "curl -X PUT -d 'status=active' ..."
}

Level 4: PUT Updates
PUT /level/4/{id} with status=active
{
  "success": true,
  "lesson": "PUT replaces entire resources",
  "instruction": "Now try PATCH for partial updates at /level/5/alice_7f3a2",
  "current_data": {"name": "alice", "status": "active", "level": 4},
  "challenge": "Update only the level to 5",
  "hint": "curl -X PATCH -d 'level=5' ..."
}

Level 5: PATCH partial update
PATCH /level/5/{id} with level=5
{
  "success": true,
  "lesson": "PATCH updates specific fields only",
  "updated_data": {"name": "alice", "status": "active", "level": 5},
  "instruction": "DELETE your temporary data at /level/6/alice_7f3a2",
  "warning": "Add safety header: Confirm: yes",
  "hint": "curl -X DELETE -H 'Confirm: yes' ..."
}

Level 6: DELETE with headers
DELETE /level/6/{id} with header Confirm: yes
{
  "success": true,
  "lesson": "Headers carry metadata; DELETE removes resources",
  "instruction": "Pretend to be a bot: GET /level/7 with custom User-Agent",
  "required_header": "User-Agent: CurlBot/1.0",
  "hint": "curl -H 'User-Agent: CurlBot/1.0' ..."
}

Level 7: User-Agent Spoofing
GET /level/7 with header User-Agent: CurlBot/1.0
{
  "success": true,
  "message": "BEEP BOOP - BOT RECOGNIZED",
  "lesson": "User-Agent identifies your client software",
  "instruction": "Send JSON data to /level/8",
  "required": {
    "header": "Content-Type: application/json",
    "body": {"bot": true, "version": "1.0"}
  },
  "hint": "curl -H 'Content-Type: application/json' -d '{\"bot\":true,\"version\":\"1.0\"}' ..."
}
