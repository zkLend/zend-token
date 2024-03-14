#!/bin/sh

set -e

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

compile () {
  MODULE="$1"
  NAME="$2"
  OUTPUT="$REPO_ROOT/build/$NAME.json"

  echo "Compiling $MODULE::$NAME"

  # This is better than using the output option, which does not emit EOL at the end.
  starknet-compile -c "$MODULE::$NAME" . > $OUTPUT

  if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    chown $USER_ID:$GROUP_ID $OUTPUT
  fi
}

mkdir -p "$REPO_ROOT/build"

cd ./airdrop

compile airdrop::airdrop Airdrop

if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
  chown -R $USER_ID:$GROUP_ID "$REPO_ROOT/build"
fi
