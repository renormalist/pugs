use v6-alpha;
use Test;
plan 1;

# L<S29/Num/"=item exp">

=pod 

Basic tests for the exp() builtin

=cut

sub is_approx (Num $is, Num $expected, Str $descr) {
  ok abs($is - $expected) <= 0.00001, $descr;
}

is_approx(exp(5), 148.4131591025766, 'got the exponent of 5');
