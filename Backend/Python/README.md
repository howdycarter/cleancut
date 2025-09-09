Python Flask backend for AI wrappers (OpenAI)

Overview
- Provides three endpoints that proxy to OpenAI APIs so the iOS app never stores API keys:
  - POST /v1/chat: chat completion (text generation)
  - POST /v1/images: image generation
  - POST /v1/vision: vision (image + text)

Setup
1) Python 3.10+
2) Create a virtualenv and install deps:
   python -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
3) Set env vars:
   export OPENAI_API_KEY=sk-...
   # Optional overrides:
   # export OPENAI_CHAT_MODEL=gpt-4o-mini
   # export OPENAI_IMAGE_MODEL=gpt-image-1
   # export OPENAI_VISION_MODEL=gpt-4o-mini
   export FLASK_ENV=development
   export PORT=5001  # optional
4) Run:
   python app.py

Endpoints
- POST /v1/chat
  Content-Type: application/json
  Body: { "messages": [{"role":"user","content":"Hi"}], "model":"gpt-4o-mini", "temperature":0.7 }
  Returns: { "reply": "...", "usage": {"prompt_tokens":..., "completion_tokens":...} }

- POST /v1/images
  Content-Type: application/json
  Body: { "prompt": "a cute corgi", "count": 2, "size": "512x512", "response_format":"b64_json" }
  Returns: { "images": ["base64...", ...] } or with response_format=url: { "images": ["https://...", ...] }

- POST /v1/vision
  Content-Type: multipart/form-data
  Fields: file=<image binary>, prompt="optional text"
  Returns: { "result": "..." }

Security
- Keep OPENAI_API_KEY server-side only.
- Optionally add an auth token and verify on each request (omitted for brevity).
