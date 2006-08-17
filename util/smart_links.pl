# yet another util/catalog_tests.pl.

# This script is still under development.
# Contact agentzh on #perl6 if you have a patch or some good idea for this tool.
# Currently you can use it to verify the smart link used in your script:
#   perl util/smart_links.pl --check t/some/test.t
# The HTML outputing feature will be implemented *very* soon.

use strict;
use warnings;

use YAML::Syck;
use Getopt::Long;
use File::Basename;

my ($check, $count);

my %Spec = reverse qw(
    01 Overview 02 Syntax       03 Operator     04 Block
    05 Rule     06 Subroutine   09 Structure    10 Package
    11 Module   12 Object       13 Overload     29 Functions
);

sub add_link ($$$$$$$)  {
    my ($links, $synopsis, $section, $pattern, $t_file, $from, $to) = @_;
    $links->{$synopsis} ||= {};
    $links->{$synopsis}->{$section} ||= [];
    if ($pattern and substr($pattern, -1, 1) eq '/') { $pattern = "/$pattern"; }
    push @{ $links->{$synopsis}->{$section} },
        [$pattern => [$t_file, $from, $to]];
    $count++;
}

sub error ($) {
    my ($msg) = @_;
    if ($check) {
        die "$msg\n";
    } else {
        warn "$msg\n";
    }
}

sub process_t_file ($$) {
    my ($infile, $links) = @_;
    open my $in, $infile or
        die "error: Can't open $infile for reading: $!\n";
    my ($setter, $from, $to);
    while (<$in>) {
        chomp;
        my ($synopsis, $section, $pattern);
        if (/^ \s* \#? \s* L< (S\d+) \/ ([^\/]+) >\s*$/xo) {
            ($synopsis, $section) = ($1, $2);
            $section =~ s/^\s+|\s+$//g;
            $section =~ s/^"(.*)"$/$1/;
            #warn "$synopsis $section" if $synopsis eq 'S06';
            $to = $. - 1;
        }
        elsif (/^ \s* \#? \s* L< (S\d+) \/ ([^\/]+) \/ (.*) /xo) {
            #warn "$1, $2, $3\n";
            ($synopsis, $section, $pattern) = ($1, $2, $3);
            $section =~ s/^\s+|\s+$//g;
            $section =~ s/^"(.*)"$/$1/;
            if (!$section) {
                error "$infile: line $.: section name can't be empty.";
            }
            $pattern =~ s/^\s+|\s+$//g;
            if (substr($pattern, -1, 1) ne '>') {
                $_ = <$in>;
                s/^\s+|\s+$//g;
                if (!/>$/) {
                    error "$infile: line $.: smart links must termanate " .
                        "in the second line.";
                }
                $pattern .= $_;
                $to = $. - 2;
            } else {
                $to = $. - 1;
            }
            chop $pattern;
            #warn "*$synopsis* *$section* *$pattern*\n";
        }
        elsif (/^ \s* \#? \s* L< S\d+\b /xoi) {
            error "$infile: line $.: syntax error in the magic link:\n\t$_";
        }
        else { next; }

        #warn "*$synopsis* *$section*\n";
        $setter->($from, $to) if $setter and $from;
        $setter = sub {
            add_link($links, $synopsis, $section, $pattern, $infile, $_[0], $_[1]);
        };
        $from = $. + 1;
    }
    $setter->($from, $.) if $setter and $from;
    close $in;
}

sub parse_pod ($) {
    my $infile = shift;
    open my $in, $infile or
        die "can't open $infile for reading: $!\n";
    my $podtree = {};
    my $section;
    while (<$in>) {
        if (/^ =head(\d+) \s* (.*\S) \s* $/x) {
            #warn "parse_pod: *$1*\n";
            my $num = $1,
            $section = $2;
            $podtree->{_sections} ||= [];
            push @{ $podtree->{_sections} }, [$num, $section];
        } elsif (!$section) {
            $podtree->{_header} .= $_;
        } elsif (/^\s*$/) {
            $podtree->{$section} ||= [];
            #push @{ $podtree->{$section} }, "\n";
            push @{ $podtree->{$section} }, '';
        } elsif (/^\s+(.+)/) {
            $podtree->{$section}->[-1] .= $_;
            push @{ $podtree->{$section} }, '';
        } else {
            $podtree->{$section}->[-1] .= $_;
        }
    }
    close $in;
    $podtree;
}

sub emit_pod ($) {
    my $podtree = shift;
    my $str;
    $str .= $podtree->{_header} if $podtree->{_header};
    for my $elem (@{ $podtree->{_sections} }) {
        my ($num, $sec) = @$elem;
        $str .= "=head$num $sec\n\n";
        for my $para (@{ $podtree->{$sec} }) {
            if ($para eq '') {
                $str .= "\n";
            } elsif ($para =~ /^\s+/) {
                $str .= $para;
            } else {
                $str .= "$para\n";
            }
        }
    }
    $str;
}

sub process_syn ($$$) {
    my ($infile, $out_dir, $links) = @_;
    my $syn_id;
    if ($infile =~ /\bS(\d+)\.pod$/) {
        $syn_id = $1;
    } else {
        my $base = basename($infile, '.pod');
        $syn_id = $Spec{$base};
    }
    if (!$syn_id) {
        warn "  warning: $infile skipped.\n";
        return;
    }
    my $podtree = parse_pod($infile);
    #print Dump $podtree if $syn_id eq '02';

    my $sections = $links->{"S$syn_id"};
    if (!$sections) {
        return;
    }
    for my $section (keys %$sections) {
        #warn "checking $section...";
        my @links = @{ $sections->{$section} };
        if (!$podtree->{$section}) {
            my $link = $links[0];
            my ($t_file, $from) = @{ $link->[1] };
            $from--;
            error "$t_file: line $from: ".
                "section name ``$section'' not found.";
        }
    }

    my $pod = emit_pod($podtree);
    #print $pod if $syn_id eq '02';
    #if ($syn_id eq '02') {
    #    use File::Slurp;
    #    write_file("S$syn_id.pod", $pod);
    #}
    warn "$syn_id: $infile\n";
}

MAIN: {
    my ($syn_dir, $out_dir);
    GetOptions(
        'check'   => \$check,
        'syn-dir' => \$syn_dir,
        'out-dir' => \$out_dir,
    );
    $out_dir ||= 'tmp';
    mkdir $out_dir if !-d $out_dir;

    my @t_files = map glob, @ARGV;
    mkdir 'tmp' if !-d 'tmp';
    my $links = {};
    for my $t_file (@t_files) {
        process_t_file($t_file, $links);
    }
    #print Dump($links);
    warn "  info: $count smart links found.\n";

    $syn_dir ||= 'docs/Perl6/Spec';

    if ($syn_dir eq 'docs/Perl6/Spec') {
        system "$^X $syn_dir/update";
    }
    my @syns = map glob, "$syn_dir/*.pod";
    for my $syn (@syns) {
        process_syn($syn, $out_dir, $links);
    }
    exit if $check;
}
