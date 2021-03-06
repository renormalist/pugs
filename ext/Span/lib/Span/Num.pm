use v6-alpha;

class Span::Num-0.01;

has $.start;
has $.end;
has bool   $.start_is_open;
has bool   $.end_is_open;

=for TODO

    * open-set could be "start = object but true" and
      closed-set could be "start = object but false"

=cut

submethod BUILD (
    $.start, 
    $.end, 
    $.start_is_open? = Bool::False, 
    $.end_is_open?   = Bool::False, 
) 
{}

method empty_span ($class: ) { $class.new( start => undef, end => undef ) }
method is_empty        () returns bool   { ! defined( $.start ) }
method size            () returns Object { $.end - $.start }
method start_is_closed () returns bool   { ! $.start_is_open }
method end_is_closed   () returns bool   { ! $.end_is_open }

method intersects ( Span::Functional $span ) returns bool {
    my ($i_start, $i_end);
    my bool $open_start;
    my bool $open_end;
    my $cmp = $.start <=> $span.start;
    if ($cmp < 0) {
        $i_start       = $span.start;
        $open_start    = $span.start_is_open;
    }
    elsif ($cmp > 0) {
        $i_start       = $.start;
        $open_start    = $.start_is_open;
    }
    else {
        $i_start       = $.start;
        $open_start    = $.start_is_open || $span.start_is_open;
    }
    $cmp = $.end <=> $span.end;
    if ($cmp > 0) {
        $i_end       = $span.end;
        $open_end    = $span.end_is_open;
    }
    elsif ($cmp < 0) {
        $i_end       = $.end;
        $open_end    = $.end_is_open;
    }
    else {
        $i_end       = $.end;
        $open_end    = $.end_is_open || $span.end_is_open;
    }
    $cmp = $i_start <=> $i_end;
    return $cmp <= 0  &&
           ( $cmp != 0  ||  ( ! $open_start && ! $open_end ) );
}

method complement ($self: ) returns List of Span::Num 
{
    if ($.end == Inf) {
        return () if $.start == -Inf;
        return $self.new( start => -Inf,
                     end =>   $.start,
                     start_is_open => Bool::True,
                     end_is_open =>   ! $.start_is_open );
    }
    if ($.start == -Inf) {
        return $self.new( start => $.end,
                     end =>   Inf,
                     start_is_open => ! $.end_is_open,
                     end_is_open =>   Bool::True );
    }
    return (   $self.new( start => -Inf,
                     end =>   $.start,
                     start_is_open => Bool::True,
                     end_is_open =>   ! $.start_is_open ),
               $self.new( start => $.end,
                     end =>   Inf,
                     start_is_open => ! $.end_is_open,
                     end_is_open =>   Bool::True ) );
}

method union ($self: Span::Num $span ) 
    returns List of Span::Num 
{
    my int $cmp;
    $cmp = $.end <=> $span.start;
    if ( $cmp < 0 ||
             ( $cmp == 0 && $.end_is_open && $span.start_is_open ) ) {
        return ( $self, $span );
    }
    $cmp = $.start <=> $span.end;
    if ( $cmp > 0 ||
         ( $cmp == 0 && $span.end_is_open && $.start_is_open ) ) {
        return ( $span, $self );
    }

    my ($i_start, $i_end, $open_start, $open_end);
    $cmp = $.start <=> $span.start;
    if ($cmp > 0) {
        $i_start = $span.start;
        $open_start = $span.start_is_open;
    }
    elsif ($cmp == 0) {
        $i_start = $.start;
        $open_start = $.start_is_open ?? $span.start_is_open !! 0;
    }
    else {
        $i_start = $.start;
        $open_start = $.start_is_open;
    }

    $cmp = $.end <=> $span.end;
    if ($cmp < 0) {
        $i_end = $span.end;
        $open_end = $span.end_is_open;
    }
    elsif ($cmp == 0) {
        $i_end = $.end;
        $open_end = $.end_is_open ?? $span.end_is_open !! 0;
    }
    else {
        $i_end = $.end;
        $open_end = $.end_is_open;
    }
    return $self.new( start => $i_start,
                 end =>   $i_end,
                 start_is_open => $open_start,
                 end_is_open =>   $open_end );
}

method intersection ($self: $span ) {

    return $span.intersection( $self )
        if $span.isa( 'Span::Code' );

    my ($i_start, $i_end);
    my bool $open_start;
    my bool $open_end;
    my int $cmp = $.start <=> $span.start;
    if ($cmp < 0) {
        $i_start       = $span.start;
        $open_start    = $span.start_is_open;
    }
    elsif ($cmp > 0) {
        $i_start       = $.start;
        $open_start    = $.start_is_open;
    }
    else {
        $i_start       = $.start;
        $open_start    = $.start_is_open || $span.start_is_open;
    }
    $cmp = $.end <=> $span.end;
    if ($cmp > 0) {
        $i_end       = $span.end;
        $open_end    = $span.end_is_open;
    }
    elsif ($cmp < 0) {
        $i_end       = $.end;
        $open_end    = $.end_is_open;
    }
    else {
        $i_end       = $.end;
        $open_end    = $.end_is_open || $span.end_is_open;
    }
    $cmp = $i_start <=> $i_end;
    if $cmp <= 0  &&
       ( $cmp != 0  ||  ( ! $open_start && ! $open_end ) )
    {
        return $self.new( start => $i_start,
                     end =>   $i_end,
                     start_is_open => $open_start,
                     end_is_open =>   $open_end );
    }
    return;
}

method stringify () returns String {
    return '' unless defined $.start;
    my $tmp1 = "$.start";
    my $tmp2 = "$.end";
    return $tmp1 if $tmp1 eq $tmp2;
    return ( $.start_is_open ?? '(' !! '[' ) ~
           $tmp1 ~ ',' ~ $tmp2 ~
           ( $.end_is_open   ?? ')' !! ']' );
}

method compare ( Span::Num $span ) returns int {
    my int $cmp;
    $cmp = $.start <=> $span.start;
    return $cmp if $cmp;
    $cmp = $span.start_is_open <=> $.start_is_open;
    return $cmp if $cmp;
    $cmp = $.end <=> $span.end;
    return $cmp if $cmp;
    return $span.end_is_open <=> $.end_is_open;
}

method difference ($self: $span ) returns List {
    return $self if $self.is_empty;
    my @span = $span.complement;
    @span = @span.map:{ $self.intersection( $_ ) };
    return @span;
}

method next ($self: $x ) {
    return $.start if $x < $.start;
    return $x      if   $.end_is_open && $x < $.end;
    return $x      if ! $.end_is_open && $x <= $.end;
    return Inf;
}

method previous ($self: $x ) {
    return $.end   if $x > $.end;
    return $x      if   $.start_is_open && $x > $.start;
    return $x      if ! $.start_is_open && $x >= $.start;
    return -Inf;
}

=kwid

= NAME

Span::Num - An object representing a single span, with a simple functional API.

= SYNOPSIS

  use Span::Num;

  $span = Span::Num.new( start => $start, end => $end, start_is_open => Bool::False, end_is_open => Bool::False );

= DESCRIPTION

This class represents a single span.

It is intended mostly for "internal" use by the Span class. 
For a more complete API, see `Span`.

The `start` value must be less than or equal to `end`. There is no checking.

= AUTHOR

Flavio S. Glock, <fglock@gmail.com>

= COPYRIGHT

Copyright (c) 2005, Flavio S. Glock.  All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
