#!/bin/bash
# Detect project stack from files in current directory
if [ -f "package.json" ]; then echo "node"
elif ls *.csproj 1>/dev/null 2>&1 || ls *.sln 1>/dev/null 2>&1; then echo "dotnet"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then echo "python"
elif [ -f "go.mod" ]; then echo "go"
elif [ -f "Cargo.toml" ]; then echo "rust"
elif [ -f "Gemfile" ]; then echo "ruby"
elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then echo "java"
else echo "unknown"
fi
