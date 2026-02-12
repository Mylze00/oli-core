#!/bin/bash
cd /home/paolice-mylze/oli-core/oli_delivery
perl -pi -e 's/
/
/g' /mnt/c/flutter/bin/flutter /mnt/c/flutter/bin/dart
find /mnt/c/flutter/bin/internal -name '*.sh' -exec perl -pi -e 's/
/
/g' {} +
/mnt/c/flutter/bin/flutter build web --release
