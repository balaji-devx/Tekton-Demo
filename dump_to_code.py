#!/usr/bin/env python3
"""
dump_to_code.py

Traverses the project folder, extracts all project source code, configuration
files, manifests, scripts, and documentation, and consolidates them into a
clean, structured Markdown document (tekton.md).

It also prints the extracted code to stdout.

Usage:
    python dump_to_code.py
    python dump_to_code.py --output tekton.md
    python dump_to_code.py --no-print
"""

import os
import sys
import argparse
from pathlib import Path

# Directories to ignore
IGNORE_DIRS = {
    ".git",
    "node_modules",
    "__pycache__",
    ".vscode",
    ".idea",
    "coverage",
    ".nyc_output",
    "logs",
    ".minikube",
    "dist",
    "build",
}

# Specific filenames to ignore
IGNORE_FILES = {
    "dump_to_code.py",     # Script itself
    "tekton.md",           # Generated markdown output
    ".DS_Store",
    "Thumbs.db",
    "package-lock.json.backup",
}

# Extensions to ignore (binaries, compiled files, etc.)
IGNORE_EXTENSIONS = {
    ".pyc",
    ".pyo",
    ".pyd",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".iso",
    ".tar",
    ".gz",
    ".zip",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".woff",
    ".woff2",
    ".ttf",
    ".eot",
}

# Mapping of file extensions to markdown code block language identifiers
EXTENSION_LANG_MAP = {
    ".js": "javascript",
    ".mjs": "javascript",
    ".cjs": "javascript",
    ".jsx": "javascript",
    ".ts": "typescript",
    ".tsx": "typescript",
    ".json": "json",
    ".html": "html",
    ".htm": "html",
    ".css": "css",
    ".scss": "scss",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".ps1": "powershell",
    ".psm1": "powershell",
    ".sh": "bash",
    ".bash": "bash",
    ".zsh": "bash",
    ".py": "python",
    ".md": "markdown",
    ".txt": "text",
    ".env": "shell",
}

# Mapping of specific filenames to language identifiers
FILENAME_LANG_MAP = {
    "dockerfile": "dockerfile",
    ".dockerignore": "dockerfile",
    ".gitignore": "gitignore",
}


def is_binary_file(filepath: Path) -> bool:
    """Check if a file appears to be binary by checking for null bytes."""
    try:
        with open(filepath, "tr", encoding="utf-8") as f:
            f.read(1024)
            return False
    except (UnicodeDecodeError, PermissionError):
        return True


def get_language(filepath: Path) -> str:
    """Determine the syntax highlighting language for Markdown fences."""
    filename_lower = filepath.name.lower()
    if filename_lower in FILENAME_LANG_MAP:
        return FILENAME_LANG_MAP[filename_lower]
    
    ext = filepath.suffix.lower()
    return EXTENSION_LANG_MAP.get(ext, "text")


def get_code_fence(content: str) -> str:
    """Return ``` or ```` (or more) if the content itself contains backticks."""
    max_consecutive_backticks = 0
    current_count = 0
    for char in content:
        if char == "`":
            current_count += 1
            if current_count > max_consecutive_backticks:
                max_consecutive_backticks = current_count
        else:
            current_count = 0
    fence_length = max(3, max_consecutive_backticks + 1)
    return "`" * fence_length


def collect_project_files(root_dir: Path, output_file: str):
    """Recursively collect eligible files from the project root."""
    collected = []
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Modify dirnames in-place to prune ignored directories
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS and not d.startswith(".git")]
        
        for fname in sorted(filenames):
            if fname in IGNORE_FILES or fname == output_file:
                continue
            
            fpath = Path(dirpath) / fname
            if fpath.suffix.lower() in IGNORE_EXTENSIONS:
                continue
            
            if is_binary_file(fpath):
                continue
            
            rel_path = fpath.relative_to(root_dir)
            collected.append((rel_path, fpath))
    
    # Sort files naturally by relative path string
    collected.sort(key=lambda x: str(x[0]).replace("\\", "/"))
    return collected


def generate_markdown(root_dir: Path, collected_files: list) -> str:
    """Build the complete consolidated markdown string."""
    project_name = root_dir.name or "Tekton Project"
    lines = []
    
    lines.append(f"# Project Codebase Dump: {project_name}\n")
    lines.append(f"> Auto-generated from `{root_dir.resolve()}`\n")
    lines.append(f"> Total Files: **{len(collected_files)}**\n")
    lines.append("---\n")
    
    # Table of Contents
    lines.append("## Table of Contents\n")
    lines.append("| # | File Path | Language | Lines | Size (Bytes) |")
    lines.append("|---|-----------|----------|-------|--------------|")
    
    file_metadata = []
    for idx, (rel_path, abs_path) in enumerate(collected_files, start=1):
        rel_str = str(rel_path).replace("\\", "/")
        lang = get_language(abs_path)
        try:
            with open(abs_path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
            line_count = len(content.splitlines())
            size_bytes = os.path.getsize(abs_path)
        except Exception as e:
            content = f"Error reading file: {e}"
            line_count = 0
            size_bytes = 0
        
        anchor = rel_str.lower().replace("/", "").replace(".", "").replace("-", "").replace("_", "")
        lines.append(f"| {idx} | [{rel_str}](#{anchor}) | `{lang}` | {line_count:,} | {size_bytes:,} |")
        file_metadata.append((rel_str, abs_path, lang, content, anchor))
    
    lines.append("\n---\n")
    
    # File Contents
    for idx, (rel_str, abs_path, lang, content, anchor) in enumerate(file_metadata, start=1):
        fence = get_code_fence(content)
        lines.append(f"## {idx}. `{rel_str}`\n")
        lines.append(f"**Path:** `{rel_str}`  ")
        lines.append(f"**Language:** `{lang}`\n")
        lines.append(f"{fence}{lang}")
        lines.append(content if content.endswith("\n") else content + "\n")
        lines.append(f"{fence}\n")
        lines.append("---\n")
    
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Dump all project code into tekton.md and print to console."
    )
    parser.add_argument(
        "--dir",
        "-d",
        type=str,
        default=str(Path(__file__).resolve().parent),
        help="Project directory to scan (default: directory of this script)",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=str,
        default="tekton.md",
        help="Output markdown file name/path (default: tekton.md)",
    )
    parser.add_argument(
        "--no-print",
        action="store_true",
        help="Do not print the consolidated code to stdout (only write to file)",
    )
    args = parser.parse_args()

    root_dir = Path(args.dir).resolve()
    if not root_dir.exists() or not root_dir.is_dir():
        print(f"Error: Directory '{root_dir}' does not exist.", file=sys.stderr)
        sys.exit(1)

    output_path = root_dir / args.output if not os.path.isabs(args.output) else Path(args.output)

    print(f"Scanning directory: {root_dir}")
    collected_files = collect_project_files(root_dir, output_path.name)
    print(f"Found {len(collected_files)} files to dump.")

    markdown_content = generate_markdown(root_dir, collected_files)

    # Write to target markdown file
    try:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(markdown_content)
        print(f"Successfully generated: {output_path} ({len(markdown_content):,} characters)")
    except Exception as e:
        print(f"Failed to write to {output_path}: {e}", file=sys.stderr)
        sys.exit(1)

    # Print code to terminal unless suppressed
    if not args.no_print:
        print("\n" + "=" * 80)
        print(" PROJECT CODE DUMP")
        print("=" * 80 + "\n")
        try:
            print(markdown_content)
        except UnicodeEncodeError:
            # Handle Windows console encoding edge cases
            sys.stdout.buffer.write(markdown_content.encode("utf-8", errors="replace"))
        print("\n" + "=" * 80)
        print(f" DUMP COMPLETE -> Saved to: {output_path}")
        print("=" * 80)


if __name__ == "__main__":
    main()
