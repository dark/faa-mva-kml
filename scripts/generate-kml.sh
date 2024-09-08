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

if [[ -z "${TMPDIR}" ]]; then
  echo '  FATAL: TMPDIR has not been defined'
  exit 1
fi
generate_kml "${1}" "${2}"
