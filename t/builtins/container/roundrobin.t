use v6-alpha;

use Test;

plan 8;

# L<S29/Container/"=item roundrobin">

=pod

Tests of

  our Lazy multi Container::roundrobin( Bool :$shortest,
      Bool :$finite, *@@list );

=cut

ok(roundrobin() eqv (), 'roundrobin null identity');

ok(roundrobin(1) eqv (1,), 'roundrobin scalar identity');

ok(roundrobin(1..3) eqv 1..3, 'roundrobin list identity');

ok(roundrobin([1..3]) eqv 1..3, 'roundrobin array identity');

# Next 2 work.  Just waiting on eqv.

ok(roundrobin({'a'=>1,'b'=>2,'c'=>3}) eqv ('a'=>1,'b'=>2,'c'=>3),
    'roundrobin hash identity', :todo<feature>, depends<eqv>);

ok(roundrobin((); 1; 2..4; [5..7]; {'a'=>1,'b'=>2})
    eqv (1, 2, 5, 'a'=>1, 3, 6, 'b'=>2, 4, 7), 'basic roundrobin',
    :todo<feature>, :depends<eqv>);

ok(roundrobin(:shortest, 1; 1..2; 1..3) eqv (1), 'roundrobin :shortest',
    :todo<feature>);

flunk('roundrobin :finite', :todo<feature>, :depends<lazy roundrobin>);

=begin lazy_roundrobin

ok(roundrobin(:finite, 1; 1..2; 1..3) eqv (1), 'roundrobin :shortest',
    :todo<feature>);

=cut
