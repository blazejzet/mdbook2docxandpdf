#!/usr/bin/env bash
# Builds md2docx and md2epub in release mode and installs them, plus the
# .docx trim-size templates, under ~/.bookapps so both tools can be run from
# any book project directory without a local templates/ folder.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOKAPPS_DIR="$HOME/.bookapps"
BIN_DIR="$BOOKAPPS_DIR/bin"
TEMPLATES_DIR="$BOOKAPPS_DIR/templates/docx"

echo "Building md2docx (release)..."
swift build -c release --package-path "$ROOT_DIR/BookToDocx"

echo "Building md2epub (release)..."
swift build -c release --package-path "$ROOT_DIR/BookToEpub"

mkdir -p "$BIN_DIR" "$TEMPLATES_DIR"

cp "$ROOT_DIR/BookToDocx/.build/release/md2docx" "$BIN_DIR/md2docx"
cp "$ROOT_DIR/BookToEpub/.build/release/md2epub" "$BIN_DIR/md2epub"
chmod +x "$BIN_DIR/md2docx" "$BIN_DIR/md2epub"

echo "Installing templates..."
TEMPLATES_SRC=""
for candidate in "$ROOT_DIR/BookToDocx/templates" "$ROOT_DIR/templates"; do
    if [ -d "$candidate" ]; then
        TEMPLATES_SRC="$candidate"
        break
    fi
done

templates=()
if [ -z "$TEMPLATES_SRC" ]; then
    echo "warning: no templates/ directory found (looked in BookToDocx/templates and templates)" >&2
else
    shopt -s nullglob
    templates=("$TEMPLATES_SRC"/*.docx)
    shopt -u nullglob
    if [ ${#templates[@]} -eq 0 ]; then
        echo "warning: no .docx templates found in $TEMPLATES_SRC" >&2
    else
        cp "${templates[@]}" "$TEMPLATES_DIR/"
    fi
fi

echo
echo "Installed:"
echo "  $BIN_DIR/md2docx"
echo "  $BIN_DIR/md2epub"
echo "  ${#templates[@]} template(s) from $TEMPLATES_SRC -> $TEMPLATES_DIR"

# Add ~/.bookapps/bin to PATH, idempotently, in whichever rc file the
# user's shell actually reads.
PATH_LINE='export PATH="$HOME/.bookapps/bin:$PATH"'

add_to_rc() {
    local rc="$1"
    [ -f "$rc" ] || touch "$rc"
    if grep -qF "$PATH_LINE" "$rc" 2>/dev/null; then
        echo "~/.bookapps/bin already in PATH via $rc"
    else
        {
            echo ""
            echo "# Added by booksapps/install.sh"
            echo "$PATH_LINE"
        } >> "$rc"
        echo "Added ~/.bookapps/bin to PATH in $rc"
    fi
}

case "${SHELL:-}" in
    */zsh) add_to_rc "$HOME/.zshrc" ;;
    */bash) add_to_rc "$HOME/.bash_profile" ;;
    *) add_to_rc "$HOME/.profile" ;;
esac

echo
echo "Done. Open a new terminal (or run: source ~/.zshrc) then try:"
echo "  md2docx --help"
echo "  md2epub --help"
