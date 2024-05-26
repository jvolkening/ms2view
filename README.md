![Logo](graphics/logo.svg)

ms2view - a simple mass spectrum viewer with vim-like bindings
=======================================

## SYNOPSIS

ms2view --raw input.mzML \[--pepxml ids.pepxml ...etc...\]

## DESCRIPTION

**ms2view** is a simple viewer for tandem mass spectrometry data. It combines
an overview of an LC-MS/MS run with display of individual MS1 and MS2 spectra.
It can also show and annotate peptide spectral matches based on pepXML or
tab-delimited input.

While navigation can be done using a mouse, there are also a set of vim-like
keybindings to allow quick navigation via the keyboard. The supported bindings
are described below.

## PREREQUISITES

Requires the following non-core Perl libraries:

- Gtk3
- Gtk3::SimpleList
- MS

## COMMAND-LINE OPTIONS

- **--raw** _filename_

    Path to input mzML file (required)

- **--pepxml** _filename_

    Path to input pepXML containing spectral IDS for the corresponding mzML

- **--ids** _filename_

    Path to input tab-separated table  containing spectral IDS for the corresponding mzML

- **--hardklor**

    Path to Hardklor output file containing peptide features for the corresponding
    mzML (NOTE: this feature is currently unimplemented)

## KEY BINDINGS

The following keybindings are enabled:

- `tab` switch focus between three main canvases
- `h` `l` move peak selection left and right respectively (if the overview
    panel is in focus, this will move to the next MS1 scan and load it in the
    spectrum window)
- `H` `L` zoom canvas out and in on x-axis (zoom centers on currently
    selected peak)
- `J` `K` zoom canvas out and in on y-axis
- `<number`g> center the canvas at the m/z coordinate given by `<number>`
- `s` save the currently focused canvas as PNG (will prompt for filename)

## MOUSE NAVIGATION

The following mouse actions are supported on each spectrum canvas:

- `left-click` change the current peak selection. The selected peak will be
    the one with apex closest to the click point in Euclidean space.
- `shift+left-click` drag to select a window and add an m/z label to the most
    intense peak in the selected window
- `ctrl+left-click` drag from near the apex of one peak to the apex and
    another to display an on-screen ruler of the horizontal distance in m/z
- `right-click` drag to move canvas view horizontally
- `scroll-wheel` change x-axis zoom
- `ctrl+scroll-wheel` change y-axis zoom

## CAVEATS AND BUGS

Please submit bug reports to the issue tracker in the distribution repository.

## AUTHOR

Jeremy Volkening

## LICENSE AND COPYRIGHT

Copyright 2014-24 Jeremy Volkening

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
