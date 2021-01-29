#!/bin/bash -e

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
