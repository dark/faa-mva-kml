#!/bin/bash -e
#
#  FAA Minimum Vectoring Altitude (MVA) Charts as KML Files
#  Copyright (C) 2021  Marco Leogrande
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


D=$(readlink -f "$0" | xargs dirname)
TMPDIR=$(mktemp -d)

# Regenerate all KML files first.
mkdir -p "${TMPDIR}/kml/"
find "${D}/faa-xml/" -name '*.xml' | while read input; do
  output="${TMPDIR}/kml/$(basename "${input}" | sed 's/\.xml//').kml"
  echo "  ${input} -> ${output}"
  "${D}/xml2kml.py" "${input}" -o "${output}"
done

# Updates all files in place.
echo
echo 'Moving files in place...'
rm -rf "${D}/kml/"
mv "${TMPDIR}/kml/" "${D}/kml/"
