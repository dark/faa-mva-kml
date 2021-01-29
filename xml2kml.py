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
import attr
from typing import List
from xml.etree import ElementTree

# Constant namespaces used in all input XML files. See XML file headers.
NAMESPACES = {
    "ns2": "http://www.w3.org/1999/xlink",
    "ns1": "http://www.opengis.net/gml/3.2",
    "ns4": "http://www.isotc211.org/2005/gco",
    "ns3": "http://www.aixm.aero/schema/5.1",
    "ns5": "http://www.isotc211.org/2005/gmx",
    "ns6": "http://www.isotc211.org/2005/gmd",
    "ns7": "http://www.isotc211.org/2005/gts",
    "ns8": "http://www.aixm.aero/schema/5.1/message",
}


@attr.s
class Position:
    lat = attr.ib()
    long = attr.ib()

    def comma_z(self) -> str:
        """Comma-separated representation, including elevation."""
        return "{},{},0".format(self.long, self.lat)


class Airspace:
    """Class representing a chunk of airspace in the MVA chart."""

    # Name of the airspace
    name: str = ...

    # The airspace floor, in ft MSL
    floor: int = ...

    # The vertexes of the airspace
    vertexes: List[Position] = ...

    def __init__(self, element: ElementTree.Element):
        """Creates an airspace representation from an XML element."""
        self.name = element.find("ns3:name", NAMESPACES).text
        volume = element.find(
            "ns3:geometryComponent/ns3:AirspaceGeometryComponent/ns3:theAirspaceVolume/ns3:AirspaceVolume",
            NAMESPACES,
        )
        self.floor = volume.find("ns3:minimumLimit", NAMESPACES).text
        coords = volume.find(
            "ns3:horizontalProjection/ns3:Surface/ns1:patches/ns1:PolygonPatch/ns1:exterior/ns1:LinearRing/ns1:posList",
            NAMESPACES,
        ).text
        # Coords is a long string of longitude/latitude pairs
        # separated by spaces.
        coords = coords.split(" ")
        if len(coords) % 2 != 0:
            raise ValueError(
                "Cannot parse element with odd number of coordinate values: {}".format(
                    len(coords)
                )
            )
        self.vertexes = []
        for i in range(0, len(coords), 2):
            self.vertexes.append(
                Position(lat=float(coords[i + 1]), long=float(coords[i]))
            )


class Chart:
    # All airspaces in this chart.
    airspaces: List[Airspace] = ...

    def __init__(self, filename: str):
        tree = ElementTree.parse(filename)
        root = tree.getroot()

        self.airspaces = []
        for airspace in root.findall(
            "ns8:hasMember/ns3:Airspace/ns3:timeSlice/ns3:AirspaceTimeSlice", NAMESPACES
        ):
            self.airspaces.append(Airspace(airspace))

    def write_kml(self, filename: str):
        pass


def main(input: str, output: str) -> None:
    print("Converting input file %s to output %s" % (input, output))
    print("Parsing input file...")
    chart = Chart(input)
    print("Input file with %d airspaces parsed successfully" % len(chart.airspaces))
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
