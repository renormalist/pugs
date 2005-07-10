use v6;

class Span-0.01;

# use Set::Infinite;
use Span::Num;
use Span::Int;

has $.span;

=for TODO

    * union
    * intersection
    * complement
    * intersects
        - tests
    
    * compare

    * is_infinite

    * set_start_open / set_start_closed
    * set_end_open / set_end_closed
        - better names ?

    * set_density / density

From "Set" API:

    * equal/not_equal
    * stringify
    * difference
    * symmetric_difference
    * proper_subset
    * proper_superset
    * subset
    * superset
    * includes/member/has
    * unicode

=cut

submethod BUILD ($class: *%param is copy ) {
    my ( $start, $end );
    my bool $start_is_open;
    my bool $end_is_open;
    my $density;
    $density = 1 if %param<int>;
    $density = %param<density> if defined %param<density>;

    if defined( %param<span> ) 
    {
        if %param<span>.isa( $class.ref )
        {
            return $class.bless( { span => %param<span>.span } );
        }
        if %param<span>.isa( 'Span::Num' )
        {
            return $class.bless( { span => %param<span> } );
        }
        if %param<span>.isa( 'Span::Int' )
        {
            return $class.bless( { span => %param<span> } );
        }
        # die "unknown span class";
        %param<object> = %param<span>;
    }

    if defined( %param<object> ) 
    {
        if %param<object>.ref eq 'Array' {
            if %param<object>.elems > 0
            {
                %param<start> = %param<object>[0];
                %param<end> = %param<object>[-1];
            }
        }
        else
        {
            %param<start> = %param<end> = %param<object>;
        }
    }

    if ( defined $density )
    {
        if defined( %param<start> )  { $start = %param<start> };
        if defined( %param<after> )  { $start = %param<after> + $density };
        if defined( %param<end> )    { $end =   %param<end> };
        if defined( %param<before> ) { $end =   %param<before> - $density };

        if   !defined( $start ) &&  defined( $end ) { $start = -Inf }
        elsif defined( $start ) && !defined( $end ) { $end = Inf }

        die "start must be less or equal to end" if $start > $end;

        if defined( $start ) && defined( $end ) {
            $.span = Span::Int.new( :start($start), 
                                    :end($end), 
                                    :density($density) );
        }
        else
        {
            $.span = Span::Int.empty_span;
        }
    }
    else
    {
        if defined( %param<start> )  { $start = %param<start>;  $start_is_open = bool::false };
        if defined( %param<after> )  { $start = %param<after>;  $start_is_open = bool::true };
        if defined( %param<end> )    { $end =   %param<end>;    $end_is_open =   bool::false };
        if defined( %param<before> ) { $end =   %param<before>; $end_is_open =   bool::true };

        if   !defined( $start ) &&  defined( $end ) { $start = -Inf }
        elsif defined( $start ) && !defined( $end ) { $end = Inf }

        $start_is_open = bool::true if $start == -Inf;
        $end_is_open =   bool::true if $end == Inf;

        die "start must be less or equal to end" if $start > $end;

        if defined( $start ) && defined( $end ) {
            $.span = Span::Num.new( :start($start), 
                                    :end($end), 
                                    :start_is_open($start_is_open), 
                                    :end_is_open($end_is_open) );
        }
        else
        {
            $.span = Span::Num.empty_span;
        }
    }
}

method is_empty () returns bool { return $.span.is_empty }

method start () returns Object { return $.span.start }

method set_start ($self: $start ) {
    if $.span.is_empty 
    {
        $.span = $self.new( start => $start ).span;
    }
    else
    {
        my int $cmp = $start <=> $.span.end;
        if $cmp > 0 {
            warn "setting start bigger than end yields an empty set";
            undefine $.span;
        }
        elsif $cmp == 0 && ( $.span.start_is_open || $.span.end_is_open ) {
            warn "setting start equal to end yields an empty set";
            undefine $.span;
        }
        else
        {
            $.span = $.span.clone;
            $.span.start = $start;
        }
    }
}

method end () returns Object { return $.span.end }

method set_end ($self: Object $end ) {
    if $.span.is_empty
    {
        $.span = $self.new( end => $end ).span;
    }
    else
    {
        my int $cmp = $.span.start <=> $end;
        if $cmp > 0 {
            warn "setting start bigger than end yields an empty set";
            undefine $.span;
        }
        elsif $cmp == 0 && ( $.span.start_is_open || $.span.end_is_open ) {
            warn "setting start equal to end yields an empty set";
            undefine $.span;
        }
        else
        {
            $.span = $.span.clone;
            $.span.end = $end;
        }
    }
}

method start_is_open () returns Bool {
    return bool::false if $.span.is_empty;
    return $.span.start_is_open;
}
method start_is_closed () returns Bool {
    return bool::false if $.span.is_empty;
    return $.span.start_is_closed;
}
method end_is_open () returns Bool {
    return bool::false if $.span.is_empty;
    return $.span.end_is_open;
}
method end_is_closed () returns Bool {
    return bool::false if $.span.is_empty;
    return $.span.end_is_closed;
}
method stringify () returns String {
    return '' if $.span.is_empty;
    return $.span.stringify;
}
method size () returns Object {
    return undef if $.span.is_empty;
    return $.span.size;
}

method contains ($self: $span is copy) returns bool {
    # XXX TODO - the parameter may be a Set::Infinite
    return bool::false if $.span.is_empty;
    $span = $self.new( object => $span )
        if ! ( $span.isa( $self.ref ) );
    my $span1 = $self.span;
    my @union = $span1.union( $span.span );
    
    # XXX this should work
    # my @union = $self.span.union( $span.span );
    
    return bool::false if @union.elems == 2;
    return @union[0].compare( $self.span ) == 0;
}

method intersects ($self: $span is copy) returns bool {
    # XXX TODO - the parameter may be a Set::Infinite
    return bool::false if $.span.is_empty;
    $span = $self.new( object => $span )
        if ! ( $span.isa( $self.ref ) );
    my $span1 = $self.span;
    my @union = $span1.union( $span.span );
    
    # XXX - this should work
    # my @union = $self.span.union( $span.span );

    return @union.elems == 1;
}

method union ($self: $span ) returns Set::Infinite {
    return Set::Infinite.new( spans => ( $self, $span ) )
}

method intersection ($self: $span ) returns Set::Infinite {
    return Set::Infinite.new( spans => ( $self ) ).intersection( $span ) 
}
method complement ($self: ) returns Set::Infinite {
    return Set::Infinite.new( spans => ( $self ) ).complement
}
method difference ($self: $span ) returns Set::Infinite {
    return Set::Infinite.new( spans => ( $self ) ).difference( $span )
}

=kwid

= NAME

Span - An object representing a single span

= SYNOPSIS

  use Span;

  # XXX

= DESCRIPTION

This class represents a single span.

= CONSTRUCTORS

- `new()`

Without any parameters, returns an empty span.

- `new( object => 1 )`

Creates a span with a single element. This is the same as `new( start => $object, end => $object )`.

- `new( span => $span )`

Creates a `Span` object using an existing span.

- `new( start => 1 )`

Given a start object, returns a span that has infinite size.

- `new( :int, start => 1, end => 2 )`

Creates a span with "integer" semantics.

- `new( start => $first_day, end => $last_day, :density($day_duration) )`

Creates a span with "day" semantics.

= OBJECT METHODS

    # XXX

The following methods are available for Span objects:

- `start()` / `end()`

Return the start or end value of the span.

These methods may return nothing if the span is empty.

- `set_start( $object )` / `set_end( $object )`

Change the start or end value of the span.

These methods may raise a warning if the new value would put the span 
in an invalid state, such as `start` bigger than `end` (the span is
emptied in this case).

- `start_is_open()` / `end_is_open()` / `start_is_closed()` / `end_is_closed()`

Return a logical value, whether the `start` or `end` values belong to the span ("closed") or not ("open").

- size

Return the "size" of the span.

For example: if `start` and `end` are times, then `size` will be a duration.

- `contains( Object )` / `intersects( Object )`

These methods return a logical value.

- union

Returns a `Set::Infinite` object.

- complement

Returns a `Set::Infinite` object.

- difference

Returns a `Set::Infinite` object.

- intersects

  # XXX

- intersection 

Returns a `Set::Infinite` object.

- stringify 

  # XXX

- compare

  # XXX

- is_empty()

- `span`

Returns a `Span::Num` or `Span::Int` object, which may be useful if you
are mixing functional/non-functional programming.

= AUTHOR

Flavio S. Glock, <fglock@pucrs.br>

= COPYRIGHT

Copyright (c) 2005, Flavio S. Glock.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
