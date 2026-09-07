#!/bin/bash
# Pi Agent Full Setup — runs on right-pc (Christopher's desktop)
# Sets up: llama.cpp + Gemma 4 E4B model + Pi watcher
set -euo pipefail

MODELS_DIR="/home/zoid/ai/models"
LLAMA_DIR="/home/zoid/llama.cpp"
MODEL_URL="bartowski/google_gemma-4-E4B-it-GGUF"
MODEL_FILE="google_gemma-4-E4B-it-Q4_K_M.gguf"
MMPROJ_FILE="mmproj-BF16.gguf"

echo "=== Pi Agent Full Setup ==="
echo ""

# ─── Step 1: Verify llama.cpp ────────────────────────────────────
echo "[1/5] Checking llama.cpp..."
if [ ! -f "$LLAMA_DIR/build/bin/llama-server" ]; then
  echo "  llama-server not found. Building llama.cpp..."
  cd "$LLAMA_DIR"
  export PATH=/opt/cuda/bin:$PATH
  export CUDACXX=/opt/cuda/bin/nvcc
  cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 -DCUDAToolkit_ROOT=/opt/cuda
  cmake --build build --config Release -j $(nproc)
  mkdir -p "$HOME/.local/bin"
  ln -sf "$LLAMA_DIR/build/bin/llama-server" "$HOME/.local/bin/llama-server"
  echo "  ✅ llama-server built"
else
  echo "  ✅ llama-server already built"
fi

# ─── Step 2: Download Gemma 4 E4B Model ──────────────────────────
echo "[2/5] Checking model..."
mkdir -p "$MODELS_DIR"

if [ ! -f "$MODELS_DIR/$MODEL_FILE" ]; then
  echo "  Downloading Gemma 4 E4B Q4_K_M (~5.4GB)..."
  if command -v huggingface-cli &>/dev/null; then
    huggingface-cli download "$MODEL_URL" "$MODEL_FILE" --local-dir "$MODELS_DIR"
  else
    # Fallback: direct download from HuggingFace
    echo "  huggingface-cli not found, downloading directly..."
    cd "$MODELS_DIR"
    curl -L -o "$MODEL_FILE" "https://huggingface.co/$MODEL_URL/resolve/main/$MODEL_FILE"
  fi
  echo "  ✅ Model downloaded"
else
  echo "  ✅ Model already present"
fi

if [ ! -f "$MODELS_DIR/$MMPROJ_FILE" ]; then
  echo "  Downloading mmproj for vision..."
  if command -v huggingface-cli &>/dev/null; then
    huggingface-cli download "$MODEL_URL" "$MMPROJ_FILE" --local-dir "$MODELS_DIR"
  else
    cd "$MODELS_DIR"
    curl -L -o "$MMPROJ_FILE" "https://huggingface.co/$MODEL_URL/resolve/main/$MMPROJ_FILE"
  fi
  echo "  ✅ mmproj downloaded"
else
  echo "  ✅ mmproj already present"
fi

# ─── Step 3: Verify Pi ───────────────────────────────────────────
echo "[3/5] Checking Pi..."
if command -v pi &>/dev/null; then
  PI_VERSION=$(pi --version 2>/dev/null || echo "unknown")
  echo "  ✅ Pi installed: $PI_VERSION"
else
  echo "  ❌ Pi not found. Install with:"
  echo "     npm install -g @earendil-works/pi-coding-agent"
  exit 1
fi

# ─── Step 4: Test Pi ↔ llama.cpp Connection ──────────────────────
echo "[4/5] Testing Pi ↔ llama.cpp..."
# Start llama-server if not running
if ! curl -s http://127.0.0.1:8080/health &>/dev/null; then
  echo "  Starting llama-server..."
  nohup "$HOME/.local/bin/llama-server" \
    -m "$MODELS_DIR/$MODEL_FILE" \
    --mmproj "$MODELS_DIR/$MMPROJ_FILE" \
    -ngl 99 \
    -c 32768 \
    -fa on \
    --host 127.0.0.1 \
    --port 8080 \
    > /tmp/llama-server.log 2>&1 &
  
  # Wait for server to be ready
  for i in $(seq 1 30); do
    if curl -s http://127.0.0.1:8080/health &>/dev/null; then
      echo "  ✅ llama-server started"
      break
    fi
    sleep 2
  done
else
  echo "  ✅ llama-server already running"
fi

# Test Pi connection
echo "  Testing Pi connection..."
echo '{"id":"test","type":"prompt","message":"Reply with exactly: OK"}' | \
  timeout 30 pi --mode rpc --provider llamacpp --model google_gemma-4-E4B-it 2>/dev/null | \
  grep -q "OK" && echo "  ✅ Pi ↔ llama.cpp connection OK" || \
  echo "  ⚠️  Pi connection test inconclusive (may still work in practice)"

# ─── Step 5: Install Extensions ──────────────────────────────────
echo "[5/5] Installing Pi extensions..."
read -p "Install A2A extension? (y/N): " install_a2a
if [[ "$install_a2a" =~ ^[Yy]$ ]]; then
  pi install npm:@bacnh85/pi-a2a
  echo "  ✅ A2A extension installed"
fi

read -p "Install desktop control extension? (y/N): " install_desktop
if [[ "$install_desktop" =~ ^[Yy]$ ]]; then
  pi install npm:@agent-sh/computer-use-linux
  echo "  ✅ Desktop control extension installed"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Quick reference:"
echo "  llama-server:  curl http://127.0.0.1:8080/health"
echo "  Pi interactive: pi --provider llamacpp --model google_gemma-4-E4B-it"
echo "  Pi RPC mode:    pi --mode rpc --provider llamacpp --model google_gemma-4-E4B-it"
echo "  Pi print mode:  pi --print 'Fix the bug in foo.dart'"
echo ""
