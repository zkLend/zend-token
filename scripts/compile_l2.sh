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
  starknet-compile -c "$MODULE::$NAME" $REPO_ROOT > $OUTPUT

  if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    chown $USER_ID:$GROUP_ID $OUTPUT
  fi
}

mkdir -p "$REPO_ROOT/build"

compile openzeppelin::token::erc20_v070::erc20 ERC20

if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
  chown -R $USER_ID:$GROUP_ID "$REPO_ROOT/build"
fi
