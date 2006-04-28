#!/usr/bin/pugs
use v6;

# External packages used by packages in this file, that don't export symbols:
# (None Yet)

###########################################################################
###########################################################################

# Constant values used by packages in this file:
my Str $EMPTY_STR is readonly = q{};

###########################################################################
###########################################################################

class Relation-0.0.1 {

    # External packages used by the Relation class, that do export symbols:
    # (None Yet)

    # Attributes of every Relation object:
    has 1 %!heading;
        # Hash(Str) of 1
        # Each hash key is a name of one of this Relation's attributes; the
        # corresponding hash value is always the number 1.
        # Note that it is valid for a Relation to have zero attributes.
    has Hash @!body;
        # Array of Hash(Str) of Any
        # Each array element is a tuple of this Relation, where the tuple
        # is represented as a hash; each key of that hash is the name of
        # one of this Relation's attributes and the value corresponding to
        # that is the value for that attribute for that tuple.
        # Note that it is valid for a Relation to have zero tuples.
        # Note that while an array is used here, it is meant to represent a
        # set of tuples, so its elements are conceptually not in any order.

###########################################################################

submethod BUILD (1 :%heading? = {}, Hash :@body? = []) {

    die "Arg :%heading has the empty string for a key."
        if %heading.exists($EMPTY_STR);
    %!heading = {%heading};

    for @body -> %tuple {
        die "An element of arg :@body has an element count that does not"
                ~ "match the element count of arg :%heading."
            if +%tuple.keys != +%heading.keys;
        die "An element of arg :@body has the empty string for a key."
            if %tuple.exists($EMPTY_STR);
        for %tuple.kv -> $atnm, $atvl {
            die "An element of arg :@body has a key, '$atnm', that does"
                    ~ " not match any key of arg :%heading."
                if !%heading.exists($atnm);
        }
    }
    # TODO: Eliminate any duplicate/redundant @body elements silently.
    @!body = [@body.map:{ {$_} }];

    return;
}

###########################################################################

method export_as_hash () returns Hash {
    return {
        'heading' => {%!heading},
        'body'    => [@!body.map:{ {$_} }],
    };
}

###########################################################################

} # class Relation

###########################################################################
###########################################################################

=pod

=encoding utf8

=head1 NAME

Relation -
Relations for Perl 6

=head1 VERSION

This document describes Relation version 0.0.1.

=head1 SYNOPSIS

    use Relation;

I<This documentation is pending.>

=head1 DESCRIPTION

This class implements a Relation data type that corresponds to the
"relation" of logic and mathematics and philosophy ("a predicate ranging
over more than one argument"), which is also the basis of the relational
data model proposed by Edgar. F. Codd, upon which anything in the world can
be modelled.

A relation is essentially a set of sets, or a set of logical tuples; a
picture of one can look like a table, where each tuple is a row and each
relation/tuple attribute is a column, but it is not the same as a table.

The intended interface and use of this class in Perl programs is similar to
the intended use of a L<Set> class; a Relation is like a Set that exists
over N dimensions rather than one.  The Relation operators are somewhat of
a superset of the Set operators.

Like the Set data type, the Relation data type is immutable.  The value of
a Relation object is determined when it is constructed, and the object can
not be changed afterwards.

If you want something similar but that is mutable, you can accomplish that
manually using a multi-dimensional object Hash, or various combinations of
other data types.

While the implementation can be changed greatly (it isn't what's important;
the interface/behaviour is), this Relation data type is proposed to be
generally useful, and very basic, and worthy of inclusion in the Perl 6
core, at least as worthy as a Set data type is.

=head1 INTERFACE

The interface of Relation is entirely object-oriented; you use it by
creating objects from its member classes, usually invoking C<new()> on the
appropriate class name, and then invoking methods on those objects.  All of
their class/object attributes are private, so you must use accessor
methods.  Relation does not declare any subroutines or export such.

The usual way that Relation indicates a failure is to throw an exception;
most often this is due to invalid input.  If an invoked routine simply
returns, you can assume that it has succeeded.

=head2 The Relation Class

A Relation object is an unordered set of tuples, each of which is an
unordered set of named attributes; all tuples in a Relation are of the same
degree, and the attribute names of each tuple are all the same as those of
all the other tuples.

For purposes of the Relation class' API, a tuple is represented by a Perl
Hash where each Hash key is an attribute name and each Hash value is the
corresponding attribute value.

Every Relation attribute has a name that is distinct from the other
attributes, though several attributes may store values of the same class;
every Relation tuple must be distinct from the other tuples.  All Relation
attributes may be individually addressed only by their names, and all
Relation tuples may be individually addressed only by their values; neither
may be addressed by any ordinal value.

Note that it is valid for a Relation to have zero tuples.  It is also valid
for a Relation to have zero attributes, though such a Relation can have no
more than a single tuple.  A zero-attribute Relation with zero tuples or
one tuple respectively have a special meaning in relational algebra which
is analagous to what the identity numbers 0 and 1 mean to normal algebra.

A picture of a Relation can look like a table, where each of its tuples is
a row, and each attribute is a column, but a Relation is not a table.

Note that, unlike some standard definitions of what a Relation should be,
this class does not associate specific data types with each relation
attribute, such to constrain corresponding tuple attributes; rather, every
attribute is implicitly of type Any.  That said, like said standard
definitions, no two stored values will be considered equal if they aren't
of the same actual class.

The Relation class is pure and deterministic, such that all of its class
and object methods will each return the same result when invoked on the
same object with the same arguments; they do not interact with the outside
environment at all.

A Relation object has 2 main attributes (implementation details subject to
change):

=over

=item C<%!heading> - B<Relation Heading>

Hash(Str) of 1 - This contains zero or more Relation attribute names that
define the heading of this Relation.  Each attribute name is a non-empty
character string.

=item C<@!body> - B<Relation Body>

Array of Hash(Str) of Any - This contains zero or more member tuples of the
Relation; each Array element is a Hash whose keys and values are attribute
names and values.  Each Hash key of a Body tuple must match a Hash key of
Heading, and the value of every tuple in Body must be mutually distinct.
Despite this property being implemented (for now) with an Array, its
elements are all conceptually not in any order.

=back

This is the main Relation constructor method:

=over

=item C<new( Role :%heading?, Hash :@body? )>

This method creates and returns a new Relation object, whose Heading and
Body attributes are set respectively from the optional named parameters
%heading and @body.  If %heading is undefined or an empty Hash, the
Relation has zero attributes.  If @body is undefined or an empty Array, the
Relation has zero tuples.  If a Relation has zero attributes, then @body
may be an Array with a single element that is an empty Hash.

=back

A Relation object has these methods:

=over

=item C<export_as_hash()>

This method returns a deep copy of this Relation as a Hash ref of 2
elements, which correspond to the 2 named parameters of new().

=back

=head1 DIAGNOSTICS

I<This documentation is pending.>

=head1 CONFIGURATION AND ENVIRONMENT

I<This documentation is pending.>

=head1 DEPENDENCIES

This file requires any version of Perl 6.x.y that is at least 6.0.0.

=head1 INCOMPATIBILITIES

None reported.

=head1 SEE ALSO

L<Set>.

=head1 BUGS AND LIMITATIONS

I<This documentation is pending.>

=head1 AUTHOR

Darren R. Duncan (C<perl@DarrenDuncan.net>)

=head1 LICENCE AND COPYRIGHT

This file is part of the Relation library.

Relation is Copyright (c) 2006, Darren R. Duncan.

Relation is free software; you can redistribute it and/or modify it under
the same terms as Perl 6 itself.

=head1 ACKNOWLEDGEMENTS

None yet.

=cut
