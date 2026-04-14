#!/usr/bin/env python3
"""
Memory Garden Web Server
Serves the p5.js frontend and proxies Replicate API calls.

Launch:
    uv run --with flask --with replicate server.py
"""

from __future__ import annotations

import base64
import io
import json
import os
import time
import urllib.request
import webbrowser
from pathlib import Path
from threading import Timer

from flask import Flask, jsonify, request, send_from_directory

ROOT = Path(__file__).resolve().parent
MEMORY_GARDEN_DIR = ROOT / "MemoryGarden"
MEMORIES_DIR = ROOT / "memories_of_your_class_only"
MODEL = "google/nano-banana-pro"
LLM_MODEL = "deepseek-ai/deepseek-v3.1"
# Load API token from .env file or environment
_env_path = ROOT / ".env"
if _env_path.exists():
    for _line in _env_path.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _k, _v = _line.split("=", 1)
            os.environ.setdefault(_k.strip(), _v.strip())

REPLICATE_API_TOKEN = os.environ.get("REPLICATE_API_TOKEN", "")

app = Flask(__name__, static_folder=str(ROOT / "static"))


@app.route("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory(app.static_folder, filename)


@app.route("/api/garden")
def get_garden():
    garden_path = ROOT / "garden.json"
    with open(garden_path, encoding="utf-8") as f:
        data = json.load(f)
    return jsonify(data)


@app.route("/api/generate", methods=["POST"])
def generate():
    body = request.get_json()
    image_b64 = body.get("image", "")
    prompt = body.get("prompt", "")

    if not image_b64 or not prompt:
        return jsonify({"error": "Missing image or prompt"}), 400

    # Strip data URL prefix if present
    if "," in image_b64:
        image_b64 = image_b64.split(",", 1)[1]

    image_bytes = base64.b64decode(image_b64)
    image_file = io.BytesIO(image_bytes)
    image_file.name = "flower.png"

    import replicate

    client = replicate.Client(api_token=REPLICATE_API_TOKEN)

    try:
        output = client.run(
            MODEL,
            input={
                "prompt": prompt,
                "image_input": [image_file],
                "aspect_ratio": "match_input_image",
                "resolution": "2K",
                "output_format": "png",
            },
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    # Download the result
    result_bytes = None
    if hasattr(output, "read"):
        result_bytes = output.read()
    elif isinstance(output, (list, tuple)) and output:
        item = output[0]
        if hasattr(item, "read"):
            result_bytes = item.read()
        else:
            result_bytes = urllib.request.urlopen(str(item)).read()
    else:
        result_bytes = urllib.request.urlopen(str(output)).read()

    # Save to MemoryGarden/
    out_name = f"nano-banana-{time.strftime('%Y%m%d-%H%M%S')}.png"
    out_path = MEMORY_GARDEN_DIR / out_name
    out_path.write_bytes(result_bytes)

    # Return as base64
    result_b64 = base64.b64encode(result_bytes).decode("ascii")
    return jsonify({
        "image": f"data:image/png;base64,{result_b64}",
        "filename": out_name,
    })


@app.route("/api/students")
def list_students():
    """List available student memory files."""
    files = sorted(p.stem for p in MEMORIES_DIR.glob("*.json"))
    return jsonify(files)


@app.route("/api/process-memories", methods=["POST"])
def process_memories():
    """Use DeepSeek V3.1 to convert raw student memories into garden.json format."""
    body = request.get_json()
    student = body.get("student", "")

    student_file = MEMORIES_DIR / f"{student}.json"
    if not student_file.exists():
        return jsonify({"error": f"Student file not found: {student}"}), 404

    with open(student_file, encoding="utf-8") as f:
        raw_memories = json.load(f)

    student_name = raw_memories[0].get("name", student) if raw_memories else student
    activities = [m.get("activity", "") for m in raw_memories if m.get("activity")]

    # Load the example garden.json as a format reference
    with open(ROOT / "garden.json", encoding="utf-8") as f:
        example = json.load(f)
    example_cluster = json.dumps(example["all_clusters"][0], indent=2)

    prompt = f"""Analyze the following personal memories and convert them into a structured JSON format.

For EACH memory, you must:
1. Assign a short "theme" (2-3 words, e.g. "Pure Joy", "Heartbreak", "Quiet Moment")
2. Rate these 5 emotional features as floats:
   - valence: -1.0 (very sad/negative) to 1.0 (very happy/positive)
   - impact: 0.0 (trivial) to 1.0 (life-changing)
   - togetherness: 0.0 (completely alone) to 1.0 (deeply social)
   - motion: 0.0 (completely still) to 1.0 (full of physical movement)
   - length: 0.0 (brief moment) to 1.0 (extended experience)

Here is an example of ONE cluster in the output format:
{example_cluster}

The student's name is: {student_name}

Their memories are:
{chr(10).join(f"- {a}" for a in activities)}

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{{
  "center_name": "{student_name}",
  "all_clusters": [
    ... one object per memory ...
  ]
}}"""

    import replicate

    client = replicate.Client(api_token=REPLICATE_API_TOKEN)

    try:
        output = client.run(
            LLM_MODEL,
            input={
                "prompt": prompt,
                "max_tokens": 4096,
                "temperature": 0.3,
            },
        )
        # Replicate text models return an iterator of text chunks
        result_text = "".join(output)
    except Exception as e:
        return jsonify({"error": f"LLM call failed: {e}"}), 500

    # Extract JSON from response (might have extra text around it)
    try:
        # Try to find JSON in the response
        start = result_text.index("{")
        end = result_text.rindex("}") + 1
        json_str = result_text[start:end]
        garden_data = json.loads(json_str)
    except (ValueError, json.JSONDecodeError) as e:
        return jsonify({"error": f"Failed to parse LLM output: {e}", "raw": result_text}), 500

    # Validate structure
    if "all_clusters" not in garden_data or "center_name" not in garden_data:
        return jsonify({"error": "Invalid garden.json structure from LLM", "raw": result_text}), 500

    return jsonify(garden_data)


if __name__ == "__main__":
    Timer(1.5, lambda: webbrowser.open("http://localhost:8080")).start()
    print("Memory Garden running at http://localhost:8080")
    app.run(host="127.0.0.1", port=8080, debug=False)
