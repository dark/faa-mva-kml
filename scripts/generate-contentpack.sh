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

# Generate a contentpack file for a given map type (MVA/MIA) and TRACON identifier.
function generate_contentpack() {
  source_files="${1}"
  packname="${2}"
  description="${3}"

  mkdir -p "${TMPDIR}/work/${packname}"
  mkdir -p "${TMPDIR}/work/${packname}/layers"
  cp -a ${source_files} "${TMPDIR}/work/${packname}/layers/"

  # Scan for the latest file, to determine what the version of this
  # pack should be.
  latest_file=$(ls "${TMPDIR}/work/${packname}/layers/" --sort=time | head -1)
  latest_mtime=$(stat -c %Y "${TMPDIR}/work/${packname}/layers/${latest_file}")
  echo "Contentpack version: $(date -R --date "@${latest_mtime}") (${latest_mtime})"

  # Use the determined mtime to label the contentpack and timestamp
  # the manifest and all artifacts.
  cat > "${TMPDIR}/work/${packname}/manifest.json" <<EOF
{
  "name": "${description} $(date "+%Y.%m.%d" --date "@${latest_mtime}")",
  "abbreviation": "${packname}-v$(date "+%Y.%m.%d" --date "@${latest_mtime}")",
  "version": $(date "+%y.%j" --date "@${latest_mtime}"),
  "organizationName": "github.com/dark/faa-mva-kml"
}
EOF
  touch --no-create --date "@${latest_mtime}" "${TMPDIR}/work/${packname}/manifest.json"
  touch --no-create --date "@${latest_mtime}" "${TMPDIR}/work/${packname}/layers"
  touch --no-create --date "@${latest_mtime}" "${TMPDIR}/work/${packname}"

  zip -r --latest-time -X "${TMPDIR}/contentpack/${packname}" "${packname}/"
}

if [[ -z "${TMPDIR}" ]]; then
  echo '  FATAL: TMPDIR has not been defined'
  exit 1
fi
# source_dir="${1}"
# map_type="${2}"
# id="${3}"
generate_contentpack "${1}/${3}_*" "${2}-${3}" "${2} Charts for ${3}"
