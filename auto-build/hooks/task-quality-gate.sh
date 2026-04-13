#!/bin/bash
# TaskCompleted hook: Build + test must pass before task closes
# Exit 2 = block completion, stderr fed back to Claude
# Exit 0 = allow completion

# Detect project stack
detect_stack() {
  if [ -f "package.json" ]; then echo "node"
  elif ls *.csproj 1>/dev/null 2>&1 || ls *.sln 1>/dev/null 2>&1; then echo "dotnet"
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then echo "python"
  elif [ -f "go.mod" ]; then echo "go"
  elif [ -f "Cargo.toml" ]; then echo "rust"
  else echo "unknown"
  fi
}

STACK=$(detect_stack)

case "$STACK" in
  node)
    npm run build 2>&1 || { echo "NODE BUILD FAILED" >&2; exit 2; }
    npm test 2>&1 || { echo "NODE TESTS FAILED" >&2; exit 2; }
    ;;
  dotnet)
    SLN=$(ls *.sln 2>/dev/null | head -1)
    if [ -n "$SLN" ]; then
      dotnet build "$SLN" 2>&1 || { echo "DOTNET BUILD FAILED" >&2; exit 2; }
      dotnet test "$SLN" --no-build 2>&1 || { echo "DOTNET TESTS FAILED" >&2; exit 2; }
    fi
    ;;
  python)
    if [ -d "tests" ]; then
      python3 -m pytest tests/ -q --tb=short 2>&1 || { echo "PYTHON TESTS FAILED" >&2; exit 2; }
    fi
    command -v ruff >/dev/null 2>&1 && {
      ruff check src/ 2>&1 || { echo "PYTHON LINT FAILED" >&2; exit 2; }
    }
    ;;
  go)
    go build ./... 2>&1 || { echo "GO BUILD FAILED" >&2; exit 2; }
    go test ./... 2>&1 || { echo "GO TESTS FAILED" >&2; exit 2; }
    ;;
  rust)
    cargo build 2>&1 || { echo "RUST BUILD FAILED" >&2; exit 2; }
    cargo test 2>&1 || { echo "RUST TESTS FAILED" >&2; exit 2; }
    ;;
  *)
    # Unknown stack — skip quality gate
    ;;
esac

exit 0
