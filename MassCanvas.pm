package MassCanvas;

use warnings;
use strict;

use 5.10.1;

use Glib qw/TRUE FALSE/;
use Gtk2;
use Cairo;
use Gtk2::Pango;
use List::Util qw/min max any/;
use POSIX qw/floor ceil/;
use MIME::Base64 qw/decode_base64/;

use MS::CV qw/:constants/;

use Glib::Object::Subclass
	Gtk2::DrawingArea::,
	signals => {
		expose_event         => \&expose,
        configure_event      => \&resize,
        motion_notify_event  => \&on_motion,
        button_press_event   => \&on_click,
        button_release_event => \&on_release,
        scroll_event         => \&on_scroll,
	};

my @blue = (0, 0, 1, 1);
my @label_colors = (
    [0.0, 0.0, 0.0, 1.0],
    [1.0, 0.0, 0.0, 1.0],
    [0.0, 0.0, 1.0, 1.0],
);

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


use constant L_MARGIN => 60;
use constant R_MARGIN => 10;
use constant B_MARGIN => 40;
use constant T_MARGIN => 10;
use constant TICK_LEN => 6;

use constant ZI => 1.25;
use constant ZO => 0.80;
use constant ZMAX => 10000;


sub _clamp {

    my ($val, $lower, $upper) = @_;
    return $val < $lower ? $lower
         : $val > $upper ? $upper
         : $val;

}

sub zoom_to {

    my ($self, $l_mz, $r_mz) = @_;

    $self->{xscale} = ($self->{x}->[-1] - $self->{x}->[0])/($r_mz - $l_mz);
    $self->{xscale} = _clamp( $self->{xscale}, 1, $self->{xscale} );

    $self->{pwidth} = $self->{cwidth}*$self->{xscale};

    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords(1);

    $self->{xscale} = ($self->{x}->[-1] - $self->{x}->[0])/($r_mz - $l_mz);
    $self->{xscale} = max($self->{xscale},1);

    $self->{pwidth} = $self->{cwidth}*$self->{xscale};

    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords(1);

    $self->{p_x_offset} = $self->mz2px($l_mz);
    $self->{p_x_offset} = max(0, $self->{p_x_offset}); 

    $self->draw;

}


sub on_scroll {

    my ($self,$ev) = @_;

    my $xp = $ev->x - L_MARGIN;
    my @state = @{ $ev->state };
    my $w_bg = $self->allocation->width;
    my $sf = $ev->direction eq 'up' ? ZI : ZO;
    my $x_data = $self->px2mz($xp);
    my $axis = (@state && $state[0] eq 'control-mask') ? 'y' : 'x';

    # CTLR+scrollbutton = change y-zoom
    if ($axis eq 'y') {
        $self->{yscale} *= $sf;
        $self->{yscale} = _clamp( $self->{yscale}, 0.7, ZMAX);
    }

    # scrollbutton alone = change x-zoom
    else {
        $self->{xscale} *= $sf;
        $self->{xscale} = max($self->{xscale},1);
    }

    $self->{pwidth} = $self->{cwidth}*$self->{xscale};
    $self->{pheight} = $self->{cheight}*$self->{yscale};

    $self->calc_used if ($axis eq 'x');
    $self->calc_axes;
    $self->calc_coords($axis eq 'x');
    
    # center on pointer
    my $new_x_pixel = int($self->mz2px($x_data)) - $self->{p_x_offset};
    $self->{p_x_offset} += $new_x_pixel - $xp;
    $self->{p_x_offset} = max(0, $self->{p_x_offset}); 

    $self->draw;
}

sub calc_coords {

    my ($self, $do_x) = @_;
    $do_x = $do_x // 1;

    # store peak pixel coords
    my @y_pixel;
    for (0..$#{ $self->{y_used} }) {
        my $int = $self->{y_used}->[$_];
        my $y_actual = $self->int2px( $int );
        push @y_pixel, $y_actual;
    }
    $self->{y_pixel} = [@y_pixel];
    my $max = $self->{y_max};
    my $min = $self->{y_min};
    my $pw = $self->{cheight} / ($max - $min);
    $self->{yplaces} = ceil( log_n($pw, 10) );

    if ($do_x) {
        my @x_pixel;
        for (0..$#{ $self->{x_used} }) {
            my $mz  = $self->{x_used}->[$_];
            my $x_actual = $self->mz2px( $mz );
            push @x_pixel, $x_actual;
        }
        $self->{x_pixel} = [@x_pixel];
        # calculate sig figs to display
        my $min = $self->{x_minp};
        my $max = $self->{x_maxp};
        my $pw = ($self->{pwidth}) / ($max - $min);
        $self->{xplaces} = ceil( log_n($pw, 10) );
    }

}   

sub calc_used {

    my ($self) = @_;

    #$self->{x_used} = $self->{x};
    #$self->{y_used} = $self->{y};
    #return;

    my @x_used;
    my @y_used;
    my $curr_mz  = $self->{x}->[0];
    my $curr_int = $self->{y}->[0];
    my $curr_idx = 0;
    my $curr_x = $self->mz2px( $curr_mz );
    my $curr_y = $self->int2px( $curr_int );
    my $last_int;
    my $last_mz;
    my $last_idx = 0;
    for (1..$#{ $self->{x} }) {
        my $mz  = $self->{x}->[$_];
        my $int = $self->{y}->[$_];
        my $x_actual = $self->mz2px( $mz );
        my $y_actual = $self->int2px( $int );

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

sub label {

    my ($self, @labels) = @_;
    for (@labels) {
        if (defined $self->{labeled}->{$_->[0]}->[1]) {
            warn "replacing $self->{labeled}->{$_->[0]}->[1]->[0] with $_->[1]\n";
        }
        $self->{labeled}->{$_->[0]}->[1]
            = [$_->[1],$_->[2]];
    }
    $self->draw();

}

sub _anchor_pango {

    my ($cr, $layout, $dir, $x, $y) = @_;

    my ($lx,$ly) = $layout->get_size;
    my $x_actual = $x - $lx/PANGO_SCALE/2;;
    my $y_actual = $y - $ly/PANGO_SCALE/2;;

    for ($dir) {
        if(/s/) {
            $y_actual = $y - $ly/PANGO_SCALE;
        }
        if(/n/) {
            $y_actual = $y;
        }
        if(/e/) {
            $x_actual = $x - $lx/PANGO_SCALE;
        }
        if(/w/) {
        #when(/^w$/) {
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

    my $x_ticks = $self->{pwidth}  / 50;
    my $y_ticks = $self->{pheight} / 14;
    $x_ticks = $x_ticks > 2 ? $x_ticks : 2;
    $y_ticks = $y_ticks > 2 ? $y_ticks : 2;

    # recalculate axes
    if (defined $self->{x}) {
        my $min_x = $self->{win_min} // $self->{x}->[0];
        my $max_x = $self->{win_max} // $self->{x}->[-1];
        my $min_y = 0;
        my $max_y = max(@{ $self->{y} })*1.2;
        my ($min,$max,$space,$digits) = (0,1,1,1);
        ($min,$max,$space,$digits) = calc_ticks($min_y,$max_y,$y_ticks, 10)
            if ($max_y > $min_y);
        $self->{y_min} = $min;
        $self->{y_max} = $max;
        $self->{y_space} = $space;
        $self->{y_digits} = $digits;
        ($min,$max,$space,$digits) = calc_ticks($min_x,$max_x,$x_ticks, 10);
        $self->{x_min} = $min;
        $self->{x_max} = $max;
        my $span = $max_x - $min_x;
        $self->{x_minp} = floor($min_x - $span*.05);
        $self->{x_maxp} = ceil($max_x + $span*.05);
        $self->{x_space} = $space;
        $self->{x_digits} = $digits;

        #draw y-axis
        my $h = $self->{cheight} + T_MARGIN + B_MARGIN;
        $self->{surf_yaxis} = Cairo::ImageSurface->create(
            'argb32', L_MARGIN,  $h);
        my $cr = Cairo::Context->create($self->{surf_yaxis});
        $cr->save;
        $cr->set_line_width(1);
        $cr->set_source_rgba(0.0,0.0,1.0,1.0);
        my $pw = $self->{pheight} / $self->{y_max};

        my $layout = Pango::Cairo::create_layout($cr);
        $layout->set_alignment('right');
        $layout->set_font_description($self->{font_small});

        my $y = $self->{y_min};
        my $bot;
        my $top;
        while ($y <= $self->{y_max}) {
            my $y_actual = int(T_MARGIN + $self->{cheight} - $y*$pw) + 0.5;
            $bot = $y_actual if ($y == $self->{y_min});
            last if ($y_actual < T_MARGIN);
            $top = $y_actual;
            $cr->move_to(L_MARGIN,$y_actual);
            $cr->line_to(L_MARGIN - TICK_LEN, $y_actual);

            my $text = sprintf "%.1e",$y;
            $layout->set_text($text);
            Pango::Cairo::update_layout($cr,$layout);
            _anchor_pango($cr, $layout, 'e', L_MARGIN - TICK_LEN - 2, $y_actual);

            $y += $self->{y_space};
        }
        $cr->stroke;

        $layout->set_text($self->{ylab});
        Pango::Cairo::update_layout($cr,$layout);
        $cr->rotate(-90*3.14159/180);
        _anchor_pango($cr, $layout, 's',
            $h - B_MARGIN - $self->{cheight}/2, L_MARGIN);
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

sub index_at {

    my ($self, $xc) = @_;

    $xc += $self->{p_x_offset};
    my $i = $self->find_nearest($xc);

    return $self->{xmap}->{$i};

}

sub closest_point {

    my ($self, $xc, $yc) = @_;

    $xc += $self->{p_x_offset};

    #calculate view window
    my $best_i;
    my $best_d;

    my $i = $self->find_nearest($self->{p_x_offset}) - 1;
    $i = 0 if ($i < 0);
    for ($i..$#{$self->{x_pixel}}) {
        my $xp = $self->{x_pixel}->[$_];
        my $yp = $self->{y_pixel}->[$_];
        my $dist = _euclidean( [$xc,$yc],[$xp,$yp] );
        if (! defined $best_d || $dist < $best_d) {
            $best_d = $dist;
            $best_i = $_;
        }
        last if ($xp > $self->{p_x_offset} + $self->{cwidth});
    }
    return $best_i;

}

sub on_click {

    my ($self,$ev) = @_;
    my ($px,$py) = ($ev->x - L_MARGIN, $ev->y - T_MARGIN);
    my @state = @{ $ev->state };

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
            $self->{select} = $px;
            my $i = $self->index_at($px);
            my $this = $self->{x}->[$i];
            $self->{idx_select} = $i;
            $self->{cb_click}->($i,$this);
        }

    }
    elsif ($ev->button == 3) { #right button for dragging
        $self->window->set_cursor( $self->{cursors}->{drag} );
        $self->{cursor} = $self->{cursors}->{drag};
        $self->{right_drag} = TRUE;
    }

}

sub on_release {

    my ($self,$ev) = @_;
    my $px = $ev->x - L_MARGIN;

    if ($ev->button == 1) { #left button for dragging
        if (defined $self->{left_drag}) {
            my $min_y;
            my $max_i;
            my $l = $self->{left_drag}->[0] - 1 + $self->{p_x_offset};
            my $r = $self->{left_drag}->[1] + 1 + $self->{p_x_offset};
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
        $self->window->set_cursor( $self->{cursor} );
        $self->{right_drag} = FALSE;
    }
    $self->{last_x} = undef;

}

sub px2mz {

    my ($self,$px) = @_;
    my $mw = ($self->{x_maxp} - $self->{x_minp}) / $self->{pwidth};
    return ($px + $self->{p_x_offset}) * $mw + $self->{x_minp};

}

sub mz2px {
    
    my ($self,$mz) = @_;
    my $pw = $self->{pwidth} / ($self->{x_maxp} - $self->{x_minp});
    #return floor(($mz - $self->{x_minp})*$pw) + 0.5;
    return round(($mz - $self->{x_minp})*$pw,0) + 0.5;

}

sub int2px {

    my ($self,$int) = @_;
    my $pw = $self->{pheight} / $self->{y_max};
    return floor($self->{cheight} - $int*$pw) + 0.5;

}

sub px2int {

    my ($self,$py) = @_;
    my $mw = $self->{y_max} / $self->{pheight};
    return ($self->{cheight} - $py) * $mw;

}

sub on_motion {

    my ($self, $ev) = @_;
    my ($xp, $yp) = ($ev->x - L_MARGIN, $ev->y - T_MARGIN);

    my $ha = $self->allocation()->height;
    my $wa = $self->allocation()->width;

    # check if we are entering or leaving plot area
    if ( $xp < 0
      || $xp > $self->{cwidth}
      || $yp < 0
      || $yp > $self->{cheight}
    ) {
        $self->window->set_cursor($self->{old_cursor})
            if ($self->{inside});
        $self->{inside} = 0; 
    }
    else {
        if (! $self->{inside}) {
            $self->{old_cursor} = $self->window->get_cursor;
            $self->window->set_cursor($self->{cursor})
        }
        $self->{inside} = 1;
    }

    # calculate coordinates to display
    my $x_data;
    my $y_data;
    if ($self->{inside}) {
        $x_data = $self->px2mz($xp);
        $x_data = round($x_data,$self->{xplaces});
        $y_data = $self->px2int($yp);
        $y_data = sprintf("%.1e", $y_data);
        #$y_data = round($y_data,$self->{yplaces});

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
        my $desc = Pango::FontDescription->from_string('Sans 8');
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
                $self->{p_x_offset} += $self->{last_x} - $xp;
                my $max = $self->{pwidth} - ($self->{cwidth});
                $self->{p_x_offset} = $max if ($self->{p_x_offset} > $max);
                $self->{p_x_offset} = 0 if ($self->{p_x_offset} < 0);
            
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

    my ($start,$end,$n_ticks,$base) = @_;
    $base = $base // 10;
    my $range = nice_num($end - $start, 0, $base);
    my $space = nice_num($range/($n_ticks-1),1, $base);
    my $min = floor($start/$space)*$space;
    my $max = ceil($end/$space)*$space;
    my $digits = max( -floor(log_n($space,$base)),0);
    return ($min,$max,$space,$digits);

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

    my ($self,$xp) = @_;

    my $lower = 0;
    my $upper = $#{$self->{x_pixel}};
    my $mid;
    while ($lower != $upper) {
        $mid = int( ($lower+$upper)/2 );
        return $mid if ($xp == $self->{x_pixel}->[$mid]);
        if ($xp < $self->{x_pixel}->[$mid]) {
            $upper = $mid;
        }
        else {
            $lower = $mid + 1;
        }
    }
    return $mid;

}

sub draw {

	my $self = shift;
    my $alloc = $self->allocation;
    my $w_bg = $alloc->width;
    my $h_bg = $alloc->height;

    $self->{surf_lbl} =
        Cairo::ImageSurface->create('argb32', $self->{cwidth},  $self->{cheight}+30);
    $self->{surf_data} =
        Cairo::ImageSurface->create('argb32', $self->{cwidth}, $self->{cheight}+30);
    $self->{surf_bg} =
        Cairo::ImageSurface->create('argb32',$w_bg, $h_bg);
	my $cr_lbl  = Cairo::Context->create($self->{surf_lbl});
	my $cr_data = Cairo::Context->create($self->{surf_data});
	my $cr_bg   = Cairo::Context->create($self->{surf_bg});

    #calculate view window

    if (defined $self->{x_pixel}) { 

        #my @xs = @{ $self->{x_pixel} };
        #my @ys = @{ $self->{y_pixel} };
        my $xref = $self->{x_pixel};
        my $yref = $self->{y_pixel};

        # draw x label
        $cr_bg->save;
        $cr_bg->set_source_rgba(0.0,0.0,1.0,1.0);
        my $layout = Pango::Cairo::create_layout($cr_bg);
        $layout->set_font_description($self->{font_small});
        $layout->set_text($self->{xlab});
        Pango::Cairo::update_layout($cr_bg,$layout);
        _anchor_pango($cr_bg, $layout, 'n', $self->{cwidth}/2 + L_MARGIN,
            $self->{cheight} + T_MARGIN + 20);
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
            my $l_px = $self->mz2px($l_mz) - $self->{p_x_offset};
            my $r_px = $self->mz2px($r_mz) - $self->{p_x_offset};
            $cr_data->save;
            $cr_data->set_source_rgba(@rgba);
            $cr_data->rectangle($l_px,0,$r_px - $l_px+1,$self->{cheight});
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
            my $px = $self->mz2px($mz) - $self->{p_x_offset};
            $cr_data->save;
            $cr_data->set_source_rgba(@rgba);
            $cr_data->move_to($px,0);
            $cr_data->line_to($px,$self->{cheight});
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
        my $pw = $self->{pwidth}
            / ($self->{x_maxp} - $self->{x_minp});

        # find starting x
        my $mz = $self->{x_minp} + ceil( ($self->px2mz(0)
            - $self->{x_minp})/$self->{x_space})*$self->{x_space};

        $layout = Pango::Cairo::create_layout($cr_data);
        $layout->set_font_description($self->{font_small});
        while ($mz <= $self->{x_maxp}) {
            my $xp = $self->mz2px( $mz ) - $self->{p_x_offset};
            last if ($xp > $self->{cwidth});
            #$layout->set_text( sprintf "%.$self->{x_digits}f", $mz );
            $layout->set_text( $mz );
            $mz += $self->{x_space};
            my ($lw,$lh) = $layout->get_pixel_size;
            next if ($xp - $lw/2 < 0);
            last if ($xp + $lw/2 > $self->{cwidth});

            $cr_data->move_to($xp,$self->{cheight});
            $cr_data->line_to($xp,$self->{cheight} + TICK_LEN);

            Pango::Cairo::update_layout($cr_data,$layout);
            _anchor_pango($cr_data, $layout, 'n',
                $xp, $self->{cheight} + TICK_LEN + 2);

            #$mz += $self->{x_space};
        }
        $cr_data->stroke;
        $cr_data->restore;

        # finally, plot data
        $cr_data->save;
        $cr_data->set_source_rgba(0.0, 0.0, 0.0, 1.0);
        $cr_data->set_line_width(1);

        my $last_point;

        my $left = $self->{p_x_offset};

        #semi-binary search
        my $i = $self->find_nearest($left) - 1;
        $i = 0 if ($i < 0);
        
        #for ($start_i..$end_i) {
        while ($i <= $#{$xref}) {
            my $xp = $xref->[$i] - $self->{p_x_offset};
            my $yp = $yref->[$i];
            if ($self->{type} eq 'sticks') {
                $cr_data->move_to($xp, $self->{cheight});
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
            last if ($xp > $self->{cwidth});
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
                    $cr_lbl->move_to($x-$lx/2/PANGO_SCALE,$y - $ly/PANGO_SCALE - 2);
                    $y -= $ly/PANGO_SCALE + 1;
                    Pango::Cairo::layout_path($cr_lbl,$layout);
                    $cr_lbl->set_line_width(3);
                    $cr_lbl->set_source_rgba(1.0, 1.0, 1.0, 1.0);
                    $cr_lbl->stroke_preserve;
                    #$cr_lbl->set_source_rgba(0.0, 0.0, 0.0, 1.0);
                    $cr_lbl->set_source_rgba(@{ $label_colors[$lab->[1]] });
                    $cr_lbl->fill;
                    $cr_lbl->restore;
                }
            }
            ++$i;
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

	my ($self, $event) = @_;

	my $cr = Gtk2::Gdk::Cairo::Context->create($self->window);
    my $alloc = $self->allocation;
    my $w = $alloc->width;
    my $h = $alloc->height;

    # draw white background
    $cr->save;
    $cr->rectangle(0,0,$w,$h);
    $cr->set_source_rgba(1,1,1,1);
    $cr->fill;
    $cr->set_line_width(1);
    $cr->rectangle(0.5,0.5,$w-1,$h-1);
    $cr->set_source_rgba(0,0,0,1);
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
    $cr->rectangle(L_MARGIN, T_MARGIN, $w - R_MARGIN - L_MARGIN, $h - B_MARGIN - T_MARGIN + 30);
    $cr->clip;
    $cr->set_source_surface($self->{surf_data},L_MARGIN ,T_MARGIN);
    $cr->paint;
    $cr->restore;

    # draw data labels
    $cr->save;
    $cr->rectangle(L_MARGIN, T_MARGIN, $w - R_MARGIN - L_MARGIN, $h - B_MARGIN - T_MARGIN + 30);
    $cr->clip;
    $cr->set_source_surface($self->{surf_lbl},L_MARGIN ,T_MARGIN);
    $cr->paint;
    $cr->restore;

    # draw header
    if (defined $self->{title}) {
        $cr->save;
        $cr->rectangle(L_MARGIN, T_MARGIN, $w - R_MARGIN - L_MARGIN, $h - B_MARGIN - T_MARGIN + 30);
        $cr->clip;
        $cr->set_source_rgba(@{$label_colors[2]});
        my $layout = Pango::Cairo::create_layout($cr);
        $layout->set_font_description($self->{font_small});
        $layout->set_text($self->{title});
        Pango::Cairo::update_layout($cr,$layout);
        _anchor_pango($cr, $layout, 'nw', L_MARGIN + 3, T_MARGIN + 3);
        $cr->restore;
    }
    if (defined $self->{subtitle}) {
        $cr->save;
        $cr->rectangle(L_MARGIN, T_MARGIN, $w - R_MARGIN - L_MARGIN, $h - B_MARGIN - T_MARGIN + 30);
        $cr->clip;
        $cr->set_source_rgba(@{$label_colors[1]});
        my $layout = Pango::Cairo::create_layout($cr);
        $layout->set_font_description($self->{font_small});
        $layout->set_text($self->{subtitle});
        Pango::Cairo::update_layout($cr,$layout);
        _anchor_pango($cr, $layout, 'nw', L_MARGIN + 3, T_MARGIN + 16);
        $cr->restore;
    }


    # draw mouse coordinates
    if (defined $self->{cx}) {
        $cr->save;
        $cr->set_source_surface($self->{surf_coords},$self->{cx}+4+L_MARGIN,$self->{cy}-27+T_MARGIN);
        $cr->paint;
        $cr->restore;
    }
    
    # draw selectbox
    if (defined $self->{left_drag}) {
        my ($l,$r) = map {$_+L_MARGIN} @{ $self->{left_drag} };
        $cr->save;
        $cr->set_source_rgba(.3,.3,.3,.3);
        $cr->rectangle($l,T_MARGIN,$r - $l+1,$h - T_MARGIN - B_MARGIN);
        $cr->fill;
        $cr->restore;
    }

    # draw ruler
    if (defined $self->{ruler}->[1]
      && $self->{ruler}->[1] != $self->{ruler}->[0]) {

        my $mz_x1 = $self->{x_used}->[ $self->{ruler}->[0] ];
        my $mz_x2 = $self->{x_used}->[ $self->{ruler}->[1] ];
        my $x1 = $self->{x_pixel}->[ $self->{ruler}->[0] ]
            - $self->{p_x_offset} + L_MARGIN;
        my $x2 = $self->{x_pixel}->[ $self->{ruler}->[1] ]
            - $self->{p_x_offset} + L_MARGIN;
        my $y1 = $self->{y_pixel}->[ $self->{ruler}->[0] ] + T_MARGIN;
        my $y2 = $self->{y_pixel}->[ $self->{ruler}->[1] ] + T_MARGIN;
        
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
        my $desc = Pango::FontDescription->from_string('Sans 8');
        $layout->set_font_description($desc);
        $layout->set_text($d_mz);
        Pango::Cairo::update_layout($cr,$layout);
        my ($lx,$ly) = $layout->get_size;
        $cr->move_to(($x1+$x2)/2-$lx/2/PANGO_SCALE,$y3 - 12);
        Pango::Cairo::show_layout($cr,$layout);

        $cr->restore;

    }

    # draw plot border
    $cr->save;
    $cr->set_line_width(1);
    $cr->set_source_rgba( @blue );
    $cr->rectangle(L_MARGIN + 0.5, T_MARGIN + 0.5, $w - R_MARGIN - L_MARGIN, $h - T_MARGIN - B_MARGIN);
    $cr->stroke;
    $cr->restore;

    $cr->show_page;
	
	return FALSE;
}

sub INIT_INSTANCE {

	my ($self) = @_;

    $self->{p_x_offset} = 0;
    $self->{x_min} = 0;
    $self->{x_max} = 1;
    $self->{x_minp} = 0;
    $self->{x_maxp} = 1;
    $self->{y_min} = 0;
    $self->{y_max} = 1;
    $self->{x_space} = 1;
    $self->{y_space} = 1;
    $self->{x_digits} = 1;
    $self->{y_digits} = 1;
    $self->{ruler} = [];
    $self->{pwidth} = 1;
    $self->{pheight} = 1;
    $self->{cwidth} = 10;
    $self->{cheight} = 10;
    $self->{xlab} = 'x';
    $self->{ylab} = 'y';
    $self->{xscale} = 1;
    $self->{yscale} = 1;
    $self->{hilites} = {};
    $self->{hilite_iter} = 0;
    $self->{vlines} = {};
    $self->{vline_iter} = 0;
    $self->{font_small}
        = Pango::FontDescription->from_string('Sans 8');

    $self->add_events('GDK_BUTTON_PRESS_MASK');
    $self->add_events('GDK_BUTTON_RELEASE_MASK');
    $self->add_events('GDK_POINTER_MOTION_MASK');
    $self->add_events('GDK_ENTER_NOTIFY_MASK');
    $self->add_events('GDK_LEAVE_NOTIFY_MASK');

    my $alloc = $self->allocation;
    my $w = $alloc->width;
    my $h = $alloc->height;
    $self->{pwidth} = $w;

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

    # load cursors
    my $arrow = Gtk2::Gdk::Cursor->new('left_ptr');
    my %c = (
        'ch_white'   => $icon_ch_white,
        'ch_black'   => $icon_ch_black,
        'ch_green'   => $icon_ch_green,
        'ch_red'     => $icon_ch_red,
        'ch_darkred' => $icon_ch_darkred,
    );
    $self->{cursors} = {};
    for (keys %c) {
        $self->{cursors}->{$_} = Gtk2::Gdk::Cursor->new_from_pixbuf(
            $arrow->get_display,
            do {
                my $loader = Gtk2::Gdk::PixbufLoader->new();
                $loader->write( decode_base64( $c{$_} ) );
                $loader->close;
                $loader->get_pixbuf();
            },
            8, 8);
    }
    $self->{cursors}->{drag} = Gtk2::Gdk::Cursor->new('hand2');
    $self->{cursor} = $self->{cursors}->{ch_red};
    $self->set_size_request(40 + L_MARGIN + R_MARGIN,20 + T_MARGIN + B_MARGIN);
}

sub resize {

    my ($self) = @_;

    my $offset;
    if (defined $self->{x}) {
        $offset = $self->px2mz(0);
    }

    my $alloc = $self->allocation;
    my $w = $alloc->width;
    my $h = $alloc->height;

    my $new_cwidth  = $w - L_MARGIN - R_MARGIN;
    my $new_cheight = $h - T_MARGIN - B_MARGIN;
    
    $self->{cwidth} = $new_cwidth;
    $self->{cheight} = $new_cheight;

    $self->{pwidth} = $self->{cwidth}*$self->{xscale};
    $self->{pheight} = $self->{cheight}*$self->{yscale};

    if (defined $self->{x}) {

        $self->calc_used;
        $self->calc_axes;
        $self->calc_coords;

        $self->{p_x_offset} = $self->mz2px($offset) - 0.5;

        $self->draw();

    }

}

sub round {
    my ($val,$places) = @_;
    $places = $places // 0;
    return sprintf "%.${places}f", $val if ($places > 0);
    return (int($val*10**$places+0.5))/10**$places;
}

# load MzML::Scan object (MS1 scan, MS2 scan, etc)

sub load_spectrum {

    my ($self,$spectrum) = @_;

    $self->{xscale} = 1;
    $self->{yscale} = 1;
    $self->{pwidth} = $self->{cwidth}*$self->{xscale};
    $self->{pheight} = $self->{cheight}*$self->{yscale};
    $self->{p_x_offset} = 0;

    if (! defined $spectrum) { # blank canvas
        $self->{x_pixel} = undef;
        $self->{title} = undef;
        $self->{x} = undef;
        $self->{y} = undef;
        $self->draw();
        return;
    }
    $self->{x} = $spectrum->mz;
    $self->{y} = $spectrum->int;
    $self->{type} = defined $spectrum->{cvParam}->{&CENTROID_SPECTRUM} ? 'sticks' : 'lines';

    my $description = "Scan: " . $spectrum->id;
    $description .= " | MS:"  . $spectrum->ms_level;
    $description .= " | RT:"  . round($spectrum->rt,2) . 's';
    my $tic = $spectrum->{cvParam}->{&TOTAL_ION_CURRENT}->[0]->{value};
    my ($base,$exp) = split 'e', $tic;
    $tic = round($base,0);
    if (defined $exp) {
        $tic = round($base,1) . 'e' . $exp;
    }
    $description .= " | TIC:" . $tic if (defined $tic);
    if ($spectrum->ms_level > 1) {
        my $pre = $spectrum->precursor;
        $description .= " | PreScan:" . $pre->{scan_id};
        $description .= " | PreMono:" . round($pre->{mono_mz},4);
        $description .= " | IsoWin:" . round($pre->{iso_lower},3)
            . '-' . round($pre->{iso_upper},3);
    }
    $self->{title} = $description;
    $self->{subtitle} = '';
    $self->{xlab} = 'm/z';
    $self->{ylab} = 'intensity';
    $self->{labeled} = {};

    my $lower = $spectrum->{scanList}->{scan}->[0]->{scanWindowList}->{scanWindow}->[0]->{cvParam}->{&SCAN_WINDOW_LOWER_LIMIT()}->[0]->{value};

    my $upper = $spectrum->{scanList}->{scan}->[0]->{scanWindowList}->{scanWindow}->[0]->{cvParam}->{&SCAN_WINDOW_UPPER_LIMIT()}->[0]->{value};

    $self->{win_min} = $lower;
    $self->{win_max} = $upper;
    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords;

    $self->draw();
    
}

# load MzML::IC object (ion chromatogram)
sub load_chrom {

    my ($self,$ic) = @_;

    $self->{xscale} = 1;
    $self->{yscale} = 1;
    $self->{pwidth} = $self->{cwidth}*$self->{xscale};
    $self->{pheight} = $self->{cheight}*$self->{yscale};
    $self->{p_x_offset} = 0;

    if (! defined $ic) { # blank canvas
        $self->{x_pixel} = undef;
        $self->{x} = undef;
        $self->{y} = undef;
        $self->draw;
        return;
    }
    $self->{x} = $ic->rt;
    $self->{y} = $ic->int;
        
    $self->{type} = 'lines';

    if (defined $ic->{window}) {
        my $description = " m/z:"  . round($ic->{window}->[0],3)
            . '-' . round($ic->{window}->[1],3);
        $description .= " | RT:"  . round($self->{x}->[0],2)
            . '-' . round($self->{x}->[-1],2);
        $self->{title} = $description;
    }

    $self->{xlab} = 'retention time (s)';
    $self->{ylab} = 'ion current';
    
    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords;

    $self->draw();

}

# load generic data type
sub load_data {

    my ($self,$x,$y) = @_;
    $self->{x} = $x;
    $self->{y} = $y;
    $self->{type} = 'lines';

    $self->calc_used;
    $self->calc_axes;
    $self->calc_coords;

    $self->draw();
    
}


1;
