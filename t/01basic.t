#!/usr/bin/pugs

use v6;
require Test;

=kwid

Basic tests.

=cut

plan 17;

ok(1, "Welcome to Pugs!");

sub cool { ok(fine($_), " # We've got " ~ toys) }
sub fine { $_ == 2 }
sub toys { "fun and games!" }

(2).cool;  # and that is it, folks!

my $foo = "Foo";
eval 'undef $foo';
ok(!$foo, 'undef');

my $bar;
unless ($foo) { $bar = "true" }
ok($bar, "unless");

my ($var1, $var2) = ("foo", "bar");
is($var1, "foo", 'list assignment 1');
is($var2, "bar", 'list assignment 2');
todo_ok(eval '(my $quux = 1) == 1)', "my returns LHS");

eval 'if 1 { pass() }' err todo_fail "if without parens";
eval 'for 1 { pass() }' err todo_fail "for without parens";
eval 'while (0) { } pass()' err todo_fail "while";

my $lasttest = 0;
eval 'for (1..10) { $lasttest++; last; $lasttest++; }';
todo_ok($lasttest == 1, "last");

my $nexttest = 0;
eval 'for (1..10) { $nexttest++; next; $nexttest++; }';
todo_ok($lasttest == 10, "next");

print "# ok ";
if (eval '12.print') { print "\n"; pass() } else { print "\n"; todo_fail("12.print"); }

ok(eval 'say(1 ?? "# ok 14" :: "# Bail out!")');

