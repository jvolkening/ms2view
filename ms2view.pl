#!/usr/bin/perl

#############################################################################
# embedded files
#############################################################################

package Spector::Embed;

$ui = <<XML;
<ui>
  <menubar name="MenuBar">
    <menu name="FileMenu" action="FileMenu">
      <menuitem name="Load_I" action="Load_I" />
      <menuitem name="Load_N" action="Load_N" />
      <menuitem name="Save" action="Save" />
      <separator />
      <menuitem name="Quit" action="Quit" />
    </menu>
    <menu name="EditMenu" action="EditMenu">
      <menuitem name="Grid_M" action="Grid_M"/>
      <menuitem name="Grid_A" action="Grid_A"/>
      <menuitem name="Grid_L" action="Grid_L"/>
      <separator />
      <menuitem name="Prefs" action="Prefs" />
    </menu>
    <menu name="ViewMenu" action="ViewMenu">
      <menuitem name="Show_Grid" action="Show_Grid"/>
      <menuitem name="HL_Used" action="HL_Used"/>
      <separator />
      <menuitem name="Zoom_In" action="Zoom_In"/>
      <menuitem name="Zoom_Out" action="Zoom_Out"/>
      <menuitem name="Zoom_Fit" action="Zoom_Fit"/>
      <menuitem name="Zoom_100" action="Zoom_100"/>
    </menu>
    <menu name="HelpMenu" action="HelpMenu">
      <menuitem name="About" action="About"/>
    </menu>
  </menubar>
</ui>
XML

$icon_B2B_16 = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz
AAAN1wAADdcBQiibeAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAADASURB
VDiNpZPBDYMwDEWf067TLsClR3Yoc/SKI3FiDtihC7AAnYYDuBdaEZpIFL5kyZKTp287ETPjqBSw
naEyJ7t1Brg/ntHiq2vouwZVpSzLoOa9R1URwFKAJSQ2KxEh2cI1K7hkBQBtnX8BIhLkDsDMglBV
+q6JOlo7cbFD637XtpOAdfFvB/88qqqqgHmNSwcpiHMuiGEYfgGpy6k1t3UeH+LH3hYJYCIStbdF
pxlyMzOmaWIcx82XAS9Hv/MbCXls+cixbw4AAAAASUVORK5CYII=
PNG

$icon_ch_white = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAAAXNSR0IArs4c6QAAAAZiS0dEAAAA
AAAA+UO7fwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB90EFxMwAJscR20AAAAZdEVYdENv
bW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBXgQ4XAAAALUlEQVQ4y2NgIAD+////n5AaJgYqgFFDBrMh
jITSASMjIyMxaWU0sY0aQggAAMpCEBLL4xSxAAAAAElFTkSuQmCC
PNG

$icon_ch_green = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH3gEUFQwjEsRhYgAAABl0RVh0Q29tbWVudABDcmVhdGVk
IHdpdGggR0lNUFeBDhcAAAAtSURBVDjLY2AgACL+y24mpIaJgQpg1JDBbAgjoXSwgvGxLzFpZTSx
jRpCCAAAiWsKk6T5wbEAAAAASUVORK5CYII=
PNG

package main;

use v5.10.1;

use strict;
use warnings;
no warnings 'experimental';
use File::Basename qw/basename/;
use File::Temp qw/tempfile/;
use FindBin;
use Getopt::Long;
use Gtk2 '-init';
use Glib qw(TRUE FALSE);
use Gtk2::SimpleList;
use List::MoreUtils(qw/uniq any/);
use List::Util;
use Memoize qw/memoize flush_cache/;
use MIME::Base64 qw/decode_base64/;
use Time::Piece;
use Data::Dumper;

use lib $FindBin::Bin;
use MassCanvas;
use MS::Parser::MzML;
use MS::Parser::PepXML;
use MS::PepInfo qw/calc_fragments/;

# constants
use constant ZI => 1.25;
use constant ZO => 0.80;

# globals
my $NAME    = 'Spector';
my $VERSION = '0.1a';
my $YEAR    = 2014;
my $gobjs   = {};
my $cursors = {};
my $ndf     = {}; # store ndf data and metadata
my $embedded = get_embedded();
my $chip_rotation = 0;
my %extract_functions = (
    'center' => \&get_value_center,
    'median' => \&get_value_median,
    'mean'   => \&get_value_mean,
);
my $zoom_mode = 0;

my $mzml_file = $ARGV[0];
my $pepxml_file = $ARGV[1];
my $curr_scan_index;
my $parser = MS::Parser::MzML->new;
my $pep_p  = MS::Parser::PepXML->new();

my $ms1_canvas;
my $ms2_canvas;
my $xic_canvas;
my $list;
my $ms1_hid;
my $xic_lid;
my %mods;
my %charges;

# initialize GUI
$gobjs->{mw} = _build_ui();

if (defined $mzml_file) {
    $parser->load( $mzml_file );
    $curr_scan_index = $parser->first_spectrum_index()
        if (! defined $curr_scan_index);
    my $scan = $parser->fetch_record('spectrum' => $curr_scan_index);
    load_scan( $scan );
}
if (defined $pepxml_file) {
    load_list( $pepxml_file );
}
Gtk2->main;




#----------------------------------------------------------------------------#
# SUBROUTINES
#----------------------------------------------------------------------------#

sub load_list {

    my ($fn) = @_;
    return if (! defined $fn);
    $pep_p->load($fn);
    while (my $run = $pep_p->next_run) {
        while (my $spectrum = $run->next_query) {
            my $z  = $spectrum->{assumed_charge};
            my $id = $spectrum->{start_scan};
            my $pep = $spectrum->top_hit->{peptide};
            my @mods = $spectrum->mod_delta_array;
            $mods{$id} = [@mods];
            $charges{$id} = $z;
            push @{$list->{data}}, [$id,$pep];
        }
    }
}


sub clean_quit {

    Gtk2->main_quit;
    return FALSE;
    
}

sub _build_ui {

    # set up the main window
    my $mw = Gtk2::Window->new('toplevel');
    $mw->set_title("$NAME v$VERSION");
    $mw->signal_connect('delete_event' => \&clean_quit );
    $mw->set_default_size(900, 500);
    $mw->set_default_icon_list($embedded->{B2B_16});

    # add custom icons
    my $theme = Gtk2::IconTheme->get_default;

    # build menubar and toolbar
    my $vbox_main = _return_framework($mw);
    
    # Next we put together the main content
    $mw->add($vbox_main);

    $mw->show_all();
    return $mw;
    
}

sub _return_framework {

    my $mw = shift;


    my $vbox = Gtk2::VBox->new(FALSE,0);
    
    # define menu structure
    my @menu_actions = (
        # name         stock id           label
        [ "FileMenu",  undef,            "_File" ],
        [ "EditMenu",  undef,            "_Edit" ],
        [ "ViewMenu",  undef,            "_View" ],
        [ "HelpMenu",  undef,            "_Help" ],
        # name         stock id           label          accelerator   tooltip      callback
        [ "Load_I",   'gtk-open',        "_Load image", "<control>O", "Load image", sub{_load_image()}  ],
        [ "Load_N",   'gtk-open',        "_Load NDF",    undef,       "Load NDF",   sub{ _load_ndf()}   ],
        [ "Save",      undef,            "_Save .pair",  undef,       "Save",       \&print_pair        ],
        [ "Quit",     'gtk-quit',        "_Quit",       "<control>Q", "Quit",       \&clean_quit        ],
        [ "Grid_M",    undef,            "_Manual grid", undef,       "Manual",     \&manual_grid       ],
        [ "Grid_A",    undef,            "_Auto grid",   undef,       "Auto",       \&auto_grid         ],
        [ "Grid_L",    undef,            "_Auto all",    undef,       "Auto All",   \&auto_all          ],
        [ "About",    'gtk-about',       "_About",       undef,       "About",      \&show_about        ],
        [ "Prefs",    'gtk-preferences', "_Preferences", undef,       "Prefs",      \&edit_prefs        ],
        [ "Zoom_In",  'gtk-zoom-in',     "_Zoom in",     undef,       "Zoom in",    sub{zoom(undef,ZI)} ],
        [ "Zoom_Out", 'gtk-zoom-out',    "_Zoom out",    undef,       "Zoom out",   sub{zoom(undef,ZO)} ],
        [ "Zoom_100", 'gtk-zoom-100',    "_Zoom 100%",   undef,       "Zoom 100%",  sub{zoom(undef,-1)} ],
        [ "Zoom_Fit", 'gtk-zoom-fit',    "_Zoom to fit", undef,       "Zoom fit",   sub{zoom(undef,0)}  ],
    );
    my @toggle_actions = (
        [ "Show_Grid", undef,            "_Show grid",      undef,    "Show grid",      \&toggle_grid,      1 ],
        [ "HL_Used",   undef,            "_Highlight used", undef,    "Highlight used", \&toggle_highlight, 0 ],
    );

    my $actions = Gtk2::ActionGroup->new( "Actions" );
    $actions->add_actions( \@menu_actions, undef );
    $actions->add_toggle_actions( \@toggle_actions, undef );

    my $ui = Gtk2::UIManager->new;
    $ui->insert_action_group( $actions, 0 );
    $mw->add_accel_group( $ui->get_accel_group );
    $ui->add_ui_from_string( $embedded->{ui} );
    $vbox->pack_start( $ui->get_widget( "/MenuBar" ), FALSE, FALSE, 0 );

    # create toolbar
    # TODO convert toolbar below to use UIManager
    my $toolbar = Gtk2::Toolbar->new;
    $toolbar->set_show_arrow (TRUE);

    my $t_btn_first = Gtk2::ToolButton->new_from_stock('gtk-goto-first');
    my $t_btn_prev  = Gtk2::ToolButton->new_from_stock('gtk-go-back');
    my $t_btn_next  = Gtk2::ToolButton->new_from_stock('gtk-go-forward');
    my $t_btn_last  = Gtk2::ToolButton->new_from_stock('gtk-goto-last');
    my $t_entry = Gtk2::Entry->new();
    $t_entry->set_width_chars(7);
    my $t_item_entry = Gtk2::ToolItem->new();
    $t_item_entry->add( $t_entry );
    my $t_btn_go  = Gtk2::ToolButton->new_from_stock('gtk-ok');

    $t_btn_first->signal_connect('clicked' => \&change_spectrum, 'first' );
    $t_btn_prev->signal_connect( 'clicked' => \&change_spectrum, 'prev' );
    $t_btn_next->signal_connect( 'clicked' => \&change_spectrum, 'next' );
    $t_btn_last->signal_connect( 'clicked' => \&change_spectrum, 'last' );
    $t_btn_go->signal_connect(   'clicked' => sub {change_spectrum($t_btn_go, 'by_id',
        $t_entry->get_text);} );
    $t_entry->signal_connect( 'key-release-event' => sub {
        if ($_[1]->keyval == 65293) {
            $t_btn_go->signal_emit('clicked');
        }
        #return TRUE;
    });

    $toolbar->insert($t_btn_first,-1);
    $toolbar->insert($t_btn_prev,-1);
    $toolbar->insert($t_btn_next,-1);
    $toolbar->insert($t_btn_last,-1);
    $toolbar->insert($t_item_entry,-1);
    $toolbar->insert($t_btn_go,-1);

    #my $sep = Gtk2::SeparatorToolItem->new;
    #$sep->set_draw(FALSE);
    #$sep->set_expand(TRUE);
    #$toolbar->insert($sep ,-1 );			

    $vbox->pack_start($toolbar,FALSE,FALSE,0);


    # create sidebar
    my $hbox_main = Gtk2::HBox->new(FALSE,0);
    my $layout = Gtk2::Table->new(2,5,FALSE);

    $ms2_canvas = MassCanvas->new();
    $ms1_canvas = MassCanvas->new();
    $xic_canvas = MassCanvas->new();
    $layout->attach($ms2_canvas,0,4,0,1,['expand','fill'],['expand','fill'],2,2);
    $layout->attach($ms1_canvas,0,4,1,2,['expand','fill'],['expand','fill'],2,2);
    $layout->attach($xic_canvas,4,5,0,1,['expand','fill'],['expand','fill'],2,2);

    # create list
    $list = Gtk2::SimpleList->new(
        'SpectrumID' => 'text',
        'Peptide'    => 'text',
    );
    $list->signal_connect('row_activated' => sub {
        my ($l, $path, $col) = @_;
        my $row_ref = $l->get_row_data_from_path($path);
        my $scan = $parser->fetch_record('spectrum' => $row_ref->[0]);
        load_scan($scan);
        annotate($scan, $row_ref->[1]);
        $curr_scan_index = $row_ref->[0];
    });
    my $sw = Gtk2::ScrolledWindow->new(undef,undef);
    $sw->set_policy('never','always');
    $sw->add($list);
    $sw->set_size_request(200,-1);
    $layout->attach($sw,4,5,1,2,['fill'],['fill'],2,2);

    $vbox->pack_start($layout,TRUE,TRUE,0);

    #create statusbar
    my $status_bar = Gtk2::Statusbar->new;
    $status_bar->set_size_request(1,20);
    my $status_context_id = $status_bar->get_context_id('current_status');
    $status_bar->push($status_context_id,'idle');
    $gobjs->{status_bar} = $status_bar;
    $vbox->pack_end($status_bar, FALSE, FALSE, 0);

    $gobjs->{status_bar} = $status_bar;

    $vbox->show_all();
    $toolbar->set_style('icons');
    
    return $vbox;
    
}

sub load_scan {

    my ($scan) = @_;

    $ms1_canvas->remove_shading($ms1_hid) if (defined $ms1_hid);
    $xic_canvas->remove_vline($xic_lid) if (defined $xic_lid);
    if ($scan->ms_level > 1) {
        $ms2_canvas->load_spectrum($scan);
        my $pre = $parser->fetch_record('spectrum' => $scan->precursor->{scan_id});
        if (defined $pre) {
            $ms1_canvas->load_spectrum($pre);
            my $l = $scan->precursor->{iso_lower};
            my $r = $scan->precursor->{iso_upper};
            my $s = $r - $l;
            $ms1_canvas->zoom_to($l-$s,$r+$s);
            $ms1_hid = $ms1_canvas->add_shading( $l, $r, '#0000ff44', 'ms2 isolation' );
            my $rt = $pre->rt;
            my $mz = $scan->precursor->{mono_mz};
            my $ic = $parser->get_xic(
                mz => $mz,
                err_ppm => 10,
                rt => $rt,
                rt_win => 120,
            );
            $ic->{window} = [$mz - $mz*10/1000000, $mz + $mz*10/1000000];
            $xic_canvas->load_chrom($ic);
            $xic_lid = $xic_canvas->add_vline($rt,'#ff0000ff');
        }
        else {
            $ms1_canvas->load_spectrum();
            $xic_canvas->load_spectrum();
        }
    }
    else {
        $ms1_canvas->load_spectrum($scan);
        $ms2_canvas->load_spectrum();
        $xic_canvas->load_spectrum();
    }

}

sub change_spectrum {

    my ($w,$cmd,$id) = @_;
    if (defined $parser) {
        my $scan_id;
        for ($cmd) {
            when( /first/ ) { $scan_id = $parser->first_spectrum_index }
            when( /prev/ )  { $scan_id = $parser->prev_spectrum_index($curr_scan_index) }
            when( /next/ )  { $scan_id = $parser->next_spectrum_index($curr_scan_index) }
            when( /last/ )  { $scan_id = $parser->last_spectrum_index }
            when( /by_id/)  { $scan_id = $id }
        }
        return if (! defined $scan_id);
        my $scan = $parser->fetch_record('spectrum' => $scan_id );
        load_scan( $scan );
        $curr_scan_index = $scan_id;
    }

}

sub round {

    my ($val,$places) = @_;
    $places = $places // 0;
    return (int($val*10**$places+0.5))/10**$places;

}

sub median {

    my @sorted = sort {$a <=> $b} @_;
    my $mid = int(@sorted/2);
    return $sorted[$mid] if (@sorted%2);
    return ($sorted[$mid-1] + $sorted[$mid])/2;

}

sub show_about {

    my $dialog = Gtk2::AboutDialog->new;
    $dialog->set_program_name( $NAME );
    $dialog->set_version( $VERSION );
    $dialog->set_copyright( chr(169) . " $YEAR Jeremy Volkening" );
    $dialog->set_comments('gRidderM is a software tool for extracting raw'
        . ' probe intensities from a set of four millichip images');
    $dialog->set_authors('Jeremy Volkening');
    $dialog->set_wrap_license(TRUE);
    $dialog->set_license(
        "$NAME is free software: you can redistribute it and/or modify" .
        ' it under the terms of the GNU General Public License as published' .
        ' by the Free Software Foundation, either version 2 of the License,' .
        " or (at your option) any later version.\n\n" .

        "$NAME is distributed in the hope that it will be useful, " .
        'but WITHOUT ANY WARRANTY; without even the implied warranty of ' .
        'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the ' .
        "GNU General Public License for more details.\n\n" .

        'You should have received a copy of the GNU General Public License ' .
        'along with this program.  If not, see http://www.gnu.org/licenses/.'
    );
    $dialog->set_logo( $embedded->{chip} );
    $dialog->run;
    $dialog->destroy;
    return 0;

}

sub get_embedded {

    my $embedded = {};

    my %encoded = (
        B2B_16      => $Spector::Embed::icon_B2B_16,
        ch_w        => $Spector::Embed::icon_ch_white,
        ch_g        => $Spector::Embed::icon_ch_green,
    );
    my %unencoded = (
        ui          => $Spector::Embed::ui,
    );

    for (keys %encoded) {
        $embedded->{$_} = do {
            my $loader = Gtk2::Gdk::PixbufLoader->new();
            $loader->write( decode_base64( $encoded{$_} ) );
            $loader->close;
            $loader->get_pixbuf();
        };
    }
    for (keys %unencoded) {
        $embedded->{$_} = $unencoded{$_};
    }
    return $embedded;

}

sub get_filename {

    my ( $heading, $type,) = @_;

    my $file_chooser =  Gtk2::FileChooserDialog->new( 
        $heading,
        $gobjs->{mw},
        $type,
        'gtk-cancel' => 'cancel',
        'gtk-ok' => 'ok'
    );

    # since we are auto-adding the correct suffix if missing, we need to
    # manually handle the overwrite confirmation and check the filename
    # with suffix added as well
    if ($type eq 'save') {
        $file_chooser->set_do_overwrite_confirmation(TRUE);
    }

    my $filename;
    if ('ok' eq $file_chooser->run){    
        $filename = $file_chooser->get_filename;
        # automatic overwrite confirmation doesn't work when we add a suffix
        # aftwards like this, so the feature is currently disabled
        # TODO: implement custom overwrite confirmation dialog to fix this
        #if ($type eq 'save' && $filename !~ /\.pair$/i) {
            #$filename .= '.pair';
        #}
    }
    $file_chooser->destroy;
    return $filename;

}

sub annotate {

   my ($scan,$pep) = @_;

   my @mz = $scan->mz;
   my @int = $scan->int;
   #my $cutoff = $int[ int(scalar(@int)*5/6) ]; # roughly Q3
   my $cutoff = 0;
   my $id = $scan->id;
   my @mods = @{ $mods{$id} };
   my $z = $charges{$id};
   my @frags = calc_fragments($pep, $mods{$id}, $z);
   #print join(" ",@{$_})."\n" for (@frags);
   my %matches;
   for my $i (0..$#mz) {
        next if ($int[$i] < $cutoff); # only label major peaks
        THEO:
        for my $theo (@frags) {
            my $diff = $mz[$i] - $theo->[0];
            next THEO if (abs($diff) > 0.4);
            next THEO if ( defined $matches{$theo->[0]}
                && $matches{$theo->[0]}->{diff} < $diff);
            my $col_idx = $theo->[1] =~ /^[abc]/ ? 1 : 2;
            my $lab = "$theo->[1]";
            $lab .= "<sub>$theo->[2]</sub>";
            $lab .= "<sup>$theo->[3]+</sup>" if ($theo->[3] > 1);
            my $extra = $theo->[4];
            if (defined $extra) {
                $extra =~ s/[A-Za-z]\K(\d+)/<sub>$1<\/sub>/g;
                $lab .= $extra;
            }
            $matches{$theo->[0]}->{diff} = $diff;
            $matches{$theo->[0]}->{entry} = [$i, $lab, $col_idx];
        }
    }
    my @labels = map {$matches{$_}->{entry}} keys %matches;
    $ms2_canvas->label(@labels);

    my @chars = split '', $pep;
    my @str = ('C-t', (map {$chars[$_] . $_} 0..$#chars), 'N-t');
    for (0..$#mods) {
        if ($mods[$_] =~ /^[\-\d\.]+$/) {
            $mods[$_] = sprintf '%.3f', $mods[$_];
        }
    }
    my $mod_string = join('; ', (map {$str[$_] . "($mods[$_])"} grep
    {$mods[$_] != 0} 0..$#mods));
    $ms2_canvas->{subtitle} = "$pep [$mod_string] [$z+]";

}
