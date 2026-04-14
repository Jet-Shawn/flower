# Memory Garden Tutorial

You'll be turning your personal memories into AI-generated flower art — all in the browser.

---

## Step 0 — Download and open the project

1. Go to the GitHub repository link provided by your TA.
2. Click the green **Code** button, then click **Download ZIP**.
3. Find the downloaded `.zip` file (usually in your `Downloads` folder) and **unzip** it.
4. Open **Cursor** (our code editor for this workshop).
5. In Cursor, go to **File → Open Folder** and select the unzipped project folder.

> You should now see the project files (like `server.py`, `TUTORIAL.md`, etc.) in Cursor's sidebar.

---

## Step 1 — Install uv (one time only)

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

## Step 2 — Set up your API key

1. In Cursor's sidebar, find the file called `.env.example` and right-click it, then select **Rename**.
2. Rename it to `.env` (just remove the `.example` part).
3. Open the `.env` file, replace `your_api_key_here` with the API key provided by your TA.
4. Save the file (**Ctrl+S** on Windows / **Cmd+S** on Mac).

---

## Step 3 — Start the Memory Garden

Open your terminal in cursor, navigate to the project folder, and run:

```bash
uv run --with flask --with replicate server.py
```

Your browser will automatically open **http://localhost:8080**. You should see a flower canvas on the left and a control panel on the right.

> If the browser doesn't open automatically, go to http://localhost:8080 manually.
>
> **Mac users:** if you get a 403 error, macOS AirPlay may be using port 5000. Our server uses port 8080 to avoid this.

---

## Step 4 — Load your memories

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

## Step 5 — Explore your flowers

Press **R** on your keyboard (or refresh) to shuffle through your memories. Each memory produces a unique flower — the shape, color, and texture all come from the emotional analysis of that memory.

Take a moment to see how different memories create different flowers. A sad, intense memory will look very different from a happy, calm one.

---

## Step 6 — Generate AI art

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

## Step 7 — Submit

1. Find your 5 generated images in the `MemoryGarden/` folder.
2. **Rename each file with your full name and a number** — for example:
   - `John_Smith_1.png`
   - `John_Smith_2.png`
   - `John_Smith_3.png`
   - `John_Smith_4.png`
   - `John_Smith_5.png`
3. Upload all 5 images to the shared Google Drive folder: https://drive.google.com/drive/folders/1wCa1v2l9Q7qvPiXCMJVWwtCFwCMVwOcZ

---

## Quick reference

| Action | How |
|--------|-----|
| Start the server | `uv run --with flask --with replicate server.py` |
| Shuffle memories | Press **R** |
| Generate AI art | Type prompt + click **Generate with Nano Banana** |
| Stop the server | Press **Ctrl+C** in the terminal |
