import base64
import io
import os

from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

try:
    from openai import OpenAI
except Exception:  # pragma: no cover
    OpenAI = None

# OpenAI configuration
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "")  # optional override

# Default OpenAI models (override via env if desired)
CHAT_MODEL = os.environ.get("OPENAI_CHAT_MODEL", "gpt-4o-mini")
IMAGE_MODEL = os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1")
VISION_MODEL = os.environ.get("OPENAI_VISION_MODEL", "gpt-4o-mini")

app = Flask(__name__)
CORS(app)


def get_client():
    if OpenAI is None:
        raise RuntimeError("openai package not installed")
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY is not set")
    if OPENAI_BASE_URL:
        return OpenAI(api_key=OPENAI_API_KEY, base_url=OPENAI_BASE_URL)
    return OpenAI(api_key=OPENAI_API_KEY)


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/v1/chat")
def chat():
    data = request.get_json(force=True, silent=True) or {}
    messages = data.get("messages", [])
    model = data.get("model", CHAT_MODEL)
    temperature = float(data.get("temperature", 0.7))

    if not messages:
        return jsonify({"error": "messages required"}), 400

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


@app.post("/v1/images")
def images():
    data = request.get_json(force=True, silent=True) or {}
    prompt = data.get("prompt", "")
    count = int(data.get("count", 2))
    size = data.get("size", "512x512")
    # Note: OpenAI's images.generate for gpt-image-1 does not accept response_format; it returns b64_json by default.
    # We keep parsing the field from client for compatibility but do not forward it to OpenAI.
    _ = data.get("response_format")

    def normalize_image_size(s: str) -> str:
        allowed = {"1024x1024", "1024x1536", "1536x1024", "auto"}
        if s in allowed:
            return s
        try:
            parts = s.lower().split("x")
            if len(parts) == 2:
                w, h = int(parts[0]), int(parts[1])
                if w <= 0 or h <= 0:
                    return "1024x1024"
                if w == h:
                    return "1024x1024"
                # preserve aspect: landscape vs portrait
                return "1536x1024" if w > h else "1024x1536"
        except Exception:
            pass
        return "1024x1024"

    mapped_size = normalize_image_size(size)

    if not prompt:
        return jsonify({"error": "prompt required"}), 400

    client = get_client()
    resp = client.images.generate(
        model=IMAGE_MODEL,
        prompt=prompt,
        n=count,
        size=mapped_size,
    )

    images = [getattr(d, "b64_json", None) for d in resp.data]
    images = [i for i in images if i]
    return jsonify({"images": images})


@app.post("/v1/vision")
def vision():
    # Expect multipart/form-data with `file` and optional `prompt`
    if "file" not in request.files:
        return jsonify({"error": "file required"}), 400
    prompt = request.form.get("prompt", "Describe this image.")

    file = request.files["file"]
    img_bytes = file.read()
    b64 = base64.b64encode(img_bytes).decode("utf-8")

    client = get_client()
    # Vision via chat with image content
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
            ],
        }
    ]
    resp = client.chat.completions.create(
        model=VISION_MODEL,
        messages=messages,
        temperature=0.2,
    )
    reply = resp.choices[0].message.content or ""
    return jsonify({"result": reply})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    app.run(host="0.0.0.0", port=port, debug=True)
