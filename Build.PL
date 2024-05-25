use 5.012;

use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'ms2view',
    dist_version       => 0.004,
    dist_abstract      => 'ms2view is a simple mass spectrum viewer',
    license            => 'GPL_3',
    dist_author        => q{Jeremy Volkening <jdv@base2bio.com>},
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More'    => 0,
    },
    requires => {
        'Gtk2'             => 0,
        'Gtk2::SimpleList' => 0,
        'MS'               => 0,
    },
    meta_merge => {
        resources => {
            repository => 'https://github.com/jvolkening/ms2view'
        }
    },
    add_to_cleanup => [ 'ms2view-*' ],
    create_license => 1,
);
$builder->create_build_script;
