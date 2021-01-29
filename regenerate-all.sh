#!/bin/bash

find faa-xml/ -name '*.xml' | while read input; do
  output="output-kml/$(basename "${input}" | sed 's/\.xml//').kml"
  echo "${input} -> ${output}"
  ./xml2kml.py "${input}" -o "${output}"
done
