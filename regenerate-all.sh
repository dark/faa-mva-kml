#!/bin/bash -e
#
#  FAA Minimum Vectoring Altitude (MVA) Charts as KML Files
#  Copyright (C) 2021-2024  Marco Leogrande
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
export D

# Generate a KML file given its XML input.
function generate_kml() {
  map_type="${1}"
  input="${2}"
  output="${TMPDIR}/${map_type}-kml/$(basename "${input}" | sed 's/\.xml/.kml/')"
  # Always try to convert the file.
  echo "  ${input} -> ${output}"
  "${D}/xml2kml.py" "${input}" -o "${output}"
  conversion_status=$?
  # See if the input file is in the blacklist.
  grep -q "$(basename "${input}")" "${D}/blacklist.txt"
  blacklist_status=$?

  if [[ $conversion_status -eq 0 ]]; then
    # Successful conversion case.
    if [[ $blacklist_status -eq 0 ]]; then
      # Warn that this file is in the blacklist, despite converting
      # successfully. This will help remove items from the blacklist
      # once they get fixed.
      echo "  WARNING: ${input} is in the blacklist, but converts successfully" >&2
    fi
    # Always return success on a successful conversion.
    return 0
  fi

  # Unsuccessful conversion case
  echo "  INFO: failed to convert ${input} -> ${output}" >&2
  if [[ $blacklist_status -eq 0 ]]; then
    # Since this file is in the blacklist, ignore the error. Delete
    # the output file to avoid issues.
    rm -f "${output}"
    return 0
  fi

  # This input file is not blacklisted, return an error.
  echo "  ERROR: please add '$(basename "${input}")' to the blacklist to suppress this error." >&2
  return $conversion_status
}
export -f generate_kml

# Generate a contentpack file for a given map type (MVA/MIA) and TRACON identifier.
function generate_contentpack() {
  map_type="${1}"
  id="${2}"
  packname="${map_type}-${id}"
  mkdir -p "${TMPDIR}/work/${packname}"
  mkdir -p "${TMPDIR}/work/${packname}/layers"
  cp ${D}/${map_type,,}-kml/${id}_* "${TMPDIR}/work/${packname}/layers/"
  cat > "${TMPDIR}/work/${packname}/manifest.json" <<EOF
{
  "name": "${map_type} Charts for ${id} $(date "+%Y.%m.%d")",
  "abbreviation": "${packname}-v$(date "+%Y.%m.%d")",
  "version": $(date "+%y.%j"),
  "organizationName": "github.com/dark/faa-mva-kml"
}
EOF
  zip -r "${TMPDIR}/contentpack/${packname}" "${packname}/"
}
export -f generate_contentpack

function do_work() {
  map_type_lowercase="${1,,}"
  map_type_uppercase="${1^^}"
  echo "Working on ${map_type_uppercase} maps"

  # Create all temporary directories
  TMPDIR=$(mktemp -d)
  export TMPDIR
  mkdir -p "${TMPDIR}/work/"
  mkdir -p "${TMPDIR}/${map_type_lowercase}-faa-xml/"
  mkdir -p "${TMPDIR}/${map_type_lowercase}-kml/"
  mkdir -p "${TMPDIR}/contentpack/"
  mkdir -p "${TMPDIR}/tmp/"
  echo "Using temporary directory: ${TMPDIR}"

  # Download all XML files from the FAA website.
  echo
  echo '  * Download all XML files...'
  pushd "${TMPDIR}/${map_type_lowercase}-faa-xml/" &> /dev/null
  wget --user-agent="" -r -l1 -t1 -np -nd -H --accept-regex 'aeronav.faa.gov/.*xml' -A ".xml" -w 0.1 --random-wait \
       "https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/mva_mia/${map_type_lowercase}" 2> "${TMPDIR}/work/wget.out" || true
  popd &> /dev/null
  echo "$(find "${TMPDIR}/${map_type_lowercase}-faa-xml/" -type f -name '*.xml' | wc -l) files were downloaded, moving files into the repo..."
  rm -rf "${D}/${map_type_lowercase}-faa-xml/"
  mv "${TMPDIR}/${map_type_lowercase}-faa-xml/" "${D}/${map_type_lowercase}-faa-xml/"
  echo 'XML files moved into the repo.'

  # Regenerate all KML files.
  echo
  echo '  * Regenerate all KML files...'
  find "${D}/${map_type_lowercase}-faa-xml/" -name '*.xml' | parallel --eta --color-failed generate_kml "${map_type_lowercase}" > /dev/null
  echo 'Regeneration complete, moving files into the repo...'
  rm -rf "${D}/${map_type_lowercase}-kml/"
  mv "${TMPDIR}/${map_type_lowercase}-kml/" "${D}/${map_type_lowercase}-kml/"
  echo 'KML files moved into the repo.'

  # Iterate through all unique TRACON identifiers and generate content packs.
  echo
  echo '  * Regenerate contentpack files with modifications...'
  pushd "${TMPDIR}/work/" &> /dev/null
  git -C "${D}" status -s | grep " ${map_type_lowercase}-kml/" | sed "s:.* ${map_type_lowercase}-kml/::" | cut -f 1 -d _ | \
    sort | uniq | parallel --eta generate_contentpack "${map_type_uppercase}" > /dev/null
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
}

# main code
do_work 'mva'
