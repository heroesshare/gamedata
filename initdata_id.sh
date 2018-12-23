#!/bin/sh

tmpfile=`mktemp`

replay="$1"

"/Library/Application Support/Heroes Share/heroprotocol/heroprotocol.py" --initdata "$replay" | grep -e "'m_hero'" -e "'m_tier'" > $tmpfile

echo "$tmpfile"
less "$tmpfile"

exit 0