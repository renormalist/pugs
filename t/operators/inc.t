#!/usr/bin/pugs

use v6;
require Test;

plan 26;

=kwid

Mostly copied from Perl 5.8.4 s t/op/inc.t

Verify that addition/subtraction properly upgrade to doubles.
These tests are only significant on machines with 32 bit longs,
and two s complement negation, but should not fail anywhere.

=cut

my $a = 2147483647;
my $c=$a++;
is($a, 2147483648, "var incremented after post-autoincrement");
is($c, 2147483647, "during post-autoincrement return value is not yet incremented");

$a = 2147483647;
$c=eval '++$a';
is($a, 2147483648, "var incremented  after pre-autoincrement");
is($c, 2147483648, "during pre-autoincrement return value is incremented");

$a = 2147483647;
$a=$a+1;
is($a, 2147483648, 'simple assignment: $a = $a+1');

$a = -2147483648;
$c=$a--;
is($a, -2147483649, "var decremented after post-autodecrement");
is($c, -2147483648, "during post-autodecrement return value is not yet decremented");

$a = -2147483648;
$c=eval '--$a';
is($a, -2147483649, "var decremented  after pre-autodecrement");
is($c, -2147483649, "during pre-autodecrement return value is decremented");

$a = -2147483648;
$a=$a-1;
is($a, -2147483649, 'simple assignment: $a = $a-1');

$a = 2147483648;
$a = -$a;
$c=$a--;
is($a, -2147483649, "post-decrement negative value");

$a = 2147483648;
$a = -$a;
$c=eval '--$a';
is($a, -2147483649, "pre-decrement negative value");

$a = 2147483648;
$a = -$a;
$a=$a-1;
is($a, -2147483649, 'assign $a = -$a; $a = $a-1');

$a = 2147483648;
my $b = -$a;
$c=$b--;
is($b, ((-$a)-1), "commpare -- to -1 op with same origin var");
is($a, 2147483648, "make sure origin var remains unchanged");

$a = 2147483648;
$b = -$a;
$c=eval '--$b';
is($b, ((-$a)-1), "same thing with predecremenet");

$a = 2147483648;
$b = -$a;
$b=$b-1;
is($b, eval '-(++$a)', 'est oder of predecrement in -(++$a)');

$a = undef;
is($a++,'0', 'undef++ == 0');

$a = undef;
is(eval '$a--', undef, 'undef-- is undefined');

$a = 'x';
is($a++, 'x', 'magical ++ should not be numified');
isa_ok($a, "Str", "it isa Str");

my %a = ('a' => 1);
eval '%a{"a"}++';
is(%a{'a'}, 2, "hash key");

my %b = ('b' => 1);
my $var = 'b';
eval '%b{$var}++';
is(%b{$var}, 2, "hash key via var");

my @a = (1);
eval '@a[1]++';
is(@a[0], 2, "array elem");

my @b = (1);
my $moo = 0;
eval '@b[$moo]++';
is(@b[$moo], 2, "array elem via var");
is($moo, 0, "var was not touched");
