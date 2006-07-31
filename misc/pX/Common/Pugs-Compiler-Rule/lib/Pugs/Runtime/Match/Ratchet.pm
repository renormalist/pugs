package Pugs::Runtime::Match::Ratchet;
# Documentation in the __END__

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Class::InsideOut qw( public register id );

use overload (
    '@{}'    => \&array,
    '%{}'    => \&hash,
    'bool'   => \&bool,
    '&{}'    => \&code,
    '${}'    => \&code,
    '""'     => \&flat,
    '0+'     => \&flat,
    fallback => 1,
);

public data => my %_data;

sub new {
    my ($class, $match) = @_;
    my $obj = register( bless \(my $s), $class );
    $_data{ id $obj } = $match;
    return $obj;
}

sub from  {  ${$_data{id $_[0]}->{from}}  }
sub to    {  ${$_data{id $_[0]}->{to}}    }
sub bool  {  ${$_data{id $_[0]}->{bool}}  }
sub hash  {  $_data{id $_[0]}->{named} }
sub array {  $_data{id $_[0]}->{match} }

sub flat {
    my $cap = $_data{id $_[0]}->{capture};
    #print ref $cap;
    return $$cap
        if ref $cap eq 'REF';
    return $_[0]->str;
}

sub str {
    #print $_[0]->perl;
    return '' unless $_[0]->bool;
    return substr( ${$_data{id $_[0]}->{str}}, $_[0]->from, $_[0]->to - $_[0]->from );
}

sub perl {
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Pad = '  ';
    return __PACKAGE__ . "->new( " . Dumper( $_[0]->data ) . ")\n";
}

# tail() for backwards compatibility
# - doesn't work on failed matches
sub tail {
    return substr( ${$_data{id $_[0]}->{str}}, $_[0]->to );
}

# return the capture
sub code {
    my $c = $_[0]->flat;
    return sub { $c };
}

1;

__END__

=head1 NAME 

Pugs::Runtime::Match::Ratchet - Match object created by :ratchet rules

=head1 METHODS

* array

* hash

* str

* data

- return the internal representation

* bool

* from

* to

=head1 OVERLOADS

* $match->()

- return the capture

* $match->[$n]

- return the positional matches

* $match->{$n}

- return the named matches

* $match ? 1 : 0

- return whether there was a match

=head1 SEE ALSO

Pugs::Runtime::Match

=head1 AUTHORS

The Pugs Team E<lt>perl6-compiler@perl.orgE<gt>.

=head1 COPYRIGHT

Copyright 2006 by Flavio Soibelmann Glock and others.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut