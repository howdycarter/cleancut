"""
TheSwiftKit — Python Flask AI Backend
======================================
A lightweight Flask server that proxies requests from the iOS app to OpenAI APIs.
This keeps the OpenAI API key server-side and provides a clean REST interface.

Endpoints:
    POST /v1/chat    — Text chat completion (GPT-4o)
    POST /v1/images  — Image generation (gpt-image-1.5)
    POST /v1/vision  — Image analysis / vision (GPT-4o with vision)
    GET  /health      — Health check

Setup:
    1. Copy .env.example to .env and fill in your OPENAI_API_KEY
    2. pip install -r requirements.txt
    3. python app.py
"""

import base64
import os
import traceback

from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables from .env file (if present)
load_dotenv()

# ---------------------------------------------------------------------------
# OpenAI SDK import — gracefully handle missing package
# ---------------------------------------------------------------------------
try:
    from openai import OpenAI, APIError, APIConnectionError, RateLimitError, APITimeoutError
except ImportError:  # pragma: no cover
    OpenAI = None
    APIError = Exception
    APIConnectionError = Exception
    RateLimitError = Exception
    APITimeoutError = Exception

# ---------------------------------------------------------------------------
# Configuration (all overridable via environment variables)
# ---------------------------------------------------------------------------
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "")  # optional override for proxies

# Default OpenAI models — override via env vars if desired
CHAT_MODEL = os.environ.get("OPENAI_CHAT_MODEL", "gpt-4o")
IMAGE_MODEL = os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1.5")
VISION_MODEL = os.environ.get("OPENAI_VISION_MODEL", "gpt-4o")

# Limits
MAX_CHAT_MESSAGES = 50          # Max messages in a single chat request
MAX_IMAGE_SIZE_BYTES = 20_000_000  # 20 MB max for vision image uploads
MAX_IMAGE_COUNT = 4             # Max images per generation request

# ---------------------------------------------------------------------------
# Flask app setup
# ---------------------------------------------------------------------------
app = Flask(__name__)

# CORS — allow all origins for development.
# In production, restrict this to your app's domain or use a reverse proxy.
# Example: CORS(app, origins=["https://yourapp.com"])
CORS(app)

# ---------------------------------------------------------------------------
# Rate Limiting (recommendations)
# ---------------------------------------------------------------------------
# For production, add rate limiting to protect against abuse. Options:
#   - flask-limiter: pip install flask-limiter
#     from flask_limiter import Limiter
#     limiter = Limiter(app, default_limits=["60 per minute"])
#   - Reverse proxy rate limiting (nginx, Cloudflare, etc.)
#   - OpenAI's own rate limits will also apply as a backstop.
# ---------------------------------------------------------------------------


def get_client() -> "OpenAI":
    """
    Create and return an OpenAI client instance.
    Raises RuntimeError if the SDK is missing or the API key is not configured.
    """
    if OpenAI is None:
        raise RuntimeError(
            "The 'openai' package is not installed. Run: pip install openai"
        )
    if not OPENAI_API_KEY:
        raise RuntimeError(
            "OPENAI_API_KEY environment variable is not set. "
            "Create a .env file or export the variable."
        )
    kwargs = {"api_key": OPENAI_API_KEY}
    if OPENAI_BASE_URL:
        kwargs["base_url"] = OPENAI_BASE_URL
    return OpenAI(**kwargs)


# ---------------------------------------------------------------------------
# Helper: standard error response
# ---------------------------------------------------------------------------
def error_response(message: str, status_code: int = 500, details: str = None):
    """Return a consistent JSON error response."""
    payload = {"error": message}
    if details:
        payload["details"] = details
    return jsonify(payload), status_code


# ===========================================================================
# Health Check
# ===========================================================================
@app.get("/health")
def health():
    """Simple health check endpoint — useful for uptime monitors and deploys."""
    return jsonify({
        "ok": True,
        "models": {
            "chat": CHAT_MODEL,
            "image": IMAGE_MODEL,
            "vision": VISION_MODEL,
        }
    })


# ===========================================================================
# POST /v1/chat — Text Chat Completion
# ===========================================================================
@app.post("/v1/chat")
def chat():
    """
    Chat completion endpoint using OpenAI's chat API.

    Request JSON:
        {
            "messages": [{"role": "user", "content": "Hello"}],
            "model": "gpt-4o",           // optional, defaults to CHAT_MODEL
            "temperature": 0.7            // optional, 0.0–2.0
        }

    Response JSON:
        {
            "reply": "AI response text",
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 25,
                "total_tokens": 35
            }
        }
    """
    # --- Parse request ---
    data = request.get_json(force=True, silent=True) or {}
    messages = data.get("messages", [])
    model = data.get("model", CHAT_MODEL)
    temperature = data.get("temperature", 0.7)

    # --- Validate ---
    if not messages:
        return error_response("'messages' field is required and must be a non-empty array.", 400)

    if not isinstance(messages, list):
        return error_response("'messages' must be an array of message objects.", 400)

    if len(messages) > MAX_CHAT_MESSAGES:
        return error_response(
            f"Too many messages. Maximum is {MAX_CHAT_MESSAGES}.", 400
        )

    # Validate each message has role and content
    for i, msg in enumerate(messages):
        if not isinstance(msg, dict) or "role" not in msg or "content" not in msg:
            return error_response(
                f"Message at index {i} must have 'role' and 'content' fields.", 400
            )

    # Clamp temperature to valid range
    try:
        temperature = max(0.0, min(2.0, float(temperature)))
    except (ValueError, TypeError):
        temperature = 0.7

    # --- Call OpenAI ---
    try:
        client = get_client()
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
        )

        choice = resp.choices[0]
        reply = choice.message.content or ""
        usage = getattr(resp, "usage", None)

        return jsonify({
            "reply": reply,
            "usage": {
                "prompt_tokens": getattr(usage, "prompt_tokens", None),
                "completion_tokens": getattr(usage, "completion_tokens", None),
                "total_tokens": getattr(usage, "total_tokens", None),
            }
        })

    except RateLimitError:
        return error_response("OpenAI rate limit exceeded. Please try again later.", 429)
    except APITimeoutError:
        return error_response("OpenAI request timed out. Please try again.", 504)
    except APIConnectionError:
        return error_response("Could not connect to OpenAI. Check network or API status.", 502)
    except APIError as e:
        return error_response(f"OpenAI API error: {str(e)}", 502)
    except RuntimeError as e:
        return error_response(str(e), 503)
    except Exception as e:
        traceback.print_exc()
        return error_response("Internal server error during chat completion.", 500, details=str(e))


# ===========================================================================
# POST /v1/images — Image Generation
# ===========================================================================
@app.post("/v1/images")
def images():
    """
    Image generation endpoint using OpenAI's image generation API.

    Uses gpt-image-1.5 model which returns base64-encoded images by default.

    Request JSON:
        {
            "prompt": "A cute corgi in a space suit",
            "count": 2,                    // optional, 1–4, default 2
            "size": "1024x1024",           // optional, see allowed sizes below
            "response_format": "b64_json"  // accepted for compatibility, not forwarded
        }

    Allowed sizes for gpt-image-1.5:
        - "1024x1024" (square, default)
        - "1024x1536" (portrait)
        - "1536x1024" (landscape)
        - "auto"

    Response JSON:
        {
            "images": ["base64_encoded_string", ...]
        }
    """
    # --- Parse request ---
    data = request.get_json(force=True, silent=True) or {}
    prompt = data.get("prompt", "").strip()
    count = data.get("count", 2)
    size = data.get("size", "1024x1024")
    # Note: response_format is accepted from the client for compatibility
    # but gpt-image-1.5 returns b64_json by default so we don't forward it.
    _ = data.get("response_format")

    # --- Validate ---
    if not prompt:
        return error_response("'prompt' field is required and cannot be empty.", 400)

    # Clamp count to safe range
    try:
        count = max(1, min(MAX_IMAGE_COUNT, int(count)))
    except (ValueError, TypeError):
        count = 2

    # --- Normalize image size ---
    mapped_size = _normalize_image_size(size)

    # --- Call OpenAI ---
    try:
        client = get_client()
        resp = client.images.generate(
            model=IMAGE_MODEL,
            prompt=prompt,
            n=count,
            size=mapped_size,
        )

        # Extract base64 image data from the response
        result_images = []
        for d in resp.data:
            b64 = getattr(d, "b64_json", None)
            if b64:
                result_images.append(b64)
            else:
                # Fallback: some models/configurations may return URLs
                url = getattr(d, "url", None)
                if url:
                    result_images.append(url)

        if not result_images:
            return error_response("Image generation succeeded but no image data was returned.", 500)

        return jsonify({"images": result_images})

    except RateLimitError:
        return error_response("OpenAI rate limit exceeded. Please try again later.", 429)
    except APITimeoutError:
        return error_response("OpenAI request timed out. Image generation can take a while.", 504)
    except APIConnectionError:
        return error_response("Could not connect to OpenAI. Check network or API status.", 502)
    except APIError as e:
        return error_response(f"OpenAI API error: {str(e)}", 502)
    except RuntimeError as e:
        return error_response(str(e), 503)
    except Exception as e:
        traceback.print_exc()
        return error_response("Internal server error during image generation.", 500, details=str(e))


def _normalize_image_size(size_str: str) -> str:
    """
    Normalize a requested image size to one of the sizes supported by
    gpt-image-1.5: 1024x1024, 1024x1536, 1536x1024, or auto.

    If the requested size doesn't match, we map it based on aspect ratio:
        - Square -> 1024x1024
        - Landscape (wider) -> 1536x1024
        - Portrait (taller) -> 1024x1536
    """
    allowed = {"1024x1024", "1024x1536", "1536x1024", "auto"}
    if size_str in allowed:
        return size_str
    try:
        parts = size_str.lower().split("x")
        if len(parts) == 2:
            w, h = int(parts[0]), int(parts[1])
            if w <= 0 or h <= 0:
                return "1024x1024"
            if w == h:
                return "1024x1024"
            return "1536x1024" if w > h else "1024x1536"
    except (ValueError, IndexError):
        pass
    return "1024x1024"


# ===========================================================================
# POST /v1/vision — Image Analysis (Vision)
# ===========================================================================
@app.post("/v1/vision")
def vision():
    """
    Vision endpoint — analyze an image using GPT-4o's vision capability.

    Request: multipart/form-data
        - file: image binary (JPEG, PNG, etc.) — required
        - prompt: text prompt for analysis — optional, defaults to "Describe this image."

    Response JSON:
        {
            "result": "AI analysis of the image"
        }
    """
    # --- Validate file presence ---
    if "file" not in request.files:
        return error_response(
            "'file' field is required. Send an image as multipart/form-data.", 400
        )

    prompt = request.form.get("prompt", "Describe this image.").strip()
    if not prompt:
        prompt = "Describe this image."

    file = request.files["file"]

    # --- Read and validate image data ---
    img_bytes = file.read()

    if not img_bytes:
        return error_response("The uploaded file is empty.", 400)

    if len(img_bytes) > MAX_IMAGE_SIZE_BYTES:
        return error_response(
            f"Image too large. Maximum size is {MAX_IMAGE_SIZE_BYTES // 1_000_000} MB.",
            413
        )

    # Detect MIME type from file extension or default to jpeg
    filename = file.filename or "image.jpg"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "jpg"
    mime_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
                "gif": "image/gif", "webp": "image/webp"}
    mime_type = mime_map.get(ext, "image/jpeg")

    # Encode image to base64
    b64 = base64.b64encode(img_bytes).decode("utf-8")

    # --- Call OpenAI Vision ---
    try:
        client = get_client()

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{mime_type};base64,{b64}"
                        }
                    },
                ],
            }
        ]

        resp = client.chat.completions.create(
            model=VISION_MODEL,
            messages=messages,
            temperature=0.2,
            max_tokens=1024,
        )

        reply = resp.choices[0].message.content or ""
        return jsonify({"result": reply})

    except RateLimitError:
        return error_response("OpenAI rate limit exceeded. Please try again later.", 429)
    except APITimeoutError:
        return error_response("OpenAI request timed out. Please try again.", 504)
    except APIConnectionError:
        return error_response("Could not connect to OpenAI. Check network or API status.", 502)
    except APIError as e:
        return error_response(f"OpenAI API error: {str(e)}", 502)
    except RuntimeError as e:
        return error_response(str(e), 503)
    except Exception as e:
        traceback.print_exc()
        return error_response("Internal server error during vision analysis.", 500, details=str(e))


# ===========================================================================
# Global error handlers
# ===========================================================================
@app.errorhandler(404)
def not_found(e):
    return error_response("Endpoint not found.", 404)


@app.errorhandler(405)
def method_not_allowed(e):
    return error_response("Method not allowed.", 405)


@app.errorhandler(413)
def payload_too_large(e):
    return error_response("Request payload too large.", 413)


@app.errorhandler(500)
def internal_error(e):
    return error_response("Internal server error.", 500)


# ===========================================================================
# Run the server
# ===========================================================================
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    debug = os.environ.get("FLASK_DEBUG", "true").lower() in ("true", "1", "yes")

    print(f"Starting TheSwiftKit AI Backend on port {port}")
    print(f"  Chat model:   {CHAT_MODEL}")
    print(f"  Image model:  {IMAGE_MODEL}")
    print(f"  Vision model: {VISION_MODEL}")
    print(f"  Debug mode:   {debug}")

    app.run(host="0.0.0.0", port=port, debug=debug)
