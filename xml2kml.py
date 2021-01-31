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
import os
import simplekml
from shapely.geometry import Polygon
from typing import List, Tuple
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

# Minimum and maximum alpha for the KML color gradients.
MIN_ALPHA = 50
MAX_ALPHA = 130


class Palette:
    def default():
        while True:
            for color in [
                simplekml.Color.red,
                simplekml.Color.green,
                simplekml.Color.chocolate,
            ]:
                yield color


@attr.s
class Position:
    lat = attr.ib()
    long = attr.ib()

    def comma_z(self) -> str:
        """Comma-separated representation, including elevation."""
        return "{},{},0".format(self.long, self.lat)

    def tuple_z(self) -> Tuple[float, float, float]:
        """Tuple representation, including elevation."""
        return (self.long, self.lat, 0.0)


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
        self.floor = int(volume.find("ns3:minimumLimit", NAMESPACES).text)
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

    def representative_point(self) -> Position:
        shape = Polygon([p.tuple_z() for p in self.vertexes])
        point = shape.representative_point()
        return Position(lat=point.y, long=point.x)


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

        # Sort airspaces in ascending MVA order. This helps with the
        # layering in the final map.
        self.airspaces.sort(key=lambda a: a.floor)

    def write_kml(self, filename: str):
        kml = simplekml.Kml()
        palette = Palette.default()
        # Have a "pretty" document name.
        kml.document.name = os.path.basename(filename).split(".")[0]
        # Get minimum and maximum airspace floors, to apply color
        # gradients to the map.
        min_floor = min([a.floor for a in self.airspaces])
        max_floor = max([a.floor for a in self.airspaces])
        for airspace in self.airspaces:
            poly = kml.newpolygon(
                name="{} - {} ft".format(airspace.name, airspace.floor),
                outerboundaryis=[p.tuple_z() for p in airspace.vertexes],
            )

            # Same color for the polygon fill and its outline.
            gradient = MIN_ALPHA + (MAX_ALPHA - MIN_ALPHA) * (
                airspace.floor - min_floor
            ) / (max_floor - min_floor)
            poly_color = next(palette)
            poly.style.linestyle.color = poly_color
            poly.style.linestyle.width = 1
            poly.style.polystyle.color = simplekml.Color.changealphaint(
                int(gradient), poly_color
            )

            # Select a good place to put the label for this airspace.
            point = kml.newpoint(name="{}".format(int(airspace.floor)))
            point.coords = [airspace.representative_point().tuple_z()]
            # We don't need the icon, make it quite small.
            point.style.iconstyle.scale = 0.1
            point.style.iconstyle.icon.href = (
                "http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png"
            )
        kml.save(filename)


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
