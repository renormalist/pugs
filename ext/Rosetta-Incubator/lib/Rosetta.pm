#!/usr/bin/pugs
use v6;

# External packages used by packages in this file, that don't export symbols:
use Locale::KeyedText-(1.71.0...);
use SQL::Routine-(0.710.0...);

###########################################################################
###########################################################################

# Constant values used by packages in this file:
# (None Yet)

###########################################################################
###########################################################################

package Rosetta-0.490.0 {
    # Note: This given version applies to all of this file's packages.
} # package Rosetta

###########################################################################
###########################################################################

class Rosetta::Interface {

    # External packages used by the Rosetta::Interface class, that do export symbols:
    # (None Yet)

    # Attributes of every Rosetta::Interface object:
    # (None Yet)

###########################################################################



###########################################################################

} # class Rosetta::Interface

###########################################################################
###########################################################################

class Rosetta::Interface::fubar {

    # External packages used by the Rosetta::Interface::fubar class, that do export symbols:
    # (None Yet)

    # Attributes of every Rosetta::Interface::fubar object:
    # (None Yet)

###########################################################################



###########################################################################

} # class Rosetta::Interface::fubar

###########################################################################
###########################################################################

class Rosetta::Engine {

    # External packages used by the Rosetta::Engine class, that do export symbols:
    # (None Yet)

    # Attributes of every Rosetta::Engine object:
    # (None Yet)

###########################################################################



###########################################################################

} # class Rosetta::Engine

###########################################################################
###########################################################################

=pod

=head1 NAME

Rosetta -
Rigorous database portability

=head1 VERSION

This document describes Rosetta version 0.490.0.

It also describes the same-number versions of Rosetta::Interface
("Interface"), Rosetta::Interface::fubar ("fubar"), and Rosetta::Engine
("Engine").

I<Note that the "Rosetta" package serves only as the name-sake
representative for this whole file, which can be referenced as a unit by
documentation or 'use' statements or Perl archive indexes.  Aside from
'use' statements, you should never refer directly to "Rosetta" in your
code; instead refer to other above-named packages in this file.>

=head1 SYNOPSIS

I<This documentation is pending.>

=head1 DESCRIPTION

I<This documentation is pending.>

=head1 INTERFACE

The interface of Rosetta is entirely object-oriented; you use it by
creating objects from its member classes, usually invoking C<new()> on the
appropriate class name, and then invoking methods on those objects.  All of
their attributes are private, so you must use accessor methods.  Rosetta
does not declare any subroutines or export such.

The usual way that Rosetta indicates a failure is to throw an exception;
most often this is due to invalid input.  If an invoked routine simply
returns, you can assume that it has succeeded, even if the return value is
undefined.

=head2 The Rosetta::Interface Class

I<This documentation is pending.>

=head2 The Rosetta::Interface::fubar Class

I<This documentation is pending.>

=head2 The Rosetta::Engine Class

I<This documentation is pending.>

=head1 DIAGNOSTICS

I<This documentation is pending.>

=head1 CONFIGURATION AND ENVIRONMENT

I<This documentation is pending.>

=head1 DEPENDENCIES

This file requires any version of Perl 6.x.y that is at least 6.0.0.

It also requires these Perl 6 classes that are on CPAN:
L<Locale::KeyedText-(1.71.0...)|Locale::KeyedText> (for error messages),
L<SQL::Routine-(0.710.0...)|SQL::Routine>.

=head1 INCOMPATIBILITIES

None reported.

=head1 SEE ALSO

The Perl 6 module L<Rosetta::Validator> is bundled with Rosetta and can be
used to test Rosetta Engine classes.

These Perl 6 packages implement Rosetta Engine classes:
L<Rosetta::Engine::Native>, L<Rosetta::Engine::Generic>.

These Perl 6 packages are the initial main dependents of Rosetta:
L<Rosetta::Emulator::DBI>.

=head1 BUGS AND LIMITATIONS

I<This documentation is pending.>

=head1 AUTHOR

Darren R. Duncan (C<perl@DarrenDuncan.net>)

=head1 LICENCE AND COPYRIGHT

This file is part of the Rosetta database portability library.

Rosetta is Copyright (c) 2002-2005, Darren R. Duncan.  All rights reserved.
Address comments, suggestions, and bug reports to C<perl@DarrenDuncan.net>,
or visit L<http://www.DarrenDuncan.net/> for more information.

Rosetta is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License (GPL) as published by the Free
Software Foundation (L<http://www.fsf.org/>); either version 2 of the
License, or (at your option) any later version.  You should have received a
copy of the GPL as part of the Rosetta distribution, in the file named
"GPL"; if not, write to the Free Software Foundation, Inc., 51 Franklin St,
Fifth Floor, Boston, MA  02110-1301, USA.

Linking Rosetta statically or dynamically with other files is making a
combined work based on Rosetta.  Thus, the terms and conditions of the GPL
cover the whole combination.  As a special exception, the copyright holders
of Rosetta give you permission to link Rosetta with independent files,
regardless of the license terms of these independent files, and to copy
and distribute the resulting combined work under terms of your choice,
provided that every copy of the combined work is accompanied by a complete
copy of the source code of Rosetta (the version of Rosetta used to produce
the combined work), being distributed under the terms of the GPL plus this
exception.  An independent file is a file which is not derived from or
based on Rosetta, and which is fully useable when not linked to Rosetta in
any form.

Any versions of Rosetta that you modify and distribute must carry prominent
notices stating that you changed the files and the date of any changes, in
addition to preserving this original copyright notice and other credits.
Rosetta is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

While it is by no means required, the copyright holders of Rosetta would
appreciate being informed any time you create a modified version of Rosetta
that you are willing to distribute, because that is a practical way of
suggesting improvements to the standard version.

=head1 ACKNOWLEDGEMENTS

None yet.

=cut
