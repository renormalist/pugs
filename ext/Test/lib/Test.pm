module Test-0.0.1;
use v6;

my $loop = 0;
my $plan = 0;
my $failed = 0;

sub plan (Int $number_of_tests) returns Int is export {
    $plan = $number_of_tests;
    say "1..$number_of_tests";
    return $number_of_tests;
}

sub proclaim (Bool $cond, Str ?$desc, Str ?$context) returns Bool {
    my $ok := $cond ?? "ok " :: "not ok ";
    my $out := defined($desc) ?? " - $desc" :: "";
    my $context_out := defined($context) ?? " # $context" :: "";
    $loop++;
    say $ok, $loop, $out, $context_out;
    return $cond;
}

sub ok (Bool $cond, Str ?$desc) returns Bool is export {
    proclaim($cond, $desc);
    if (!$cond) {
        $*ERR.say("#     Failed test ($?CALLER::POSITION)");
        $failed++;
    }
    return $cond;
}

sub is (Str $got, Str $expected, Str ?$desc) returns Bool is export {
    my $test := $got eq $expected; 
    proclaim($test, $desc);
    if (!$test) {
        $*ERR.say("#     Failed test ($?CALLER::POSITION)");
        $*ERR.say("#          got: '$got'");
        $*ERR.say("#     expected: '$expected'");
        $failed++;
    }
    return $test;
}

sub isa_ok ($ref, Str $expected_type, Str ?$desc) returns Bool is export {
    my $ref_type = ref($ref);
    my $out := defined($desc) ?? $desc :: "The object is-a '$expected_type'";    
    my $test := $ref_type eq $expected_type;
    proclaim($test, $out);
    if (!$test) {
        $*ERR.say("#     Failed test ($?CALLER::POSITION)");
        $*ERR.say("#          got: '$ref_type'");
        $*ERR.say("#     expected: '$expected_type'");        
        $failed++;
    }
    return $test;
}

sub todo_ok (Bool $cond, Str ?$desc) returns Bool is export {
    proclaim($cond, $desc, "TODO");
    if (!$cond) {
        diag("    Failed (TODO) test ($?CALLER::POSITION)");
    }
    return $cond;
}

sub todo_is (Str $got, Str $expected, Str ?$desc) returns Bool is export {
    my $test = $got eq $expected;
    proclaim($test, $desc, "TODO");
    if (!$test) {
        diag("    Failed (TODO) test ($?CALLER::POSITION)");
        diag("         got: '$got'");
        diag("    expected: '$expected'");
    }
    return $test;
}

sub todo_isa_ok ($ref, Str $expected_type, Str ?$desc) returns Bool is export {
    my $ref_type = ref($ref);
    my $out := defined($desc) ?? $desc :: "The object is-a '$expected_type'";         
    my $test := $ref_type eq $expected_type;
    proclaim($test, $out, "TODO");
    if (!$test) {
        diag("    Failed (TODO) test ($?CALLER::POSITION)");
        diag("         got: '$ref_type'");
        diag("    expected: '$expected_type'");        
    }
    return $test;
}

sub skip (Str ?$reason) returns Bool is export {
    proclaim(1, "", "skip $reason");
    return 1;
}

sub pass (Str ?$desc) returns Bool is export {
    proclaim(1, $desc);
    return 1;
}

sub fail (Str ?$desc) returns Bool is export {
    proclaim(0, $desc);
    diag("    Failed test ($?CALLER::POSITION)");
    return 0;
}

sub todo_fail (Str ?$desc) returns Bool is export {
    proclaim(0, $desc, 'TODO');
    diag("    Failed (TODO) test ($?CALLER::POSITION)");
    return 0;
}

sub diag (Str $diag) is export {
    for (split("\n", $diag)) -> $line {
		say "# $line";
	}
}

END {
    if (!$plan) {
        say("1..$loop");
    } else {
        if ($plan != $loop) {
	    $*ERR.say("# Looks like you planned $plan tests, but ran $loop");
        }
    }
    if ($failed) {
        $*ERR.say("# Looks like you failed $failed tests of $loop");
    }
}

=kwid

= NAME

Test - Test support module for perl6

= SYNOPSIS

  use v6;
  require Test;
  
  plan 8;
  
  ok(2 + 2 == 4, '2 and 2 make 4');
  is(2 + 2, 4, '2 and 2 make 4');
  isa_ok([1, 2, 3], 'List');
  
  todo_ok(2 + 2 == 5, '2 and 2 make 5');
  todo_is(2 + 2, 5, '2 and 2 make 5');  
  todo_isa_ok({'one' => 1}, 'Hash');
  
  pass('This test passed');
  fail('This test failed');

  skip('skip this test for now');
  
  todo_fail('this fails, but might work soon');
  
  diag('some misc comments and documentation');

= DESCRIPTION

This module was built to facilitate the Pugs test suite. It has the 
distinction of being the very first module written for Pugs. 

It provides a simple set of common test utility functions, and is 
an implementation of the TAP protocol.

This module, like Pugs, is a work in progress. As new features are 
added to Pugs, new test functions will be defined to facilitate the
testing of those features. For more information see the FUTURE PLANS 
section of this document.

= FUNCTIONS

* `plan (Int $number_of_tests) returns Int`

All tests need a plan. A plan is simply the number of tests which are
expected to run. This should be specified at the very top of your tests.

== Testing Functions

* `ok (Bool $cond, Str ?$desc) returns Bool` 

* `is (Str $got, Str $expected, Str ?$desc) returns Bool`

* `isa_ok ($ref, Str $expected_type, Str ?$desc) returns Bool`

This function currently on checks with ref() since we do not yet have
object support. Once object support is created, we will add it here, and 
maintain backwards compatibility as well.

== TODO Testing functions

Sometimes a test is broken because something is not implemented yet. So 
in order to still allow that to be tested, and those tests to knowingly
fail, we provide a set of todo_* functions for all the basic test 
functions.

* `todo_ok (Bool $cond, Str ?$desc) returns Bool`

* `todo_is (Str $got, Str $expected, Str ?$desc) returns Bool`

* `todo_isa_ok ($ref, Str $expected_type, Str ?$desc) returns Bool`

== Misc. Functions

* `skip (Str ?$reason) returns Bool`

If for some reason a test is to be skipped, you can use this function to do so.

* `pass (Str ?$desc) returns Bool`

Sometimes what you need to test does not fit into one of the standard testing 
functions. In that case, you can use the rather blunt pass() functions and its
compliment the fail() function.

* `fail (Str ?$desc) returns Bool`

This is the opposite of pass()

* `todo_fail (Str ?$desc) returns Bool`

On occasion, one of these odd tests might fail, but actually be a TODO item. So 
we give you todo_fail() for just such an occasion.

* `diag (Str $diag)`

This will print each string with a '#' character appended to it, this is ignored
by the TAP protocol.

= FUTURE PLANS

This module is still a work in progress. As Pugs grows, so will it's testing needs.
This module will be the code support for those needs. The following is a list of
future features planned for this module.

* is_deeply

Once nested data structures are implemented, we will need an easy way to test them. 
So we will implement the Test::More function is_deeply. The plan currently is to 
implement this as a mutually recursive multi-sub which will be able to handle 
structures of arbitrary depth and of an arbitrary type. The function signatures 
will likely look something like this:

  multi sub is_deeply (Array @got, Array @expected, Str ?$desc) returns Bool;  
  multi sub is_deeply (List  $got, List  $expected, Str ?$desc) returns Bool;    
  multi sub is_deeply (Hash  %got, Hash  %expected, Str ?$desc) returns Bool;      
  multi sub is_deeply (Pair  $got, Pair  $expected, Str ?$desc) returns Bool;  
  
Because these functions will be mutually recursive, they will easily be able handle 
arbitrarily complex data structures automatically (at least that is what I hope).

* like

This is similar to the Test::More like() function. It will take a regular expression
reference and compare it with a given string.

* throws_ok, lives_ok

These are functions taken directly from Test::Exception. They will accept a block to 
execute and then either an Exception type, a reg-exp or a string to match against the 
error.

= SEE ALSO

The Perl 5 Test modules

* Test

* Test::More

Information about the TAP protocol can be found in the Test::Harness distribution.

= AUTHORS

Aurtrijus Tang <autrijus@autrijus.org>

Benjamin Smith

Norman Nunley

Steve Peters

Stevan Little <stevan@iinteractive.com>

Brian Ingerson <ingy@cpan.org>

= COPYRIGHT

Copyright (c) 2005. Autrijus Tang. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
