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

# Create a work and final directory to store the content packs.
mkdir -p "${TMPDIR}/work/"
mkdir -p "${TMPDIR}/contentpack/"

# Iterate through all unique ATC identifiers and generate content packs.
pushd "${TMPDIR}/work/"
for id in $(find "${D}/kml/" -type f | sed 's:.*/kml/::' | cut -f 1 -d _ | sort | uniq); do
  packname="MVA-${id}"
  mkdir -p "${TMPDIR}/work/${packname}"
  mkdir -p "${TMPDIR}/work/${packname}/layers"
  cp ${D}/kml/${id}_* "${TMPDIR}/work/${packname}/layers/"
  cat > "${TMPDIR}/work/${packname}/manifest.json" <<EOF
{
  "name": "MVA Charts for ${id} $(date "+%Y.%m.%d")",
  "abbreviation": "${packname}-v$(date "+%Y.%m.%d")",
  "version": $(date "+%y.%j"),
  "organizationName": "github.com/dark/faa-mva-kml"
}
EOF
  zip -r "${TMPDIR}/contentpack/${packname}" "${packname}/"
done
popd

# Update all files in place.
echo
echo 'Moving files in place...'
rm -rf "${D}/kml/"
mv "${TMPDIR}/kml/" "${D}/kml/"
rm -rf "${D}/contentpack/"
mv "${TMPDIR}/contentpack/" "${D}/contentpack/"

# Cleanup
rm -rf "${TMPDIR}/"
