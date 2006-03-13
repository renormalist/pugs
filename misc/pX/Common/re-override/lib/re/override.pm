package re::override;

use 5.005;
use strict;
use vars qw( @ISA @EXPORT $VERSION );

BEGIN {
    $VERSION = '0.03';

    local $@;
    eval {
        require XSLoader;
        XSLoader::load(__PACKAGE__ => $VERSION);
        1;
    } or do {
        require DynaLoader;
        push @ISA, 'DynaLoader';
        __PACKAGE__->bootstrap($VERSION);
    };
}

our $inserted = 0;
BEGIN { our $regcompp = undef };

sub import {
    my $class = shift;
    my $flavor = shift;
    $flavor =~ s/\W//g;

    die "Usage: use re::override-flavor" unless $flavor;

    unless ($inserted++) {
        regexp_exechook_insert();
        regexp_hook_on();
    }

    no strict 'refs';
    require "re/override/$flavor.pm";
    goto &{"re::override::${flavor}::import"};
}

sub unimport {
    regexp_hook_off();
}

sub make_qr_regexp_pair {
  my($pat,$nparens,$callback)=@_;
  die "bug - no nparens" if !defined($nparens);
  die "bug - no callback" if !defined($callback);
  my $r_address;
  $^H{regcompp} = sub {
    $r_address = $_[0];
    return reverse(13,$pat,$nparens,$callback);
  };
  my $qr = eval 'qr//'; die $@ if $@;
  return ($qr,$r_address);
}

1;

__END__

=head1 NAME 

re::override - Override Perl regular expressions

=head1 VERSION

This document describes version 0.03 of re::override, released
March 12, 2006.

=head1 SYNOPSIS

    use re::override-PCRE;

    if ("Hello, world" =~ /(?<=Hello|Hi), (world)/) {
        print "Greetings, $1!";
    }

    no re::override;
    # back to normal regexes

=head1 DESCRIPTION

This module provides a Perl interface for pluggable regular expression
engines.  It affects all regular expressions I<defined> within its scope;
when those regular expresisons are used, an alternate engine is invoked.

Currently, only the I<PCRE> flavor is supported.

=head1 CAVEATS

This is an experimental, pre-alpha development snapshot.  There are currently
no support for match flags; regexes constructed with this module may cause
segfaults on C<split>, substitution, and/or other uses.

It is currently unsuitable for just about any use other than Pugs development.

An user-supplied regular expression may lead to execution of arbitrary code;
each alternate engine may introduce additional security or memory problems.

Tainting information is discarded.

=head1 BUGS

Numerous.

=head1 AUTHORS

Audrey Tang

=head1 COPYRIGHT

Copyright 2006 by Audrey Tang E<lt>autrijus@autrijus.orgE<gt>.

The F<libpcre> code bundled with this library by I<Philip Hazel>,
under a BSD-style license.  See the F<LICENCE> file for details.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut