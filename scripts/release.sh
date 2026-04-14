#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="mcp-tsup-aatex"
VERSION=$(node -p "require('./package.json').version")
ARCHIVE="${NAME}-v${VERSION}"
DIST_DIR="dist"

mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${ARCHIVE}.zip" "${DIST_DIR}/${ARCHIVE}.tar.gz"

git archive --format=zip    --prefix="${ARCHIVE}/" -o "${DIST_DIR}/${ARCHIVE}.zip"    HEAD
git archive --format=tar.gz --prefix="${ARCHIVE}/" -o "${DIST_DIR}/${ARCHIVE}.tar.gz" HEAD

echo ""
echo "Созданы архивы:"
echo "  ${DIST_DIR}/${ARCHIVE}.zip"
echo "  ${DIST_DIR}/${ARCHIVE}.tar.gz"
echo ""
echo "В архив попадают только tracked файлы — .mcp.json (с реальным ключом) исключён автоматически."
