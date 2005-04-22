#!/usr/bin/pugs

use v6;
require Test;

=kwid

=head1 Binding tests

These tests are derived from the "Binding" section of Synopsis 3

L<S03/"Binding">

=cut

plan 11;
# force_todo 7;

# L<S03/"Binding" /replaces the container itself.  For instance:/>

my $x = 'Just Another';
is($x, 'Just Another', 'normal assignment works');

my $y := $x;
is($y, 'Just Another', 'y is now bound to x');

todo_ok(eval '$y =:= $x', 'y is bound to x (we checked with the =:= identity op)');

my $z = $x;
is($z, 'Just Another', 'z is not bound to x');

todo_ok(eval '!($z =:= $x)', 'z is not bound to x (we checked with the =:= identity op)');

$y = 'Perl Hacker';
is($y, 'Perl Hacker', 'y has been changed to "Perl Hacker"');
is($x, 'Perl Hacker', 'x has also been changed to "Perl Hacker"');

is($z, 'Just Another', 'z is still "Just Another" because it was not bound to x');

sub bar {
  return $CALLER::a eq $CALLER::b;
}

sub foo {
  my $a = "foo";
  my $b := $a;
  return bar(); # && bar2();
}

ok(foo(), "CALLER resolves bindings in caller's dynamic scope");

# Binding to swap
my $a = "a";
my $b = "b";
($a, $b) := ($b,$a);
is($a, 'b', '$a has been changed to "b"');
is($b, 'a', '$b has been changed to "a"');