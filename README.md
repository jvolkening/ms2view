ms2view - a simple mass spectrum viewer
=======================================

# SYNOPSIS

ms2view --raw &lt;input.mzML> \[--pepxml ids.pepxml --hardklor peptides.hk\]

# DESCRIPTION

**ms2view** is a simple viewer for tandem mass spectrometry data. At its
simplest it combines an overview of an LC-MS/MS run along with individual MS1
and MS2 spectra. It can also show and annotate peptide spectral matches based
on a pepXML input as well as highlight peptide features detected by the
Hardklor program.

# PREREQUISITES

Requires the following non-core Perl libraries:

- Gtk2
- Gtk2::SimpleList
- MS

# OPTIONS

- **--raw** _filename_

    Path to input mzML file (required)

- **--pepxml** _filename_

    Path to input pepXML containing spectral IDS for the corresponding mzML

- **--ids** _integer_

    Path to input tab-separated table  containing spectral IDS for the corresponding mzML

- **--hardklor**

    Path to Hardklor output file containing peptide features for the corresponding
    mzML (NOTE: this feature is currently unimplemented)

# CAVEATS AND BUGS

Please submit bug reports to the issue tracker in the distribution repository.

# AUTHOR

Jeremy Volkening (jdv@base2bio.com)

# LICENSE AND COPYRIGHT

Copyright 2014-17 Jeremy Volkening

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/.
