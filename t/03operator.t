#!/usr/bin/pugs

use v6;
require Test;

plan 22;

my $str1 = "foo";
my $str2 = "bar";
my $str3 = "foobar";
my $str4 = $str1~$str2;

is($str3, $str4, "~");

my $bar = "";
($str3 eq $str4) ?? $bar = 1 :: $bar = 0;

ok($bar, "?? ::");

my $five = 5;
my $four = 4;
my $wibble = 4;

ok(!($five == $four), "== (false)");
ok($wibble == $four, "== (true)");
ok(!($wibble != $four), "== (false)");
ok($five != $four, "!= (true)");

ok($five == 5, "== (const on rhs)");
ok(!($five != 5), "!= (const on rhs)");

ok(5 == $five, "== (const on lhs)");
ok(!(5 != $five), "!= (const on lhs)");

ok($five == (2 + 3), "== (sum on rhs)");
ok(!($five != (2 + 3)), "== (sum on rhs)");

is(2 + 3, $five, "== (sum on lhs)");
ok((2 + 3) == 5, "== (sum on lhs)");
ok(!((2 + 3) != $five), "== (sum on lhs)");

# String Operations
is("text " ~ "stitching", "text stitching", 'concationation with ~ operator');

# Bit Stitching

is(2 || 3, 2, "|| returns first true value");
todo_is(eval '2 ?| 3', 1, "boolean or (?|) returns 0 or 1");
ok(!(defined( 0 || undef)), "|| returns last false value of list?");
todo_is(eval '0 ?| undef', 0, "boolean or (?|) returns 0 or 1");

#junctions

ok(all((4|5|6) + 3) == one(7|8|9), "all elements in junction are incremented");

# Hyper ops

skip("waiting for hyper operators");
#is_deeply eval '(1,2,3,4) >>+<< (1,2,3,4)' , (2,4,6,8), 'hyper-add';
