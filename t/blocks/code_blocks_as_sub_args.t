use v6-alpha;

use Test;

plan 2;

=pod

Test a bug where sub args of type Sub do not get handled correctly.

=cut

sub foo (Sub $code, Str $a, Str $b) { return $a.WHAT }

is(foo(-> { die "test" }, "a", "b"), ::Str, 'this will die with a "No compatible subroutine found: &foo"');

sub foo2 (Sub $code, Str $a, Str $b?) { return $a.WHAT }

is(foo2(-> { die "test" }, "a", "b"), ::Str, 'this should return "Str"');
