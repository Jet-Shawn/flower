# Memory Garden Tutorial

You'll be turning your personal memories into AI-generated flower art — all in the browser.

---

## Step 0 — Install uv (one time only)

**Mac (Terminal):**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

After installing, **restart your terminal** (or run `source ~/.zshrc` on Mac).

Verify it works:

```bash
uv --version
```

---

## Step 1 — Set up your API key

Create a file called `.env` in the project folder with your Replicate API token:

```
REPLICATE_API_TOKEN=your_api_key_here
```

> Ask your TA for the workshop API key if you don't have one.

---

## Step 2 — Start the Memory Garden

Open your terminal, navigate to the project folder, and run:

```bash
cd <path-to-the-flower-folder>
uv run --with flask --with replicate server.py
```

Your browser will automatically open **http://localhost:8080**. You should see a flower canvas on the left and a control panel on the right.

> If the browser doesn't open automatically, go to http://localhost:8080 manually.
>
> **Mac users:** if you get a 403 error, macOS AirPlay may be using port 5000. Our server uses port 8080 to avoid this.

---

## Step 3 — Load your memories

1. In the **Student Memory** dropdown at the top-right, find and select your name.
2. Click **Load Student Memories**.
3. Wait 10–30 seconds — the system uses DeepSeek V3.1 (an AI model) to analyze your memories and assign emotional features to each one.
4. Once loaded, your first memory flower will appear on the canvas.

The **Emotional Features** panel shows the five dimensions that shape your flower:

| Feature | What it means | How it affects the flower |
|---------|--------------|--------------------------|
| **Valence** | Sad (-1) to Happy (+1) | Color warmth, head droop |
| **Impact** | Calm (0) to Intense (1) | Size, petal shape, outline weight |
| **Togetherness** | Solo (0) to Social (1) | Number of petals, ring spacing |
| **Motion** | Still (0) to Lively (1) | Sway speed, hatching texture |
| **Length** | Brief (0) to Detailed (1) | Stem height, petal curl |

---

## Step 4 — Explore your flowers

Press **R** on your keyboard (or refresh) to shuffle through your memories. Each memory produces a unique flower — the shape, color, and texture all come from the emotional analysis of that memory.

Take a moment to see how different memories create different flowers. A sad, intense memory will look very different from a happy, calm one.

---

## Step 5 — Generate AI art

Once you find a flower you like:

1. Choose **Flower Head Only** or **With Stem** in the export mode dropdown.
2. Type a prompt describing the style you want. You **must include "photorealistic"** so we have a general theme.
3. Click **Generate with Nano Banana**.
4. Wait 10–30 seconds for the AI to transform your flower.
5. The result will appear below the button.

**Example prompt:**

> Turn this into an exotic flower. Stick to the structure I am providing you. Don't leave the confines of the computer-generated image I am providing you, but make it look tropical photorealistic.

Feel free to be creative with your prompt — try different styles and see what happens.

Your generated images are automatically saved to the `MemoryGarden/` folder.

---

## Step 6 — Submit

1. Find your generated image in the `MemoryGarden/` folder (named `nano-banana-YYYYMMDD-HHMMSS.png`).
2. **Rename the file after yourself** — good data discipline matters!
3. Upload your final image to the shared Google Drive folder.

---

## Quick reference

| Action | How |
|--------|-----|
| Start the server | `uv run --with flask --with replicate server.py` |
| Shuffle memories | Press **R** |
| Generate AI art | Type prompt + click **Generate with Nano Banana** |
| Stop the server | Press **Ctrl+C** in the terminal |
