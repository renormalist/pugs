#!pugs
use v6;

require Algorithm::Dependency-0.0.1;

class Algorithm::Dependency::Item-0.0.1;

# Algorithm::Dependency::Item implements an object for a single item
# in the database, with a unique id.

has $:id;
has @:depends;

method new( $class: $id, @depends ) returns Algorithm::Dependency::Item {
	# Create the object
	return $class.bless( { id => $id, depends => @depends } );
}

# Get the values
method id      ()  returns Str   { return $.id         }
method depends ()  returns Array { return @{$.depends} }

1;

__END__

=pod

=head1 NAME

Algorithm::Dependency::Item - Implements an item in a dependency heirachy.

=head1 DESCRIPTION

The Algorithm::Dependency::Item class implements a single item within the
dependency heirachy. It's quite simple, usually created from within a source,
and not typically created directly. This is provided for those implementing
their own source. ( See L<Algorithm::Dependency::Source> for details ).

=head1 METHODS

=head2 new $id, @depends

The C<new> constructor takes as it's first argument the id ( name ) of the
item, and any further arguments are assumed to be the ids of other items that
this one depends on.

Returns a new Algorithm::Dependency::Item on success, or C<undef> on error.

=head2 id

The C<id> method returns the id of the item.

=head2 depends

The C<depends> method returns, as a list, the names of the other items that
this item depends on.

=head1 SUPPORT

For general comments, contact the author.

To file a bug against this module, in a way you can keep track of, see the
CPAN bug tracking system.

http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Algorithm%3A%3ADependency

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 SEE ALSO

L<Algorithm::Dependency>

=head1 COPYRIGHT

Copyright (c) 2003 - 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
