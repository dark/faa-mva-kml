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
export D TMPDIR

# Create all temporary directories
mkdir -p "${TMPDIR}/work/"
mkdir -p "${TMPDIR}/kml/"
mkdir -p "${TMPDIR}/contentpack/"

# Generate a KML file given its XML input.
function generate_kml() {
  input="${1}"
  output="${TMPDIR}/kml/$(basename "${input}" | sed 's/\.xml/.kml/')"
  echo "  ${input} -> ${output}"
  "${D}/xml2kml.py" "${input}" -o "${output}"
}
export -f generate_kml

# Generate a contentpack file for a given TRACON identifier.
function generate_contentpack() {
  id="${1}"
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
}

echo "Using temporary directory: ${TMPDIR}"

# Regenerate all KML files first.
echo
echo 'Regenerate all KML files...'
find "${D}/faa-xml/" -name '*.xml' | parallel --bar generate_kml > /dev/null
echo 'Regeneration complete, moving files into the repo...'
rm -rf "${D}/kml/"
mv "${TMPDIR}/kml/" "${D}/kml/"
echo 'KML files moved into the repo.'

# Iterate through all unique TRACON identifiers and generate content packs.
echo
echo 'Regenerate contentpack files with modifications...'
pushd "${TMPDIR}/work/" &> /dev/null
for id in $(git -C "${D}" status -s | grep ' kml/' | sed 's:.* kml/::' | cut -f 1 -d _ | sort | uniq); do
  generate_contentpack "${id}"
done
popd &> /dev/null
if ls ${TMPDIR}/contentpack/*.zip &> /dev/null; then
  echo 'Done regenerating contentpack files, moving files into the repo...'
  mv ${TMPDIR}/contentpack/*.zip "${D}/contentpack/"
  echo 'Contentpack files moved into the repo.'
else
  echo 'No contentpack file was regenerated.'
fi

# Cleanup
rm -rf "${TMPDIR}/"
