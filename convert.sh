#!/bin/sh
mv debian/ltsp.dirs debian/ltsp-cloud.dirs
mv debian/ltsp.install debian/ltsp-cloud.install
mv debian/ltsp.links debian/ltsp-cloud.links
mv debian/ltsp.manpages debian/ltsp-cloud.manpages
mv debian/ltsp.triggers debian/ltsp-cloud.triggers

sed -i 's|^ltsp |ltsp-cloud |g' debian/changelog
sed -i 's|/debian/ltsp-cloud/|/debian/ltsp/|' debian/rules

sed -i 's|\(https://github.com/ltsp/\)ltsp|\1staging|' debian/rules

sed -i 's/^\(Source\|Package\): .*/\1: ltsp-cloud/' debian/control

grep -q '^Replaces: ltsp' debian/control
  echo 'Replaces: ltsp' >> debian/control

grep -q '^Conflicts: ltsp' debian/control
  echo 'Conflicts: ltsp' >> debian/control

  sed -i 's|^\(Description: Linux Terminal Server Project\)$|\1 (enhanced with cloud-native features)|' debian/control
