# Memory Garden

> Original Memory Garden concept and Processing sketch by [Alexander Bie](https://scholar.google.com/citations?user=u_gpRfAAAAAJ&hl=da). Web adaptation built with Claude Code.

Turn personal memories into AI-generated flower art — all in the browser.

Each memory is analyzed for five emotional dimensions (valence, impact, togetherness, motion, length), which drive the shape, color, and texture of a procedurally generated flower. The flower is then transformed into a stylized artwork using an AI image model.

![Memory Garden](MemoryGarden/Nano%20Banana%20Example.png)

## Quick Start

### 1. Install uv

**Mac:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### 2. Set up API key

```bash
cp .env.example .env
```

Edit `.env` and replace `your_replicate_api_key_here` with your [Replicate](https://replicate.com) API token.

### 3. Run

```bash
uv run --with flask --with replicate server.py
```

Your browser will open **http://localhost:8080** automatically.

## How It Works

```
Your Memories (text)
      |
      v
DeepSeek V3.1 (LLM)          -- analyzes emotional features
      |
      v
5 Emotional Dimensions         -- valence, impact, togetherness, motion, length
      |
      v
p5.js (browser)                -- generates procedural origami flower
      |
      v
Nano Banana Pro (diffusion)    -- transforms into stylized artwork
      |
      v
Final Image
```

## Project Structure

```
flower/
  server.py                    Flask backend + Replicate API proxy
  static/
    index.html                 Web UI
    sketch.js                  p5.js flower renderer (ported from Processing)
  garden.json                  Memory data (emotional features)
  .env.example                 API key template (copy to .env)
  MemoryGarden/
    MemoryGarden.pde           Original Processing sketch
  TUTORIAL.md                  Student tutorial
```

## Documentation

- **[TUTORIAL.md](TUTORIAL.md)** — Step-by-step student guide

