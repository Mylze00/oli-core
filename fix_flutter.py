#!/usr/bin/env python3
script = '#!/usr/bin/env bash\n'
script += 'set -e\n'
script += 'unset CDPATH\n'
script += 'function follow_links() (\n'
script += '  cd -P "$(dirname -- "$1")"\n'
script += '  file="$PWD/$(basename -- "$1")"\n'
script += '  while [[ -h "$file" ]]; do\n'
script += '    cd -P "$(dirname -- "$file")"\n'
script += '    file="$(readlink -- "$file")"\n'
script += '    cd -P "$(dirname -- "$file")"\n'
script += '    file="$PWD/$(basename -- "$file")"\n'
script += '  done\n'
script += '  echo "$file"\n'
script += ')\n'
script += 'PROG_NAME="$(follow_links "${BASH_SOURCE[0]}")"\n'
script += 'BIN_DIR="$(cd "${PROG_NAME%/*}" ; pwd -P)"\n'
script += 'SHARED_NAME="$BIN_DIR/internal/shared.sh"\n'
script += 'OS="$(uname -s)"\n'
script += 'if [[ $OS =~ MINGW.* || $OS =~ CYGWIN.* || $OS =~ MSYS.* ]]; then\n'
script += '  exec "${BIN_DIR}/flutter.bat" "$@"\n'
script += 'fi\n'
script += 'source "$SHARED_NAME"\n'
script += 'shared::execute "$@"\n'

with open('/mnt/c/flutter/bin/flutter', 'w', newline='\n') as f:
    f.write(script)
print('Flutter script fixed successfully!')
