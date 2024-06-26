package Gtk3::MassCanvas;

use warnings;
use strict;

use 5.012;

use Glib qw/TRUE FALSE/;
use Gtk3;
use Cairo;
use Pango::Cairo;
use List::Util qw/min max any/;
use POSIX qw/floor ceil/;
use MIME::Base64 qw/decode_base64/;

use MS::CV qw/:MS/;

use Glib::Object::Subclass
	Gtk3::DrawingArea::,
	signals => {
		draw                 => \&expose,
        configure_event      => \&resize,
        motion_notify_event  => \&on_motion,
        button_press_event   => \&on_click,
        button_release_event => \&on_release,
        key_press_event      => \&_on_key_press,
        scroll_event         => \&on_scroll,
	};

my $icon_B2B_16 = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz
AAAN1wAADdcBQiibeAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAADASURB
VDiNpZPBDYMwDEWf067TLsClR3Yoc/SKI3FiDtihC7AAnYYDuBdaEZpIFL5kyZKTp287ETPjqBSw
naEyJ7t1Brg/ntHiq2vouwZVpSzLoOa9R1URwFKAJSQ2KxEh2cI1K7hkBQBtnX8BIhLkDsDMglBV
+q6JOlo7cbFD637XtpOAdfFvB/88qqqqgHmNSwcpiHMuiGEYfgGpy6k1t3UeH+LH3hYJYCIStbdF
pxlyMzOmaWIcx82XAS9Hv/MbCXls+cixbw4AAAAASUVORK5CYII=
PNG

my $icon_ch_white = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAAAXNSR0IArs4c6QAAAAZiS0dEAAAA
AAAA+UO7fwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB90EFxMwAJscR20AAAAZdEVYdENv
bW1lbnQAQ3JlYXRlZCB3aXRoIEdJTVBXgQ4XAAAALUlEQVQ4y2NgIAD+////n5AaJgYqgFFDBrMh
jITSASMjIyMxaWU0sY0aQggAAMpCEBLL4xSxAAAAAElFTkSuQmCC
PNG

my $icon_ch_black = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAABmJLR0QA/wD/AP+gvaeTAAAAJUlE
QVQ4y2NgIAz+E1LAxEAFMGrIYDaEkYh0QIya0cQ2aghBAABh8wQbkCV0EQAAAABJRU5ErkJggg==
PNG

my $icon_ch_darkred = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAABmJLR0QA/wD/AP+gvaeTAAAALUlE
QVQ4y2NgIAAmysv/J6SGiYEKYNSQwWwII6F0kP/wISMxaWU0sY0aQggAAHI7CYjr/d6LAAAAAElF
TkSuQmCC
PNG

my $icon_ch_green = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH3gEUFQwjEsRhYgAAABl0RVh0Q29tbWVudABDcmVhdGVk
IHdpdGggR0lNUFeBDhcAAAAtSURBVDjLY2AgACL+y24mpIaJgQpg1JDBbAgjoXSwgvGxLzFpZTSx
jRpCCAAAiWsKk6T5wbEAAAAASUVORK5CYII=
PNG

my $icon_ch_red = <<PNG;
iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAABmJLR0QA/wD/AP+gvaeTAAAAKklE
QVQ4y2NgIAD+MzD8J6SGiYEKYNSQwWwII6F0wEiEGobRxDZqCBEAAIi1CBiqzDtiAAAAAElFTkSu
QmCC
PNG


use constant MARG_L => 60;
use constant MARG_R => 10;
use constant MARG_B => 40;
use constant MARG_T => 10;
use constant TICK_LEN => 6;
use constant X_PAD_FRAC => 0.02;
use constant Y_PAD_FRAC => 1.2;

use constant ZI   => 1.25;
use constant ZO   => 0.80;
use constant ZMAX => 10000;
use constant PI   => 4 * atan2(1, 1);
use constant FLOAT_TOL => 0.00000001;

use constant BLUE   => [0, 0, 1, 1];
use constant RED    => [1, 0, 0, 1];
use constant GREEN  => [0, 1, 0, 1];
use constant BLACK  => [0, 0, 0, 1];
use constant WHITE  => [1, 1, 1, 1];

my @label_colors = (
    BLACK,
    RED,
    BLUE,
);


sub zoom_full {

    my ($self) = @_;

    $self->{scale_x}    = 1;
    $self->{scale_y}    = 1;
    $self->{w_surf_p}   = $self->{w_view_p};
    $self->{h_surf_p}   = $self->{h_view_p};
    $self->{data_off_p} = 0;

    return;

}
sub _clamp {

    my ($val, $lower, $upper) = @_;
    return $val < $lower ? $lower
         : $val > $upper ? $upper
         : $val;

}

sub zoom_to {

    my ($self, $l_mz, $r_mz) = @_;
    warn "zoom to $l_mz, $r_mz\n";

    #$self->{scale_x} = ($self->{x}->[-1] - $self->{x}->[0])/($r_mz - $l_mz);
    #$self->{scale_x} = _clamp( $self->{scale_x}, 1, $self->{scale_x} );

    #$self->{w_surf_p} = $self->{w_view_p}*$self->{scale_x};

    #$self->calc_used;
    #$self->calc_axes;
    #$self->calc_coords(1);

    $self->{scale_x} = ($self->{x}->[-1] - $self->{x}->[0])/($r_mz - $l_mz);
    $self->{scale_x} = max($self->{scale_x},1);

    $self->{w_surf_p} = $self->{w_view_p}*$self->{scale_x};
    warn "SURF: $self->{w_surf_p}\n";

    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords(1);
    $self->calc_labels;

    $self->{data_off_p} = $self->x2p($l_mz);
    $self->{data_off_p} = max(0, $self->{data_off_p}); 

    $self->draw;

}

sub on_scroll {

    my ($self, $ev) = @_;

    my $xp = $ev->x - MARG_L;
    my @state = @{ $ev->state };
    my $sf = $ev->direction eq 'up' ? ZI : ZO;
    my $x_data = $self->p2x($xp + $self->{data_off_p});
    my $axis = (@state && $state[0] eq 'control-mask') ? 'y' : 'x';

    # CTLR+scrollbutton = change y-zoom
    if ($axis eq 'y') {
        $self->zoom_y($sf);
    }

    # scrollbutton alone = change x-zoom
    else {
        $self->zoom_x($sf, $x_data);
    }

}

sub zoom_y {

    my ($self, $sf) = @_;

    $self->{scale_y} *= $sf;
    $self->{scale_y} = _clamp( $self->{scale_y}, 0.7, ZMAX);

    $self->{w_surf_p} = $self->{w_view_p}*$self->{scale_x};
    $self->{h_surf_p} = $self->{h_view_p}*$self->{scale_y};

    $self->calc_axes;
    $self->calc_coords(0);

    $self->draw;

}

sub zoom_x {

    my ($self, $sf, $x_data) = @_;

    my $xp = $self->x2p($x_data) - $self->{data_off_p};

    $self->{scale_x} *= $sf;
    $self->{scale_x} = max($self->{scale_x},1);

    $self->{w_surf_p} = $self->{w_view_p}*$self->{scale_x};
    $self->{h_surf_p} = $self->{h_view_p}*$self->{scale_y};

    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords(1);
    $self->calc_labels;

    my $new_x_pixel = $self->x2p($x_data) - $self->{data_off_p};
    $self->{data_off_p} += $new_x_pixel - $xp;
    $self->{data_off_p} = max(0, $self->{data_off_p}); 

    $self->draw;

}


sub calc_coords {

    my ($self, $do_x) = @_;
    $do_x = $do_x // 1;

    # store peak pixel coords
    my @y_pixel;
    for (0..$#{ $self->{y_used} }) {
        my $int = $self->{y_used}->[$_];
        my $y_actual = $self->y2p( $int );
        push @y_pixel, $y_actual;
    }
    $self->{y_pixel} = [@y_pixel];
    my $max = $self->{tick_y_max};
    my $min = $self->{tick_y_min};
    my $pw = $self->{h_view_p} / ($max - $min);
    $self->{yplaces} = $pw > 0 ? ceil( log_n($pw, 10) ) : 0;

    if ($do_x) {
        my @x_pixel;
        for (0..$#{ $self->{x_used} }) {
            my $mz  = $self->{x_used}->[$_];
            my $x_actual = $self->x2p( $mz ) + 0.5;
            push @x_pixel, $x_actual;
        }
        $self->{x_pixel} = [@x_pixel];
        # calculate sig figs to display
        my $min = $self->{min_x_c};
        my $max = $self->{max_x_c};
        my $pw = ($self->{w_surf_p}) / ($max - $min);
        $self->{xplaces} = $pw > 0 ? ceil( log_n($pw, 10) ) : 0;
    }

}   

sub calc_used {

    my ($self) = @_;

    my @x_used;
    my @y_used;
    my $curr_mz  = $self->{x}->[0];
    my $curr_int = $self->{y}->[0];
    my $curr_idx = 0;
    my $curr_x = $self->x2p( $curr_mz ) + 0.5;
    my $curr_y = $self->y2p( $curr_int ) + 0.5;
    my $last_int;
    my $last_mz;
    my $last_idx = 0;
    for (1..$#{ $self->{x} }) {
        my $mz  = $self->{x}->[$_];
        my $int = $self->{y}->[$_];
        my $x_actual = $self->x2p( $mz ) + 0.5;
        my $y_actual = $self->y2p( $int) + 0.5 ;

        if ($x_actual > $curr_x) {
            push @x_used, $curr_mz;
            push @y_used, $curr_int;
            # store link back to uncompressed index
            $self->{xmap}->{$#x_used} = $curr_idx;
            if (defined $last_int && $last_int == 0) {
                push @x_used, $last_mz;
                push @y_used, $last_int;
                $self->{xmap}->{$#x_used} = $last_idx;
            }
            if ($int == 0) {
                push @x_used, $mz;
                push @y_used, $int;
                $self->{xmap}->{$#x_used} = $_;
            }
            $curr_mz = undef;
            $curr_int = undef;
            $curr_x = undef;
            $curr_y = undef;
            $curr_idx = undef;
        }
        $last_mz = $mz;
        $last_int = $int;
        $last_idx = $_;
            
        next if (defined $curr_int && $int < $curr_int);

        $curr_x = $x_actual;
        $curr_y = $y_actual;
        $curr_mz = $mz;
        $curr_int = $int;
        $curr_idx = $_;
    }
    push @x_used, $curr_mz;
    push @y_used, $curr_int;
    $self->{xmap}->{$#x_used} = $curr_idx;

    $self->{x_used} = [@x_used];
    $self->{y_used} = [@y_used];

}

sub calc_labels {

    my ($self) = @_;
    # calculate peak labels

    my @x_used = @{$self->{x_used}};
    my @y_used = @{$self->{y_used}};
    my @order = sort {$y_used[$b] <=> $y_used[$a]} 0..$#y_used;
    my $max = $y_used[ $order[0] ];
    my @boxes;
    $self->{labeled}->{$_}->[0] = undef
        for (grep {defined $self->{labeled}->{$_}->[0]->[2]}
        keys %{$self->{labeled}});
    PEAK:
    for (0..$self->{max_label}-1) {
        last if ($_ > $#order);
        my $i = $order[$_];
        my $x = $x_used[$i];
        my $y = $y_used[$i];
        last if ($y < $max * $self->{min_ratio});

        my $lab = sig_fig($x, 6);
        $x = $self->x2p($x);
        my $w   = length($lab) * $self->{em}->[0];
        my $x1 = $x - $w/2;
        my $x2 = $x + $w/2;
        for (0..$_-1) {
            my $j = $order[$_];
            my $p = $self->x2p( $x_used[$j] );
            next PEAK if ($p >= $x1 && $p <= $x2);
        }
        $self->{labeled}->{
                $self->{xmap}->{$i}
            }->[0] = [$lab,0,1];

    }

}

sub label {

    my ($self, @labels) = @_;

    LABEL:
    for (@labels) {
        my $l = $self->{labeled}->{ $_->[0] }->[1];
        if (defined $l) {
            if ($l->[2] <= $_->[3]
              || (defined $_->[4] && ! defined $l->[3])) {
                next LABEL;
            }
            else {
                warn "replacing $self->{labeled}->{$_->[0]}->[1]->[0] with $_->[1]\n";
            }
        }
        $self->{labeled}->{$_->[0]}->[1]
            = [$_->[1],$_->[2],$_->[3],$_->[4]];
    }
    $self->draw();

}

sub _anchor_pango {

    my ($cr, $layout, $dir, $x, $y) = @_;

    my ($lx,$ly) = $layout->get_size;
    my $x_actual = $x - $lx / &Pango::SCALE / 2;
    my $y_actual = $y - $ly / &Pango::SCALE / 2;

    for ($dir) {
        if(/s/) {
            $y_actual = $y - $ly/&Pango::SCALE;
        }
        if(/n/) {
            $y_actual = $y;
        }
        if(/e/) {
            $x_actual = $x - $lx/&Pango::SCALE;
        }
        if(/w/) {
            $x_actual = $x
        }
    }
    $cr->move_to( $x_actual, $y_actual );
    Pango::Cairo::show_layout($cr,$layout);

}

sub add_shading {

    my ($self,$left,$right,$color,$label) = @_;
    my $id = $self->{hilite_iter}++;
    $self->{hilites}->{$id} = [$left,$right,$color,$label];
    $self->draw;
    return $id;

}

sub remove_shading {

    my ($self,$id) = @_;
    delete $self->{hilites}->{$id};
    $self->draw;

}

sub add_vline {

    my ($self,$mz,$color,$label) = @_;
    my $id = $self->{vline_iter}++;
    $self->{vlines}->{$id} = [$mz,$color,$label];
    $self->draw;
    return $id;

}

sub remove_vline {

    my ($self,$id) = @_;
    delete $self->{vlines}->{$id};
    $self->draw;

}
        

sub calc_axes {

    my ($self) = @_;

    my $x_ticks = $self->{w_surf_p}  / 50;
    my $y_ticks = $self->{h_surf_p} / 24;
    $x_ticks = $x_ticks > 2 ? $x_ticks : 2;
    $y_ticks = $y_ticks > 2 ? $y_ticks : 2;

    # recalculate axes
    if (defined $self->{x}) {
        my $padding = ($self->{x}->[-1] - $self->{x}->[0]) * 0.02;
        my $min_x_c = $self->{min_x_c};
        my $max_x_c = $self->{max_x_c};
        my $min_y_c = $self->{min_y_c};
        my $max_y_c = $self->{max_y_c};

        # calc y ticks
        my ($tick_min, $tick_max, $space, $digits) = $max_y_c > $min_y_c
            ? calc_ticks( $min_y_c ,$max_y_c ,$y_ticks, 10)
            : (0, 1, 1, 1);
        while ($tick_min < $min_y_c) {
            $tick_min += $space;
        }
        $self->{tick_y_min}    = $tick_min;
        $self->{tick_y_max}    = $tick_max;
        $self->{tick_y_space}  = $space;
        $self->{tick_y_digits} = $digits;

        # calc x ticks
        ($tick_min, $tick_max, $space, $digits) = $max_x_c > $min_x_c
            ? calc_ticks( $min_x_c ,$max_x_c ,$x_ticks, 10)
            : (0, 1, 1, 1);
        while ($tick_min < $min_x_c) {
            $tick_min += $space;
        }
        $self->{tick_x_min}    = $tick_min;
        $self->{tick_x_space}  = $space;
        $self->{tick_x_digits} = $digits;

        #$self->{min_x_c} = $min_x_c;
        #$self->{max_x_c} = $max_x_c;

        #draw y-axis
        my $h = $self->{h_view_p} + MARG_T + MARG_B;
        $self->{surf_yaxis} = Cairo::ImageSurface->create(
            'argb32', MARG_L,  $h);
        my $cr = Cairo::Context->create($self->{surf_yaxis});
        $cr->save;
        $cr->set_line_width(1);
        $cr->set_source_rgba(0.0,0.0,1.0,1.0);
        my $pw = $self->{h_surf_p} / $self->{tick_y_max};

        my $layout = Pango::Cairo::create_layout($cr);
        $layout->set_alignment('right');
        $layout->set_font_description($self->{font_small});

        my $y = $self->{tick_y_min};
        my $bot;
        my $top;
        while ($y <= $self->{tick_y_max}) {
            my $y_actual = int(MARG_T + $self->{h_view_p} - $y*$pw) + 0.5;
            $bot = $y_actual if ($y == $self->{tick_y_min});
            last if ($y_actual < MARG_T);
            $top = $y_actual;
            $cr->move_to(MARG_L,$y_actual);
            $cr->line_to(MARG_L - TICK_LEN, $y_actual);

            my $text = sprintf "%.1e",$y;
            $layout->set_text($text);
            Pango::Cairo::update_layout($cr,$layout);
            _anchor_pango($cr, $layout, 'e', MARG_L - TICK_LEN - 2, $y_actual);

            $y += $self->{tick_y_space};
        }
        $cr->stroke;

        $layout->set_text($self->{ylab});
        Pango::Cairo::update_layout($cr,$layout);
        $cr->rotate(PI/-2);
        _anchor_pango($cr, $layout, 's',
            $h - MARG_B - $self->{h_view_p}/2, MARG_L);
        $cr->restore;
    }

}

sub _euclidean {

    my ($p1,$p2) = @_;
    return sqrt(
        ($p2->[0] - $p1->[0])**2
      + ($p2->[1] - $p1->[1])**2
    );

}

sub set_peptide {

    my ($self, $seq) = @_;
    $self->{peptide} = $seq;

    $self->draw();

}

sub fit_y {

    my ($self) = @_;

    my $lp = $self->{data_off_p};
    my $rp = $lp + $self->{w_view_p};

    my $li = $self->find_nearest($lp);
    my $ri = $self->find_nearest($rp);

    my $max_y = 0;
    for my $i ($li..$ri-1) {
        my $y = $self->{y}->[$self->{xmap}->{$i}];
        $max_y = $y if ($y > $max_y);
    }
    my $sf = $self->{max_y_c}/Y_PAD_FRAC/$max_y;
    $self->zoom_y($sf);

}

sub index_at {

    my ($self, $xc) = @_;

    $xc += $self->{data_off_p};
    my $i = $self->find_nearest($xc);

    return $self->{xmap}->{$i};

}

sub closest_point {

    # returns x index of closest used point 

    my ($self, $xc, $yc) = @_;

    $xc += $self->{data_off_p};

    #calculate view window
    my $best_i;
    my $best_d;

    my $i = $self->find_nearest($self->{data_off_p}) - 1;
    $i = 0 if ($i < 0);
    for ($i..$#{$self->{x_pixel}}) {
        my $xp = $self->{x_pixel}->[$_];
        my $yp = $self->{y_pixel}->[$_];
        my $dist = _euclidean( [$xc,$yc],[$xp,$yp] );
        if (! defined $best_d || $dist < $best_d) {
            $best_d = $dist;
            $best_i = $_;
        }
        last if ($xp > $self->{data_off_p} + $self->{w_view_p});
    }
    return $best_i;

}

sub on_click {

    my ($self, $ev) = @_;
    my ($px, $py) = ($ev->x - MARG_L, $ev->y - MARG_T);
    my @state = @{ $ev->state };

    $self->grab_focus;

    return if (! $self->{inside});

    if ($ev->button == 1) { #left button for dragging

        # CTRL-left means find closest peak
        if (@state && $state[0] eq 'control-mask') {
            my $i = $self->closest_point($px, $py);
            $self->{ruler}->[0] = $i;
        }
        elsif (@state && $state[0] eq 'shift-mask') {
            $self->{left_drag} = [$px,$px];
            $self->queue_draw;
        }
        else {
            my $i = $self->closest_point($px, $py);
            warn "closest_point: $i\n";
            $self->set_selection( $self->{xmap}->{$i} );
        }

    }
    elsif ($ev->button == 3) { #right button for dragging
        $self->get_window->set_cursor( $self->{cursors}->{drag} );
        $self->{cursor} = $self->{cursors}->{drag};
        $self->{right_drag} = TRUE;
    }

}

sub on_release {

    my ($self,$ev) = @_;
    my $px = $ev->x - MARG_L;

    if ($ev->button == 1) { #left button for dragging
        if (defined $self->{left_drag}) {
            my $min_y;
            my $max_i;
            my $l = $self->{left_drag}->[0] - 1 + $self->{data_off_p};
            my $r = $self->{left_drag}->[1] + 1 + $self->{data_off_p};
            for (0..$#{ $self->{x_pixel} }) {
                my $x  = $self->{x_pixel}->[$_];
                next if ($x <= $l);
                last if ($x >= $r);
                my $y  = $self->{y_pixel}->[$_];
                if (! defined $min_y || $y < $min_y) {
                    $min_y = $y;
                    $max_i = $_;
                }
            }
            if (defined $max_i) {
                my $lab = round($self->{x_used}->[$max_i], 3);
                $self->{labeled}->{
                      $self->{xmap}->{$max_i}
                    }->[0] = [$lab,0];
            }
            $self->{left_drag} = undef;
        }
        
        $self->{ruler} = [];
        $self->draw();
    }

    if ($ev->button == 3) { #right button for dragging
        $self->{cursor} = $self->{cursors}->{ch_red};
        $self->get_window->set_cursor( $self->{cursor} );
        $self->{right_drag} = FALSE;
    }
    $self->{last_x} = undef;

}

sub p2x {

    my ($self,$px) = @_;
    my $mw = ($self->{max_x_c} - $self->{min_x_c}) / $self->{w_surf_p};
    return $px * $mw + $self->{min_x_c};

}

sub x2p {
    
    my ($self,$mz) = @_;
    my $pw = $self->{w_surf_p} / ($self->{max_x_c} - $self->{min_x_c});
    return round(($mz - $self->{min_x_c})*$pw,0);

}

sub y2p {

    my ($self,$int) = @_;
    my $pw = $self->{h_surf_p} / $self->{tick_y_max};
    return floor($self->{h_view_p} - $int*$pw) + 0.5;

}

sub p2y {

    my ($self,$py) = @_;
    my $mw = $self->{tick_y_max} / $self->{h_surf_p};
    return ($self->{h_view_p} - $py) * $mw;

}

sub on_motion {

    my ($self, $ev) = @_;
    my ($xp, $yp) = ($ev->x - MARG_L, $ev->y - MARG_T);

    my $ha = $self->get_allocation()->{height};
    my $wa = $self->get_allocation()->{width};

    # check if we are entering or leaving plot area
    if ( $xp < 0
      || $xp > $self->{w_view_p}
      || $yp < 0
      || $yp > $self->{h_view_p}
    ) {
        $self->get_window->set_cursor($self->{old_cursor})
            if ($self->{inside});
        $self->{inside} = 0; 
    }
    else {
        if (! $self->{inside}) {
            $self->{old_cursor} = $self->get_window->get_cursor;
            $self->get_window->set_cursor($self->{cursor})
        }
        $self->{inside} = 1;
    }

    # calculate coordinates to display
    my $x_data;
    my $y_data;
    if ($self->{inside}) {
        $x_data = $self->p2x($xp + $self->{data_off_p});
        $x_data = round($x_data,$self->{xplaces});
        $y_data = $self->p2y($yp);
        $y_data = sprintf("%.1e", $y_data);

        $self->{cx} = $xp;
        $self->{cy} = $yp;
    }
    else {
        $self->{cx} = undef;
        $self->{cy} = undef;
    }

    #update coord surface
    if ($self->{inside}) {
        $self->{surf_coords} = Cairo::ImageSurface->create('argb32',100,40);
        my $cr = Cairo::Context->create($self->{surf_coords});

        $cr->save;
        $cr->set_source_rgba(0.0,0.0,0.0,1.0);

        my $layout = Pango::Cairo::create_layout($cr);
        my $desc = Pango::FontDescription::from_string('Sans 8');
        $layout->set_font_description($desc);
        $layout->set_markup($x_data);
        Pango::Cairo::update_layout($cr,$layout);
        my ($lx,$ly) = $layout->get_size;
        $cr->move_to(0,0);
        Pango::Cairo::show_layout($cr,$layout);
        $layout->set_markup($y_data);
        $cr->move_to(0,12);
        Pango::Cairo::show_layout($cr,$layout);
        $cr->restore;
        $cr->show_page;
    }

    my $sensitivity = 3;

    if (! defined $self->{last_x}) {
        $self->{last_x} = $xp;
        $self->queue_draw;
        return;
    }
    elsif (abs($self->{last_x} - $xp) < $sensitivity) {
        $self->queue_draw;
        return;
    }

    if ($self->{inside}) {
        if (defined $self->{left_drag}) {
            my ($l,$r) = @{ $self->{left_drag} };
            if ($xp > $self->{last_x}) {
                $l = $xp if ($xp <= $r);
                $r = $xp if ($xp >  $r);
            }
            elsif ($xp < $self->{last_x}) {
                $r = $xp if ($xp >= $l);
                $l = $xp if ($xp <  $l);
            }
            $self->{left_drag} = [$l,$r];
        }

        elsif ($self->{right_drag}) {
            if (defined $self->{last_x}) {
                $self->{data_off_p} += $self->{last_x} - $xp;
                my $max = $self->{w_surf_p} - ($self->{w_view_p});
                $self->{data_off_p} = $max if ($self->{data_off_p} > $max);
                $self->{data_off_p} = 0 if ($self->{data_off_p} < 0);
            
            }
            $self->draw();
        }

        if (defined $self->{ruler}->[0]) {
            my $i = $self->closest_point($xp, $yp);
            $self->{ruler}->[1] = $i;
        }
            
    }
    $self->queue_draw;
    $self->{last_x} = $xp;
    return TRUE;

}

sub calc_ticks {

    # Heckbert method

    my ($start, $end, $n_ticks, $base) = @_;
    $base //= 10;
    my $range = nice_num($end - $start, 0, $base);
    my $space = nice_num($range/($n_ticks-1),1, $base);
    my $min = floor($start/$space)*$space;
    my $max = ceil($end/$space)*$space;
    my $digits = max(-floor(log_n($space,$base)),0);
    return ($min, $max, $space, $digits);

}

sub nice_num {

    # Heckbert method

    my ($val,$round, $base) = @_;

    my $exp = floor(log_n($val,$base));
    my $f   = $val / $base**$exp;

    my $nf;
    if ($round) {
        $nf = $f < 1.5 ? 1
            : $f < 3   ? 2
            : $f < 7   ? 5
            :           10;
    }
    else {
        $nf = $f < 1 ? 1
            : $f < 2 ? 2
            : $f < 5 ? 5
            :         10;
    }
    return $nf*$base**$exp;

}

sub log_n {
    
    my ($n,$base) = @_;
    $base = $base // 10;
    return log($n)/log($base);

}

# returns index to nearest pixel array greater than or equal to $xp
sub find_nearest {

    my ($self, $xp) = @_;

    my $lower = 0;
    my $upper = $#{$self->{x_pixel}};
    while ($lower != $upper) {
        my $mid = int( ($lower+$upper)/2 );
        ($lower,$upper) = $xp > $self->{x_pixel}->[$mid] + FLOAT_TOL
            ? ($mid+1, $upper)
            : ($lower, $mid  );
    }
    if ($lower > 0) {
        my $r = $self->{x_pixel}->[$lower];
        my $l = $self->{x_pixel}->[$lower-1];
        $lower = $xp - $l > $r - $xp ? $lower : $lower - 1;
    }
    return $lower;

}

sub draw {

	my $self = shift;
    my $alloc = $self->get_allocation;
    my $w_bg = $alloc->{width};
    my $h_bg = $alloc->{height};

    $self->{surf_lbl} =
        Cairo::ImageSurface->create('argb32', $self->{w_view_p},  $self->{h_view_p}+30);
    $self->{surf_data} =
        Cairo::ImageSurface->create('argb32', $self->{w_view_p}, $self->{h_view_p}+30);
    $self->{surf_bg} =
        Cairo::ImageSurface->create('argb32',$w_bg, $h_bg);
	my $cr_lbl  = Cairo::Context->create($self->{surf_lbl});
	my $cr_data = Cairo::Context->create($self->{surf_data});
	my $cr_bg   = Cairo::Context->create($self->{surf_bg});

    # draw peptide plot

    if (defined $self->{peptide}) {

        my $pep = $self->{peptide};

        my $layout = Pango::Cairo::create_layout($cr_lbl);
        $layout->set_font_description($self->{font_med});
        $layout->set_text('M');
        Pango::Cairo::update_layout($cr_lbl,$layout);
        my ($lx,$ly) = $layout->get_size;
        my $em = [$lx/&Pango::SCALE, $ly/&Pango::SCALE];

        my $space = 9;

        my $w = length($pep)*($em->[0]+$space);
        my $h = $em->[1] * 4;
        $self->{surf_pep} =
            Cairo::ImageSurface->create('argb32',$w, $h);
        my $cr_pep = Cairo::Context->create($self->{surf_pep});
        
        $cr_pep->save;
        $layout = Pango::Cairo::create_layout($cr_pep);
        $layout->set_font_description($self->{font_med});
        my $layout2 = Pango::Cairo::create_layout($cr_pep);
        $layout2->set_font_description($self->{font_small});
        my $x = int($em->[0]/2+$space/2)+0.5;
        my $y = $h/2;
        $cr_pep->set_line_width(1);
        my @res = split '', $pep;
        for (0..$#res) {

            my $ib = $_ + 1;
            my $iy = $#res - $_;

            my $aa = $res[$_];
            $cr_pep->set_source_rgba(0,0,0,1);
            $layout->set_text($aa);
            Pango::Cairo::update_layout($cr_pep, $layout);
            _anchor_pango($cr_pep, $layout, '',  $x, $y);
            last if ($_ == $#res);
            $x += $em->[0]/2+$space/2;
            $cr_pep->move_to($x,$y);
            $cr_pep->line_to($x,$y-$em->[1]/2-2);
            $cr_pep->line_to($x+$em->[0]/2 ,$y-$em->[1]/2-7);
            $cr_pep->set_source_rgba(0,0,1,1);
            $cr_pep->stroke;

            $layout2->set_markup("y<sub>$iy</sub>");
            Pango::Cairo::update_layout($cr_pep, $layout2);
            _anchor_pango($cr_pep, $layout2, 's',  $x+$em->[0]/2+1,
                $y-$em->[1]/2-8);

            $cr_pep->move_to($x,$y);
            $cr_pep->line_to($x,$y+$em->[1]/2+2);
            $cr_pep->line_to($x-$em->[0]/2 ,$y+$em->[1]/2+7);
            $cr_pep->set_source_rgba(1,0,0,1);
            $cr_pep->stroke;

            $layout2->set_markup("b<sub>$ib</sub>");
            Pango::Cairo::update_layout($cr_pep, $layout2);
            _anchor_pango($cr_pep, $layout2, 'n',  $x-$em->[0]/2-1,
                $y+$em->[1]/2+8);

            $x += $em->[0]/2+$space/2;
        }
        $cr_pep->restore;
        $cr_pep->show_page;

    }
    #calculate view window

    if (defined $self->{x_pixel}) { 

        my $xref = $self->{x_pixel};
        my $yref = $self->{y_pixel};

        # draw x label
        $cr_bg->save;
        $cr_bg->set_source_rgba(0.0,0.0,1.0,1.0);
        my $layout = Pango::Cairo::create_layout($cr_bg);
        $layout->set_font_description($self->{font_small});
        $layout->set_text($self->{xlab});
        Pango::Cairo::update_layout($cr_bg,$layout);
        _anchor_pango($cr_bg, $layout, 'n', $self->{w_view_p}/2 + MARG_L,
            $self->{h_view_p} + MARG_T + 20);
        $cr_bg->restore;

        #prepare to draw data
        $cr_data->save;
        $cr_data->set_source_rgba(0.0,0.0,1.0,1.0);
        $cr_data->set_line_width(1);

        $cr_lbl->save;
        $cr_lbl->set_source_rgba(0.0,0.0,0.0,1.0);
        $cr_lbl->set_line_width(1);

        # draw highlights
        my @sorted = sort {$self->{hilites}->{$a}->[0] <=> $self->{hilites}->{$b}->[0]} keys %{ $self->{hilites} };
        for (@sorted) {

            my ($l_mz,$r_mz,$color,$label) = @{ $self->{hilites}->{$_} };
            my @rgba = map {hex($_)/255 } unpack 'xa2a2a2a2', $color;
            my $l_px = $self->x2p($l_mz) - $self->{data_off_p};
            my $r_px = $self->x2p($r_mz) - $self->{data_off_p};
            $cr_data->save;
            $cr_data->set_source_rgba(@rgba);
            $cr_data->rectangle($l_px,0,$r_px - $l_px+1,$self->{h_view_p});
            $cr_data->fill;
            $cr_data->restore;
            if (defined $label) {
                $cr_data->save;
                my $layout = Pango::Cairo::create_layout($cr_data);
                $layout->set_alignment('left');
                $layout->set_font_description($self->{font_small});
                $layout->set_text($label);
                Pango::Cairo::update_layout($cr_data,$layout);
                _anchor_pango($cr_data, $layout, 'nw', $l_px+5, 14);
                $cr_data->restore;
            }

        }

        # draw vlines
        @sorted = sort {$self->{vlines}->{$a}->[0] <=> $self->{vlines}->{$b}->[0]} keys %{ $self->{vlines} };
        for (@sorted) {

            my ($mz,$color,$label) = @{ $self->{vlines}->{$_} };
            my @rgba = map {hex($_)/255 } unpack 'xa2a2a2a2', $color;
            my $px = $self->x2p($mz) - $self->{data_off_p} + 0.5;
            $cr_data->save;
            $cr_data->set_source_rgba(@rgba);
            $cr_data->move_to($px,0);
            $cr_data->line_to($px,$self->{h_view_p});
            $cr_data->stroke;
            $cr_data->restore;
            if (defined $label) {
                $cr_data->save;
                my $layout = Pango::Cairo::create_layout($cr_data);
                $layout->set_font_description($self->{font_small});
                $layout->set_text($label);
                Pango::Cairo::update_layout($cr_data,$layout);
                _anchor_pango($cr_data, $layout, 'nw', $px+5, 14);
                $cr_data->restore;
            }

        }

        #draw x-axis
        my $pw = $self->{w_surf_p}
            / ($self->{max_x_c} - $self->{min_x_c});


        $layout = Pango::Cairo::create_layout($cr_data);
        $layout->set_font_description($self->{font_small});
        my $c = $self->{scale_x_min};
        while ($c <= $self->{max_x_c}) {
            my $xp = $self->x2p( $c ) - $self->{data_off_p} + 0.5;
            last if ($xp > $self->{w_view_p});
            $layout->set_text( $c );
            $c += $self->{tick_x_space};
            my ($lw,$lh) = $layout->get_pixel_size;
            next if ($xp - $lw/2 < 0);
            last if ($xp + $lw/2 > $self->{w_view_p});

            $cr_data->move_to($xp,$self->{h_view_p});
            $cr_data->line_to($xp,$self->{h_view_p} + TICK_LEN);

            Pango::Cairo::update_layout($cr_data,$layout);
            _anchor_pango($cr_data, $layout, 'n',
                $xp, $self->{h_view_p} + TICK_LEN + 2);

        }
        $cr_data->stroke;
        $cr_data->restore;

        # finally, plot data
        $cr_data->save;
        $cr_data->set_source_rgba(0.0, 0.0, 0.0, 1.0);
        $cr_data->set_line_width(1);

        my $last_point;

        my $left = $self->{data_off_p};

        #semi-binary search
        my $i = ($self->find_nearest($left) // 0) - 1;
        $i = 0 if ($i < 0);
        
        while ($i <= $#{$xref}) {
            my $xp = $xref->[$i] - $self->{data_off_p};
            my $yp = $yref->[$i];
            if ($self->{type} eq 'sticks') {
                $cr_data->move_to($xp, $self->{h_view_p});
                $cr_data->line_to($xp, $yp);
            }
            elsif ($self->{type} eq 'lines') {
        
                if (defined $last_point) {
                    $cr_data->line_to($xp, $yp);
                }
                else {
                    $cr_data->move_to($xp, $yp);
                }
                $last_point = [$xp, $yp];

            }
            last if ($xp > $self->{w_view_p});
            if (defined $self->{labeled}->{ $self->{xmap}->{$i} }) {
                my $y = $yp;
                my $x = $xp;
                my $c = 1;
                for my $lab (@{ $self->{labeled}->{ $self->{xmap}->{$i} } }) {
                    next if (! defined $lab->[1]);
                    ++$c;
                    $cr_lbl->save;
                    $x += 0.5;
                    $layout->set_markup( $lab->[0] );
                    Pango::Cairo::update_layout($cr_lbl,$layout);
                    my ($lx,$ly) = $layout->get_size;
                    $cr_lbl->move_to($x-$lx/2/&Pango::SCALE,$y - $ly/&Pango::SCALE - 2);
                    $y -= $ly/&Pango::SCALE + 1;
                    Pango::Cairo::layout_path($cr_lbl,$layout);
                    $cr_lbl->set_line_width(3);
                    $cr_lbl->set_source_rgba(1.0, 1.0, 1.0, 1.0);
                    $cr_lbl->stroke_preserve;
                    $cr_lbl->set_source_rgba(@{ $label_colors[$lab->[1]] });
                    $cr_lbl->fill;
                    $cr_lbl->restore;
                }
            }
            ++$i;
        }

        # always draw certain labels
        for my $xc (keys %{ $self->{labeled} }) {
           
            next if (! defined $xc);
            my $mz  = $self->{x}->[$xc];
            next if (! defined $mz);
            my $int = $self->{y}->[$xc];
            my $x = $self->x2p( $mz ) - $self->{data_off_p} + 0.5;
            my $y = $self->y2p( $int );

            my $c = 1;
            my $lab = $self->{labeled}->{$xc}->[1];
            next if ! defined $lab;
            next if (! defined $lab->[1]);
            ++$c;
            $cr_lbl->save;
            $x += 0.5;
            $layout->set_markup( $lab->[0] );
            Pango::Cairo::update_layout($cr_lbl,$layout);
            my ($lx,$ly) = $layout->get_size;
            $cr_lbl->move_to($x-$lx/2/&Pango::SCALE,$y - $ly/&Pango::SCALE - 2);
            $y -= $ly/&Pango::SCALE + 1;
            Pango::Cairo::layout_path($cr_lbl,$layout);
            $cr_lbl->set_line_width(3);
            $cr_lbl->set_source_rgba(1.0, 1.0, 1.0, 1.0);
            $cr_lbl->stroke_preserve;
            $cr_lbl->set_source_rgba(@{ $label_colors[$lab->[1]] });
            $cr_lbl->fill;
            $cr_lbl->restore;
        }

        $cr_data->stroke;
        $cr_data->restore;

        $cr_data->show_page;
        $cr_lbl->show_page;
    }
    $self->queue_draw();

	return TRUE;
}

sub expose {

	my ($self, $cr) = @_;

	#$cr //= Gtk3::Gdk::Cairo::Context->create($self->get_window);
    my $alloc = $self->get_allocation;
    my $w = $alloc->{width};
    my $h = $alloc->{height};

    # draw white background
    $cr->save;
    $cr->rectangle(0,0,$w,$h);
    $cr->set_source_rgba(1,1,1,1);
    $cr->fill;

    # draw outline depending on focus status
    my @col = $self->has_focus ? (1,0,0,1) : (0,0,0,1);
    $cr->set_line_width(1);
    $cr->rectangle(0.5, 0.5, $w-1, $h-1);
    $cr->set_source_rgba(@col);
    $cr->stroke;
    $cr->restore;

    # draw base surface
    $cr->save;
    $cr->set_source_surface($self->{surf_bg},0,0);
    $cr->paint;
    $cr->restore;

    # draw y-axis surface
    $cr->save;
    $cr->set_source_surface($self->{surf_yaxis},0,0);
    $cr->paint;
    $cr->restore;

    # draw data surface
    $cr->save;
    $cr->rectangle(MARG_L, MARG_T, $w - MARG_R - MARG_L, $h - MARG_B - MARG_T + 30);
    $cr->clip;
    $cr->set_source_surface($self->{surf_data},MARG_L ,MARG_T);
    $cr->paint;
    $cr->restore;

    # draw data labels
    $cr->save;
    $cr->rectangle(MARG_L, MARG_T, $w - MARG_R - MARG_L, $h - MARG_B - MARG_T + 30);
    $cr->clip;
    $cr->set_source_surface($self->{surf_lbl},MARG_L ,MARG_T);
    $cr->paint;
    $cr->restore;

    # draw header
    for (0..$#{ $self->{titles} }) {
        my $title = $self->{titles}->[$_];
        next if (! defined $title);
        my $color = $self->{title_colors}->[$_] // BLACK;
        $cr->save;
        $cr->rectangle(MARG_L, MARG_T, $w - MARG_R - MARG_L, $h - MARG_B - MARG_T + 30);
        $cr->clip;
        $cr->set_source_rgba(@$color);
        my $layout = Pango::Cairo::create_layout($cr);
        $layout->set_font_description($self->{font_small});
        $layout->set_text($title);
        Pango::Cairo::update_layout($cr,$layout);
        _anchor_pango($cr, $layout, 'nw', MARG_L + 3, MARG_T + 3 + 16*$_);
        $cr->restore;
    }

    # draw mouse coordinates
    if (defined $self->{cx}) {
        $cr->save;
        $cr->set_source_surface($self->{surf_coords},$self->{cx}+4+MARG_L,$self->{cy}-27+MARG_T);
        $cr->paint;
        $cr->restore;
    }
    
    # draw selectbox
    if (defined $self->{left_drag}) {
        my ($l,$r) = map {$_+MARG_L} @{ $self->{left_drag} };
        $cr->save;
        $cr->set_source_rgba(.3,.3,.3,.3);
        $cr->rectangle($l,MARG_T,$r - $l+1,$h - MARG_T - MARG_B);
        $cr->fill;
        $cr->restore;
    }

    # draw ruler
    if (defined $self->{ruler}->[1]
      && $self->{ruler}->[1] != $self->{ruler}->[0]) {

        my $mz_x1 = $self->{x_used}->[ $self->{ruler}->[0] ];
        my $mz_x2 = $self->{x_used}->[ $self->{ruler}->[1] ];
        my $x1 = $self->{x_pixel}->[ $self->{ruler}->[0] ]
            - $self->{data_off_p} + MARG_L;
        my $x2 = $self->{x_pixel}->[ $self->{ruler}->[1] ]
            - $self->{data_off_p} + MARG_L;
        my $y1 = $self->{y_pixel}->[ $self->{ruler}->[0] ] + MARG_T;
        my $y2 = $self->{y_pixel}->[ $self->{ruler}->[1] ] + MARG_T;
        
        my $y3 = min($y1,$y2) - 10;
        $cr->save;
        $cr->set_line_width(1);
        $cr->set_source_rgba(.3,.3,.3,.6);
        $cr->move_to($x1, $y3+4);
        $cr->line_to($x1, $y3-4);
        $cr->move_to($x1, $y3);
        $cr->line_to($x2, $y3);
        $cr->move_to($x2, $y3+4);
        $cr->line_to($x2, $y3-4);
        $cr->stroke;
        $cr->set_dash(2,2);
        $cr->move_to($x1, $y3+7);
        $cr->line_to($x1, $y1-3);
        $cr->move_to($x2, $y3+7);
        $cr->line_to($x2, $y2-3);
        $cr->stroke;

        my $d_mz = round( abs($mz_x2 - $mz_x1), 4 );
        my $layout = Pango::Cairo::create_layout($cr);
        $layout->set_alignment('center');
        my $desc = Pango::FontDescription::from_string('Sans 8');
        $layout->set_font_description($desc);
        $layout->set_text($d_mz);
        Pango::Cairo::update_layout($cr,$layout);
        my ($lx,$ly) = $layout->get_size;
        $cr->move_to(($x1+$x2)/2-$lx/2/&Pango::SCALE,$y3 - 12);
        Pango::Cairo::show_layout($cr,$layout);

        $cr->restore;

    }

    # draw peptide
    if (defined $self->{peptide}) {
        my $surf = $self->{surf_pep};
        my $pw = $surf->get_width;
        my $ph = $surf->get_height;
        $cr->save;
        $cr->rectangle($w - MARG_R - $pw - 20, MARG_T + 40, $pw, $ph);
        $cr->clip;
        $cr->set_source_surface($surf,$w - MARG_R - $pw - 20 ,MARG_T+40);
        $cr->paint;
        $cr->restore;
    }


    # draw plot border
    $cr->save;
    $cr->set_line_width(1);
    $cr->set_source_rgba( @{$label_colors[2]} );
    $cr->rectangle(MARG_L + 0.5, MARG_T + 0.5, $w - MARG_R - MARG_L, $h - MARG_T - MARG_B);
    $cr->stroke;
    $cr->restore;

    $cr->show_page;
	
	return FALSE;
}

sub INIT_INSTANCE {

	my ($self) = @_;

    $self->{data_off_p}  = 0; # origin x offset of data surface, in px
    $self->{scale_x_min} = 0; # starting coord of x scale (not always shown)
    $self->{min_x_c} = 0; # lowest x value, padded
    $self->{max_x_c} = 1; # lowest y value, padded
    $self->{tick_y_min} = 0;  
    $self->{tick_y_max} = 1;
    $self->{tick_x_space} = 1;
    $self->{tick_y_space} = 1;
    $self->{tick_x_digits} = 1;
    $self->{tick_y_digits} = 1;
    $self->{ruler} = [];
    $self->{w_surf_p} = 1;
    $self->{h_surf_p} = 1;
    $self->{w_view_p} = 10;
    $self->{h_view_p} = 10;
    $self->{xlab} = 'x';
    $self->{ylab} = 'y';
    $self->{scale_x} = 1;
    $self->{scale_y} = 1;
    $self->{hilites} = {};
    $self->{hilite_iter} = 0;
    $self->{vlines} = {};
    $self->{vline_iter} = 0;
    $self->{idx_select} = 0;
    $self->{max_label} = 10;
    $self->{min_ratio} = 0.1;
    $self->{titles} = [];
    $self->{title_colors} = [];
    $self->{font_small}
        = Pango::FontDescription::from_string('Sans 8');
    $self->{font_med}
        = Pango::FontDescription::from_string('Sans 10');

    $self->add_events('GDK_BUTTON_PRESS_MASK');
    $self->add_events('GDK_BUTTON_RELEASE_MASK');
    $self->add_events('GDK_POINTER_MOTION_MASK');
    $self->add_events('GDK_ENTER_NOTIFY_MASK');
    $self->add_events('GDK_LEAVE_NOTIFY_MASK');

    $self->set_can_focus(TRUE);

    my $alloc = $self->get_allocation;
    my $w = $alloc->{width};
    my $h = $alloc->{height};
    $self->{w_surf_p} = $w;

    # initialize surfaces
    $self->{surf_bg} =
        Cairo::ImageSurface->create('argb32',$w, $h);
    $self->{surf_yaxis} =
        Cairo::ImageSurface->create('argb32',$w, $h);
    $self->{surf_data} =
        Cairo::ImageSurface->create('argb32',$w, $h);
    $self->{surf_lbl} =
        Cairo::ImageSurface->create('argb32',$w, $h);
    $self->{surf_coords} =
        Cairo::ImageSurface->create('argb32',100,40);

    # estimate em
    my $cr_lbl  = Cairo::Context->create($self->{surf_lbl});
    my $layout = Pango::Cairo::create_layout($cr_lbl);
    $layout->set_font_description($self->{font_small});
    $layout->set_text('M');
    Pango::Cairo::update_layout($cr_lbl,$layout);
    my ($lx,$ly) = $layout->get_size;
    $self->{em} = [$lx/&Pango::SCALE, $ly/&Pango::SCALE];

    # load cursors
    my $arrow = Gtk3::Gdk::Cursor->new('left_ptr');
    my %c = (
        'ch_white'   => $icon_ch_white,
        'ch_black'   => $icon_ch_black,
        'ch_green'   => $icon_ch_green,
        'ch_red'     => $icon_ch_red,
        'ch_darkred' => $icon_ch_darkred,
    );
    $self->{cursors} = {};
    for (keys %c) {
        $self->{cursors}->{$_} = Gtk3::Gdk::Cursor->new_from_pixbuf(
            $arrow->get_display,
            do {
                my $loader = Gtk3::Gdk::PixbufLoader->new();
                $loader->write( decode_base64( $c{$_} ) );
                $loader->close;
                $loader->get_pixbuf();
            },
            8, 8);
    }
    $self->{cursors}->{drag} = Gtk3::Gdk::Cursor->new('hand2');
    $self->{cursor} = $self->{cursors}->{ch_red};
    $self->set_size_request(40 + MARG_L + MARG_R,20 + MARG_T + MARG_B);
}

sub resize {

    my ($self) = @_;

    my $offset_c;
    if (defined $self->{x}) {
        $offset_c = $self->p2x($self->{data_off_p});
    }

    my $alloc = $self->get_allocation;
    my $w = $alloc->{width};
    my $h = $alloc->{height};

    $self->{w_view_p} = $w - MARG_L - MARG_R;
    $self->{h_view_p} = $h - MARG_T - MARG_B;

    $self->{w_surf_p} = $self->{w_view_p}*$self->{scale_x};
    $self->{h_surf_p} = $self->{h_view_p}*$self->{scale_y};

    if (defined $self->{x}) {

        $self->calc_used;
        $self->calc_axes;
        $self->calc_coords;
        $self->calc_labels;

        $self->{data_off_p} = $self->x2p($offset_c);

        $self->draw();

    }

}

sub round {
    my ($val,$places) = @_;
    $places = $places // 0;
    return sprintf "%.${places}f", $val if ($places > 0);
    return (int($val*10**$places+0.5))/10**$places;
}

sub sig_fig {
    my ($val, $figs) = @_;
    return $val if ($val == int($val));

    my $dec = $figs - length(int($val));
    return round( $val, $dec );
}

sub set_type {

    my ($self, $type) = @_;
    $self->{type} = $type;
    return;

}

sub set_hard_limits {

    my ($self, $min, $max) = @_;
    $self->{hard_min} = $min;
    $self->{hard_max} = $max;

}

sub clear {

    my ($self) = @_;
    $self->{x}       = undef;
    $self->{x_pixel} = undef;
    $self->{x_used}  = undef;
    $self->{peptide} = undef;
    $self->draw();

}

sub save_to_png {

    my ($self, $fn) = @_;

    my $alloc = $self->get_allocation;
    my $w = $alloc->{width};
    my $h = $alloc->{height};

    my $surf = Cairo::ImageSurface->create('argb32', $w, $h);
    my $cr = Cairo::Context->create($surf);
    $self->expose(undef, $cr);
    $surf->write_to_png($fn);

    return;

}

# load MzML::Scan object (MS1 scan, MS2 scan, etc)
sub load_spectrum {

    my ($self, $spectrum, $add) = @_;

    my $type = defined $spectrum->param( MS_CENTROID_SPECTRUM )
        ? 'sticks'
        : 'lines';

    my $description = "Scan: " . $spectrum->id;
    $description .= " | MS:"  . $spectrum->ms_level;
    $description .= " | RT:"  . round($spectrum->rt,2) . 's';
    my $tic = $spectrum->param(MS_TOTAL_ION_CURRENT);
    my ($base,$exp) = split 'e', $tic;
    $tic = round($base,0);
    if (defined $exp) {
        $tic = round($base,1) . 'e' . $exp;
    }
    $description .= " | TIC:" . $tic if (defined $tic);
    my $subtitle = '';
    if ($spectrum->ms_level > 1) {
        my $pre = $spectrum->precursor;
        $subtitle    .= "PreScan:" . $pre->{scan_id};
        $subtitle .= " | PreMono:" . round($pre->{mono_mz},4);
        $subtitle .= " | IsoWin:" . round($pre->{iso_lower},3)
            . '-' . round($pre->{iso_upper},3);
        $subtitle .= " | z:" . $pre->{charge};
    }
    $self->{titles}->[0] = $description;
    $self->{titles}->[1] = $subtitle;
    $self->{title_colors}->[0] = BLUE;
    $self->{title_colors}->[1] = BLUE;
    $self->{xlab} = 'm/z';
    $self->{ylab} = 'intensity';
    $self->{labeled} = {};

    my $x = $spectrum->mz;
    my $y = $spectrum->int;

    $self->load_data( $x, $y, $type);
    
}

sub set_title {

    my ($self, $idx, $title, $color) = @_;
    
    $self->{titles}->[$idx] = $title;
    $self->{title_colors}->[$idx] = $color // BLUE;

}

# load MzML::IC object (ion chromatogram)
sub load_chrom {

    my ($self, $ic, $add) = @_;

    my $rt  = $ic->rt;
    my $int = $ic->int;

    $self->set_title( 0 => "RT:"  . round($rt->[0], 0)
        . '-' . round($rt->[-1], 0) );
    if (defined $ic->window()) {
        $self->set_title( 1 => " m/z:"  . sig_fig($ic->window()->[0], 5)
          . '-' . sig_fig($ic->window()->[1], 5) );
    }

    $self->{xlab} = 'retention time (s)';
    $self->{ylab} = 'ion current';

    $self->load_data( $rt, $int, 'lines' );

}

# load generic data type
sub load_data {

    my ($self, $x, $y, $type) = @_;

    $self->clear();

    $type //= 'lines';

    $self->{x} = $x;
    $self->{y} = $y;
    $self->set_type($type);

    # find data extrema
    my $min_cx = $self->{hard_min} // $self->{x}->[0];
    my $max_cx = $self->{hard_max} // $self->{x}->[-1];
    my $max_cy = max @{$self->{y}};

    my $pad_x = ($max_cx - $min_cx) * X_PAD_FRAC;

    $self->{min_x_c} = $min_cx - $pad_x;
    $self->{max_x_c} = $max_cx + $pad_x;
    $self->{min_y_c} = 0;
    $self->{max_y_c} = $max_cy * Y_PAD_FRAC;

    $self->zoom_full;
    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords;
    $self->calc_labels;

    $self->draw();
    
}

sub _on_key_press {

    my ($self, $ev) = @_;
    my $val = $ev->keyval;
    my $key = $val > 31 && $val < 127 ? chr($val)
            : $val == 65361           ? 'arrow-left'
            : $val == 65362           ? 'arrow-up'
            : $val == 65363           ? 'arrow-right'
            : $val == 65364           ? 'arrow-down'
            : '';

    if (   $key =~ /^(?: h | arrow-left )$/x  ) {
        $self->move_selection(-1);
    }
    elsif ($key =~ /^(?: l | arrow-right )$/x ) {
        $self->move_selection(1);
    }
    elsif ($key =~ /^(?: k | arrow-up )$/x    ) { }
    elsif ($key =~ /^(?: j | arrow-down )$/x  ) { }
    elsif ($key eq 'H') {
        $self->zoom_x( ZO, $self->{x}->[ $self->{idx_select} ] );
    } 
    elsif ($key eq 'L') {
        $self->zoom_x( ZI, $self->{x}->[ $self->{idx_select} ] );
    } 
    elsif ($key eq 'K') {
        $self->zoom_y( ZI );
    } 
    elsif ($key eq 'J') {
        $self->zoom_y( ZO );
    } 
    elsif ($key eq 'g') {
        if (defined $self->{num_buff}) {
            my $x = $self->{num_buff};
            my $w = ($self->{x}->[-1] - $self->{x}->[0])/$self->{scale_x};
            $self->zoom_to($x - $w/2, $x + $w/2);
        }
    } 

    # track numbers entered
    if ($key =~ /\d/) {
        $self->{num_buff} .= $key;
    }
    else {
        $self->{num_buff} = undef;
    }

    return TRUE;

}

sub move_selection {

    my ($self, $steps) = @_;

    my $to = $self->{idx_select} + $steps;
    return if ($to < 0 || $to > $#{ $self->{x} });
    $self->set_selection( $to );

}

sub set_selection {

    my ($self, $idx) = @_;

    my $val = $self->{x}->[$idx];
    $self->{idx_select} = $idx;

    $self->remove_vline( $self->{select} )
        if (defined $self->{select});
    $self->{select} = $self->add_vline(
        $val, '#0000ffaa', undef );
    
    $self->{cb_click}->($idx,$val) if (defined $self->{cb_click});

}

1;
