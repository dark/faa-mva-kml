#!/bin/bash -e
#
#  FAA Minimum Vectoring Altitude (MVA) Charts as KML Files
#  Copyright (C) 2021-2026  Marco Leogrande
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
  find "${D}/${map_type_lowercase}-faa-xml/" -name '*.xml' | parallel --eta --color-failed "${D}/scripts/generate-kml.sh" "${map_type_lowercase}" > /dev/null
  echo 'Regeneration complete, moving files into the repo...'
  rm -rf "${D}/${map_type_lowercase}-kml/"
  mv "${TMPDIR}/${map_type_lowercase}-kml/" "${D}/${map_type_lowercase}-kml/"
  echo 'KML files moved into the repo.'

  # Iterate through all unique TRACON identifiers and generate content packs.
  echo
  echo '  * Regenerate contentpack files...'
  pushd "${TMPDIR}/work/" &> /dev/null
  ls "${D}/${map_type_lowercase}-kml/" | cut -f 1 -d _ | sort | uniq | \
    parallel --eta "${D}/scripts/generate-contentpack.sh" "${D}/${map_type_lowercase}-kml/" "${map_type_uppercase}" > /dev/null
  popd &> /dev/null
  echo 'Done regenerating contentpack files, moving files into the repo...'
  rm -f ${D}/contentpack/${map_type_uppercase}-*.zip
  mv ${TMPDIR}/contentpack/*.zip "${D}/contentpack/"
  echo 'Contentpack files moved into the repo.'

  # Cleanup
  echo
  rm -rf "${TMPDIR}/"
  unset TMPDIR
}

function generate_combined_files() {
  echo 'Generating combined files'

  # Create all temporary directories
  TMPDIR=$(mktemp -d)
  export TMPDIR
  mkdir -p "${TMPDIR}/work/"
  mkdir -p "${TMPDIR}/contentpack/"
  echo "Using temporary directory: ${TMPDIR}"

  # Generate the KML files from the XML files already downloaded.
  echo
  echo '  * Combine MVA maps (3 miles)...'
  find "${D}/mva-faa-xml/" -name '*FUS3*.xml' | xargs "${D}/scripts/xml2kml.py" -o "${TMPDIR}/work/mva-3miles.kml" > /dev/null
  echo '  * Combine MVA maps (5 miles)...'
  find "${D}/mva-faa-xml/" -name '*FUS5*.xml' | xargs "${D}/scripts/xml2kml.py" -o "${TMPDIR}/work/mva-5miles.kml" > /dev/null
  echo '  * Combine MVA maps (all others)...'
  find "${D}/mva-faa-xml/" -name '*.xml' -and -not -name '*FUS3*.xml' -and -not -name '*FUS5*.xml' | xargs "${D}/scripts/xml2kml.py" -o "${TMPDIR}/work/mva-others.kml" > /dev/null
  echo '  * Combine MIA maps...'
  find "${D}/mia-faa-xml/" -name '*.xml' | xargs "${D}/scripts/xml2kml.py" -o "${TMPDIR}/work/mia.kml" > /dev/null

  # Generate content packs.
  echo
  echo '  * Generate contentpack files...'
  pushd "${TMPDIR}/work/" &> /dev/null
  "${D}/scripts/generate-combined-contentpack.sh" "${TMPDIR}/work/mva-3miles.kml" 'MVA-FUS3' 'MVA Charts (3 miles)' > /dev/null
  "${D}/scripts/generate-combined-contentpack.sh" "${TMPDIR}/work/mva-5miles.kml" 'MVA-FUS5' 'MVA Charts (5 miles)' > /dev/null
  "${D}/scripts/generate-combined-contentpack.sh" "${TMPDIR}/work/mva-others.kml" 'MVA-others' 'MVA Charts (others)' > /dev/null
  "${D}/scripts/generate-combined-contentpack.sh" "${TMPDIR}/work/mia.kml" 'MIA' 'MIA Charts' > /dev/null
  popd &> /dev/null
  echo 'Done regenerating contentpack files, moving files into the repo...'
  mv ${TMPDIR}/contentpack/*.zip "${D}/contentpack/"
  echo 'Contentpack files moved into the repo.'

  # Cleanup
  echo
  rm -rf "${TMPDIR}/"
  unset TMPDIR
}

# main code
do_work 'mva'
do_work 'mia'
generate_combined_files
