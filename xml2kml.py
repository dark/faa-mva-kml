#!/usr/bin/python
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

import argparse
import xml.etree.ElementTree as ET


class Chart:
    def parse_xml(filename: str) -> "Chart":
        return Chart()

    def write_kml(self, filename: str):
        pass


def main(input: str, output: str) -> None:
    print("Converting input file %s to output %s" % (input, output))
    print("Parsing input file...")
    chart = Chart.parse_xml(input)
    print("Input file parsed successfully")
    chart.write_kml(output)
    print("Output file written successfully")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert a FAA MVA file from XML to KML"
    )
    parser.add_argument("input", type=str, help="input XML file")
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        help="output KML file (if not provided, .kml is appended to the input file name",
    )
    args = parser.parse_args()
    main(args.input, args.input + ".kml" if args.output is None else args.output)
