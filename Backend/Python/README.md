# TheSwiftKit — Python Flask AI Backend

A lightweight Flask server that proxies AI requests from the iOS app to OpenAI APIs. This keeps the OpenAI API key server-side so it never ships in your iOS binary.

## Endpoints

| Method | Path          | Description                     |
|--------|---------------|---------------------------------|
| GET    | `/health`     | Health check                    |
| POST   | `/v1/chat`    | Text chat completion (GPT-4o)   |
| POST   | `/v1/images`  | Image generation (gpt-image-1.5)|
| POST   | `/v1/vision`  | Image analysis / vision (GPT-4o)|

---

## Quick Start

### 1. Prerequisites

- Python 3.10 or later
- An [OpenAI API key](https://platform.openai.com/api-keys)

### 2. Create a virtual environment

```bash
cd Backend/Python
python -m venv .venv
source .venv/bin/activate   # macOS / Linux
# .venv\Scripts\activate    # Windows
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure environment variables

```bash
cp .env.example .env
# Edit .env and set your OpenAI API key
```

Or export directly:

```bash
export OPENAI_API_KEY=sk-your-key-here
```

### 5. Run the server

```bash
python app.py
```

The server starts on `http://0.0.0.0:5001` by default.

---

## Environment Variables

| Variable              | Required | Default           | Description                        |
|-----------------------|----------|-------------------|------------------------------------|
| `OPENAI_API_KEY`      | Yes      | —                 | Your OpenAI API key                |
| `PORT`                | No       | `5001`            | Port the server listens on         |
| `FLASK_DEBUG`         | No       | `true`            | Enable Flask debug mode            |
| `OPENAI_BASE_URL`     | No       | —                 | Override OpenAI base URL (proxies) |
| `OPENAI_CHAT_MODEL`   | No       | `gpt-4o`          | Model for chat completions         |
| `OPENAI_IMAGE_MODEL`  | No       | `gpt-image-1.5`   | Model for image generation         |
| `OPENAI_VISION_MODEL` | No       | `gpt-4o`          | Model for vision analysis          |

---

## API Reference

### GET /health

Health check endpoint.

**Response:**
```json
{
  "ok": true,
  "models": {
    "chat": "gpt-4o",
    "image": "gpt-image-1.5",
    "vision": "gpt-4o"
  }
}
```

---

### POST /v1/chat

Text chat completion using GPT-4o.

**Request:**
```
Content-Type: application/json
```

```json
{
  "messages": [
    { "role": "user", "content": "What is the capital of France?" }
  ],
  "model": "gpt-4o",
  "temperature": 0.7
}
```

- `messages` (required): Array of message objects with `role` and `content`.
- `model` (optional): Defaults to `gpt-4o`.
- `temperature` (optional): Float 0.0-2.0, defaults to 0.7.

**Response (200):**
```json
{
  "reply": "The capital of France is Paris.",
  "usage": {
    "prompt_tokens": 14,
    "completion_tokens": 8,
    "total_tokens": 22
  }
}
```

**Error (400):**
```json
{
  "error": "'messages' field is required and must be a non-empty array."
}
```

---

### POST /v1/images

Image generation using gpt-image-1.5.

**Request:**
```
Content-Type: application/json
```

```json
{
  "prompt": "A cute corgi wearing a space suit on Mars",
  "count": 2,
  "size": "1024x1024",
  "response_format": "b64_json"
}
```

- `prompt` (required): Description of the image to generate.
- `count` (optional): Number of images, 1-4, defaults to 2.
- `size` (optional): Image size. Allowed: `1024x1024`, `1024x1536`, `1536x1024`, `auto`. Other sizes are auto-mapped by aspect ratio.
- `response_format` (optional): Accepted for iOS client compatibility but not forwarded to OpenAI (gpt-image-1.5 always returns base64).

**Response (200):**
```json
{
  "images": [
    "iVBORw0KGgoAAAANSUhEUgAA...",
    "iVBORw0KGgoAAAANSUhEUgAA..."
  ]
}
```

Each entry in `images` is a base64-encoded PNG/JPEG string.

---

### POST /v1/vision

Image analysis using GPT-4o's vision capability.

**Request:**
```
Content-Type: multipart/form-data
```

| Field    | Type   | Required | Description                              |
|----------|--------|----------|------------------------------------------|
| `file`   | file   | Yes      | Image file (JPEG, PNG, GIF, WebP)        |
| `prompt` | string | No       | Analysis prompt (default: "Describe this image.") |

**Example (curl):**
```bash
curl -X POST http://localhost:5001/v1/vision \
  -F "file=@photo.jpg" \
  -F "prompt=What objects are in this image?"
```

**Response (200):**
```json
{
  "result": "The image shows a wooden desk with a laptop, a coffee mug, and a notebook."
}
```

---

## Error Handling

All error responses follow this format:

```json
{
  "error": "Human-readable error message",
  "details": "Optional technical details (only in 500 errors)"
}
```

Common HTTP status codes:
- `400` — Bad request (missing/invalid parameters)
- `404` — Endpoint not found
- `405` — Method not allowed
- `413` — Payload too large (vision images over 20 MB)
- `429` — OpenAI rate limit exceeded
- `502` — OpenAI API error
- `503` — Server misconfiguration (missing API key)
- `504` — OpenAI request timeout

---

## iOS Client Compatibility

The iOS app (`AIApiClient.swift`) calls these endpoints and expects:
- `/v1/chat` to return `{ "reply": "..." }`
- `/v1/images` to return `{ "images": ["base64...", ...] }`
- `/v1/vision` to return `{ "result": "..." }`

The backend response format matches these expectations exactly.

---

## Deployment

### Heroku

```bash
# Add a Procfile
echo "web: python app.py" > Procfile

heroku create your-app-name
heroku config:set OPENAI_API_KEY=sk-your-key
heroku config:set FLASK_DEBUG=false
git push heroku main
```

### Railway

1. Connect your GitHub repo to [Railway](https://railway.app).
2. Set environment variables in the Railway dashboard.
3. Railway auto-detects Flask apps. If needed, set the start command: `python app.py`.

### Render

1. Create a new Web Service on [Render](https://render.com).
2. Set build command: `pip install -r requirements.txt`
3. Set start command: `python app.py`
4. Add environment variables in the dashboard.

### Docker

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5001
CMD ["python", "app.py"]
```

```bash
docker build -t swiftkit-backend .
docker run -e OPENAI_API_KEY=sk-your-key -p 5001:5001 swiftkit-backend
```

---

## Security Notes

- **Never commit your `.env` file** — it is gitignored.
- The API key stays server-side; the iOS app only talks to this Flask server.
- For production, add authentication (e.g., a shared secret or JWT) to protect endpoints.
- Consider adding rate limiting with `flask-limiter` for production use.
