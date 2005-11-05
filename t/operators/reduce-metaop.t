#!/usr/bin/pugs

use v6;
use Test;

=head1 DESCRIPTION

This test tests the C<[...]> reduce metaoperator.

Reference:
L<"http://groups.google.de/group/perl.perl6.language/msg/bd9eb275d5da2eda">

=cut

plan 36;

# [...] reduce metaoperator
{
  my @array = <5 -3 7 0 1 -9>;
  my $sum   = 5 + -3 + 7 + 0 + 1 + -9; # laziness :)

  is(([+] *@array),      $sum, "[+] works");
  is(([*]  1,2,3),    (1*2*3), "[*] works");
  is(([-]  1,2,3),    (1-2-3), "[-] works");
  is(([/]  12,4,3),  (12/4/3), "[/] works");
  is(([**] 2,2,3),  (2**2**3), "[**] works");
}

{
  is ([~] <a b c d>), "abcd", "[~] works";
}

ok (    [<]  1, 2, 3, 4), "[<] works (1)";
ok (not [<]  1, 3, 2, 4), "[<] works (2)";
ok (    [>]  4, 3, 2, 1), "[>] works (1)";
ok (not [>]  4, 2, 3, 1), "[>] works (2)";
ok (    [==] 4, 4, 4),    "[==] works (1)";
ok (not [==] 4, 5, 4),    "[==] works (2)";
ok (    [!=] 4, 5, 6),    "[!=] works (1)";
ok (not [!=] 4, 4, 4),    "[!=] works (2)";

{
  my @array = (undef, undef, 3, undef, 5);
  is ([//]  *@array), 3, "[//] works";
  is ([err] *@array), 3, "[err] works";
}

{
  my @array = (undef, undef, 0, 3, undef, 5);
  is ([||] *@array), 3, "[||] works";
  is ([or] *@array), 3, "[or] works";
}

{
  my $hash = {a => {b => {c => {d => 42, e => 23}}}};
  is try { [.{}] $hash, <a b c d> }, 42, '[.{}] works';
}

{
  my $hash = {a => {b => 42}};
  is ([.{}] $hash, <a b>), 42, '[.{}] works two levels deep';
}

{
  my $arr = [[[1,2,3],[4,5,6]],[[7,8,9],[10,11,12]]];
  is ([.[]] $arr, 1, 0, 2), 9, '[.[]] works';
}

{
  # 18:45 < autrijus> hm, I found a way to easily do linked list consing in Perl6
  # 18:45 < autrijus> [=>] 1..10;
  my $list = [=>] 1,2,3;
  is $list.key,              1, "[=>] works (1)";
  is try{$list.value.key},   2, "[=>] works (2)";
  is try{$list.value.value}, 3, "[=>] works (3)";
}

{
  my @array = <5 -3 7 0 1 -9>;
  is ([,] @array), @array, "[,] works (a noop)";
}

# Following two tests taken verbatim from former t/operators/reduce.t
lives_ok({my @foo = [1..3] >>+<< [1..3] >>+<< [1..3]},'Sanity Check');
lives_ok({my @foo = [>>+<<] ([1..3],[1..3],[1..3])},'Parse [>>+<<]');

# Check that user defined infix ops work with [...], too.
sub infix:<more_than_plus>(Int $a, Int $b) { $a + $b + 1 }
is(([more_than_plus] 1, 2, 3), 8, "[...] reduce metaop works on user defined ops");

{
  my $arr = [ 42, [ 23 ] ];
  $arr[1][1] = $arr;

  is ([.[]] $arr, 1, 1, 1, 1, 1, 0), 23, '[.[]] works with infinite data structures';
}

{
  my $hash = {a => {b => 42}};
  $hash<a><c> = $hash;

  is ([.{}] $hash, <a c a c a b>), 42, '[.{}] works with infinite data structures';
}

{
  my ($a, $b);

  eval_ok '[=] $a, $b, 3', '[=] evaluates successfully';
  is($a, 3, '[=] assigns successfully (1)');
  is($b, 3, '[=] assigns successfully (2)');

  eval_ok '([=] $a, $b, 3) = 5', '[=] lvalue context restored (1)';
  is($a, 5, '[=] lvalue context restored (2)');
  is($b, 3, '[=] lvalue context restored (3)');
}

