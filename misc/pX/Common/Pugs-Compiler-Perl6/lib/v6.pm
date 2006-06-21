package v6;

# invokes the Perl6-to-Perl5 compiler and creates a .pmc file

use strict;
use warnings;
use Module::Compile-base;
use File::Basename;

my $bin;
BEGIN { $bin = ((dirname(__FILE__) || '.') . "/..") };
use lib (
    "$bin/lib",
    "$bin/../Pugs-Compiler-Rule/lib",
);

sub pmc_can_output { 1 }

sub pmc_compile {
    my ($class, $source) = @_;

    my $file = (caller(4))[1];
    if ($file !~ /\.pm$/i) {
        # Do the freshness check ourselves
        my $pmc = $file.'c';
        my $pmc_is_uptodate = (-s $pmc and (-M $pmc <= -M $file));
        if ($pmc_is_uptodate) {
            local $@; do $pmc; die $@ if $@; exit 0;
        }
    }

    require Pugs::Compiler::Perl6;
    my $p6 = Pugs::Compiler::Perl6->compile( $source );

    $p6->{perl5} =~ s/do\{(.*)\}/$1/s;
    return $p6->{perl5}."\n";
}

1;