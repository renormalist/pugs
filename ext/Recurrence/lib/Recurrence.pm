use v6-alpha;

use Set::Symbols;  # unicode operators
use Span;          # stringify()

=for TODO

    * make a Recurrence::Span class - elements can be spans

  Bugs:
    * operations with non-Recurrences should return a Set::Infinite / Span
    * cleanup extra "is copy"
    * remove "arbitrary_limit" if possible
    * cleanup circular references using 'submethod DESTROY {}'
    
  Tests:
    * overloading - ~ <=> 

  Methods:
    * iterator / map 
    * size - accept a function; use as_list
    * compare
    * as_list
    * contains( $set )
    * set_start / set_end
    * remove "difference()" method ?

  Constructor:  ------------

- `new( closure_next => sub {...} )`

Creates a recurrence set where only methods `start()` and `next($x)` are enabled.

- `new( closure_previous => sub {...} )`

Creates a recurrence set where only methods `end()`, `previous($x)` are enabled.

- `new( closure_next =>     sub {...}, universe => $universal_set )`
- `new( closure_previous => sub {...}, universe => $universal_set )`

Create a recurrence set with full bidirectional functionality.

The complementary functions are emulated using iterations.

- `new( closure_next => sub {...}, closure_previous => sub {...} )`

Creates a bidirectional recurrence set.

These methods are disabled: complement(), difference($set)

  ---------------- end Constructor 
  
=cut

class Recurrence-0.01
    does Set::Symbols
{
    has Code $.closure_next;
    has Code $.closure_previous;
    has Code $.complement_next;
    has Code $.complement_previous;
    has Recurrence $.universe;   
    has Int  $!arbitrary_limit;

submethod BUILD (
    $.closure_next, 
    $.closure_previous, 
    $is_universe?, 
    $complement_next?, 
    $complement_previous?, 
    $.universe?, 
) 
{
    # TODO - get rid of "$!arbitrary_limit"
    $!arbitrary_limit = 100;
    
    if $is_universe {
        # $.universe = $self --> $self doesn't exist yet
        $.complement_next =     sub { +Inf } unless defined $.complement_next;
        $.complement_previous = sub { -Inf } unless defined $.complement_previous;
    }
}

method get_universe ($self: ) {
    # TODO - weak reference
    # XXX - universe = self.union( self.complement )
    return $.universe = $self unless defined $.universe;
    return $.universe;
}

method equal ($self: $set ) returns Bool {
    $self.closure_next === $set.closure_next
}

method stringify ($self: ) returns Str {
    my $tmp = Span.new().union( $self );
    return $tmp.stringify;
}

method intersects ($self: $set ) returns bool {
    my $tmp = $self.intersection( $set );
    return ! $tmp.is_empty;
}

method union ($self: $set ) { 
    my $universe = $self.get_universe;
    return $universe if $set.equal( $universe );
    return $universe if $self.equal( $universe );
    return $set      if $self.equal( $set );

    return $self.new( 
        closure_next =>        $self._get_union( $self.closure_next, $set.closure_next, -1 ),
        closure_previous =>    $self._get_union( $self.closure_previous, $set.closure_previous, 1 ),
        complement_next =>     $self._get_intersection( $self.complement_next, $self.complement_previous, $set.complement_next, $set.complement_previous ),
        complement_previous => $self._get_intersection( $self.complement_previous, $self.complement_next, $set.complement_previous, $set.complement_next ),
        universe =>            $universe,
    )
}

method intersection ($self: $set ) {
    my $universe = $self.get_universe;
    return $self if $set.equal( $universe );
    return $set  if $self.equal( $universe );
    return $set  if $self.equal( $set );

    return $self.new( 
        closure_next =>        $self._get_intersection( $self.closure_next, $self.closure_previous, $set.closure_next, $set.closure_previous ),
        closure_previous =>    $self._get_intersection( $self.closure_previous, $self.closure_next, $set.closure_previous, $set.closure_next ),
        complement_next =>     $self._get_union( $self.complement_next, $set.complement_next, -1 ),
        complement_previous => $self._get_union( $self.complement_previous, $set.complement_previous, 1 ),
        universe =>            $universe,
    )
}

method complement ($self: ) {
    return $self.new( 
        closure_next =>        $self._get_complement_next, 
        closure_previous =>    $self._get_complement_previous, 
        complement_next =>     $self.closure_next,
        complement_previous => $self.closure_previous,
        universe =>            $self.get_universe,
    );
}

method difference ($self: $set ) {
    return $self.intersection( $set.complement );
}

# --------- arithmetic and list operations ----------------

method grep ($set: Code $select ) {
    return $set.new( 
        closure_next =>
            sub ($x is copy) { 
                loop {
		    $x = $set.closure_next()($x); 
		    return $x if $x==Inf || $select($x)
		} 
            },
        closure_previous =>
            sub ($x is copy) { 
                loop {
		    $x = $set.closure_previous()($x); 
		    return $x if $x==-Inf || $select($x)
		} 
            },
        # -- use the default generated closures
        # complement_next =>     sub ($x) {...},
        # complement_previous => sub ($x) {...},
        universe =>            $set.get_universe,
    );
}

method negate ($set: ) {
    return $set.new( 
        closure_next =>        sub ($x) { - $set.closure_previous()( -$x ) }, 
        closure_previous =>    sub ($x) { - $set.closure_next()( -$x ) }, 
        complement_next =>     sub ($x) { - $set._get_complement_previous()( -$x ) },
        complement_previous => sub ($x) { - $set._get_complement_next()( -$x ) },
        universe =>            $set.get_universe,
    );
}

# --------- scalar functions -----------

method next ( $x ) { 
    return $.closure_next( $x );
}

method previous ( $x ) { 
    return $.closure_previous( $x );
}

method current ( $x ) {
    return $.closure_next( $.closure_previous( $x ) );
}

method contains ($self: $x ) returns bool {
    return $x == $self.current( $x );
}

method closest ($self: $x ) {
    my $n = $self.next( $x );
    my $p = $self.current( $x );
    return $n - $x < $x - $p ?? $n !! $p;
}

method is_empty ($self: ) {
    return $self.start > $self.end;
}

method is_infinite ($self: ) {
    return $self.start == -Inf || $self.end == Inf;
}

method start ($self: ) {
    return $self.next( -Inf );
}

method end ($self: ) {
    return $self.previous( Inf );
}

# --------- internals -----------

submethod _get_union ( $closure1, $closure2, $direction ) {
    return $closure1 if $closure1 === $closure2;
    return sub ( $x is copy ) {
        my $n1 = $closure1( $x );
        my $n2 = $closure2( $x );
        return ( $n1 <=> $n2 ) == $direction ?? $n1 !! $n2;
    }
}

submethod _get_intersection ( $closure1, $closure2, $closure3, $closure4 ) {
    return $closure1 if $closure1 === $closure3;
    return sub ( $x ) {
        my $n1;
        my $n2 = $closure3( $x );
        for ( 0 .. $!arbitrary_limit )
        {
            $n1 = $closure1( $closure2( $n2 ) );
            return $n1 if $n1 == $n2;
            $n2 = $closure3( $closure4( $n1 ) );
        }
        warn "Arbitrary limit exceeded when calculating intersection()";
    }
}

submethod _get_complement_next ($self: ) { 
    return $.complement_next if defined $.complement_next;
    $self.get_universe;
    return $.complement_next =
        sub ( $x is copy ) {
            for ( 0 .. $!arbitrary_limit )
            {
                $x = $.universe.closure_next()( $x );
                return $x if $x == Inf || $x == -Inf ||
                             $x != $self.closure_previous()( $self.closure_next()( $x ) );
            }
            warn "Arbitrary limit exceeded when calculating complement()";
        };
}

submethod _get_complement_previous ($self: ) { 
    return $.complement_previous if defined $.complement_previous;
    $self.get_universe;
    return $.complement_previous =
        sub ( $x is copy ) {
            for ( 0 .. $!arbitrary_limit )
            {
                $x = $.universe.closure_previous()( $x );
                return $x if $x == Inf || $x == -Inf ||
                             $x != $self.closure_next()( $self.closure_previous()( $x ) );
            }
            warn "Arbitrary limit exceeded when calculating complement()";
        };
}

} # class Recurrence


=kwid

= NAME

Recurrence - An object representing an infinite recurrence set

= SYNOPSIS

    use Recurrence;

    # all integer numbers
    $universe = Recurrence.new( 
        closure_next =>     sub { $_ + 1 },
        closure_previous => sub { $_ - 1 },
        :is_universe(1) );

    # all even integers
    $even_numbers = Recurrence.new( 
        closure_next =>     sub { 2 * int( $_ / 2 ) + 2     },
        closure_previous => sub { 2 * int( ( $_ - 1 ) / 2 ) },
        universe => $universe );

    # all odd integers
    $odd_numbers = $even_numbers.complement;

    # all non-zero integers
    $non_zero = Recurrence.new( 
        closure_next =>        sub ($x) { $x == -1 ??  1 !! $x + 1 },
        closure_previous =>    sub ($x) { $x ==  1 ?? -1 !! $x - 1 },
        complement_next =>     sub ($x) { $x < 0   ??  0 !!    Inf },
        complement_previous => sub ($x) { $x > 0   ??  0 !!   -Inf },
        universe => $universe );

    # TODO - test this
    # all non-zero integers - alternative form
    # Note: $non_zero is a Set::Infinite object
    $non_zero = $universe.difference( 0 );

= DESCRIPTION

This class handles an infinite recurrence set, defined with closures. 

A recurrence set is defined by a "successor" function and a "predecessor" 
function.

Recurrence sets can extend from "negative Infinite" until "Infinite".

Recurrence sets can be combined with union, intersection, difference, and a few
other operations.

This class also provides methods for iterating through the set, and for querying 
set properties.

Note that all set functions may end up being calculated using iterations, 
which can be slow sometimes.
Set functions might also fail and emit warnings in some cases.

= CONSTRUCTORS

- `new( closure_next => sub {...}, closure_previous => sub {...}, universe => $universe )`

Creates a recurrence set.

The complementary functions are emulated using iterations.

See also the section "UNIVERSAL SET CONSTRUCTOR".

- `new( closure_next => sub {...}, closure_previous => sub {...}, complement_next => sub {...}, complement_previous => sub {...} )`

Creates a recurrence set. The complement set is specified with a recurrence.

= UNIVERSAL SET CONSTRUCTOR

- `new( closure_next => sub {...}, closure_previous => sub {...}, :is_universe(1) )`

Creates a "universal set".

The complement set of the universe is an empty set.

`:is_universe` must be set if this recurrence is a "universal set".
Otherwise the program will emit warnings during the execution of some methods, 
because it will try to iterate to find a "complement set" that is empty.

= SET FUNCTIONS

- `get_universe()`

Returns the "universal set" recurrence object.

- `complement()`

Returns everything (from the universal set) that is not in this recurrence.

- `union( $recurrence )`

Returns all elements both from this recurrence and from the given recurrence.

- `intersection( $recurrence )`

Returns only the elements in this recurrence that are also in the given recurrence.

- `difference( $recurrence )`

Returns only the elements in this recurrence that are not in the given recurrence.

- `intersects( $recurrence )`

Returns true if this recurrence intersects (has any element in common) with the given recurrence.

- `equal( $recurrence )`

Returns true if the closures that define the recurrences are exactly the same.

This method tests the closures identities using the '===' operation.

= SCALAR FUNCTIONS

- `next( $x )`

Returns the element in the recurrence that is right after the parameter.

- `previous( $x )`

Returns the element in the recurrence that is right before the parameter.

- `current( $x )`

Returns the parameter value if the parameter is a member of the recurrence.
Otherwise, returns the previous element in the recurrence.

- `contains( $x )`

Returns true if the parameter is a member of the recurrence set.

- `closest( $x )`

Returns the element in the recurrence that is closest to the parameter.
If both previous and next elements are at the same distance, returns the previous one.

- `is_empty()`

Returns true if the recurrence is an empty set.

- `is_infinite()`

Returns true if the recurrence is infinite.

- `start()`

Returns the start element in the recurrence.

Returns negative infinite if the recurrence is infinite.
Returns positive infinite if the recurrence is an empty set.

- `end()` 

Returns the last element in the recurrence.

Returns positive infinite if the recurrence is infinite.
Returns negative infinite if the recurrence is an empty set.

- `stringify()`

Return a string representation of the set.

For most recurrence sets, this is '-Inf..Inf'.

= ARITHMETIC AND LIST FUNCTIONS

- `negate()`

Returns a recurrence set with all elements negated (-$x).

- `grep:{...}`

This method returns a recurrence set containing only the elements that 
satisfy the given boolean function.

    # remove 0 and 5 from the recurrence
    my $span1 = $span.grep:{ $^a != 0 & 5 };

grep() is evaluated lazily. This means that side effects, such as "say" and
database queries, may occur much later than expected.

It may enter an infinite loop if the formula cannot be satisfied within a 
reasonable range of values.

You should consider using a Set::Infinite object if you want to exclude
large ranges.

    # it's better to use Set::Infinite instead of this
    my $span1 = $span.grep:{ $^a != all(0..100000) };

= SEE ALSO

    Span
    
    Set::Infinite

= AUTHOR

Flavio S. Glock, <fglock@pucrs.br>

= COPYRIGHT

Copyright (c) 2005, Flavio S. Glock.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
