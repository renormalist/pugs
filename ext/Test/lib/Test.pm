module Test-0.0.5;
use v6;

### GLOBALS

# globals to keep track of our tests
my $NUM_OF_TESTS_RUN    = 0; 
my $NUM_OF_TESTS_FAILED = 0;
my $NUM_OF_TESTS_PLANNED;

# some options available through the environment
my $ALWAYS_CALLER = %ENV<TEST_ALWAYS_CALLER>;

# a Junction to hold our FORCE_TODO tests
my $FORCE_TODO_TEST_JUNCTION;

### FUNCTIONS

## plan

sub plan (Int $number_of_tests) returns Void is export {
    $NUM_OF_TESTS_PLANNED = $number_of_tests;
    say "1..$number_of_tests";
}

sub force_todo (*@todo_tests) returns Void is export {
     $FORCE_TODO_TEST_JUNCTION = any(@todo_tests);
}

## ok

sub ok (Bool $cond, Str +$desc, Bool +$todo) returns Bool is export {
    proclaim($cond, $desc, $todo ?? 'TODO' :: undef);
}

## is

sub is (Str $got, Str $expected, Str +$desc, Bool +$todo) returns Bool is export {
    my $test := $got eq $expected;
    proclaim($test, $desc, $todo ?? 'TODO' :: undef, $got, $expected);
}

## isnt

sub isnt (Str $got, Str $expected, Str +$desc, Bool +$todo) returns Bool is export {
    my $test := not($got eq $expected);
    proclaim($test, "FAILS by matching expected: $desc", $todo ?? 'TODO' :: undef, $got, $expected);
}

## like

sub like (Str $got, Rule $expected, Str +$desc, Bool +$todo) returns Bool is export {
    my $test := $got ~~ $expected;
    proclaim($test, $desc, $todo ?? 'TODO' :: undef, $got, $expected);
}

## unlike

sub unlike (Str $got, Rule $expected, Str +$desc, Bool +$todo) returns Bool is export {
    my $test := not($got ~~ $expected);
    proclaim($test, $desc, $todo ?? 'TODO' :: undef, $got, $expected);
}

## eval_ok

sub eval_ok (Str $code, Str +$desc, Bool +$todo) returns Bool is export {
    my $result := eval $code;
    if ($!) {
	    proclaim(undef, $desc, $todo ?? 'TODO' :: undef, "eval was fatal");
    }
    else {
        #diag "'$desc' was non-fatal and maybe shouldn't use eval_ok()";
	    &ok.goto($result, $desc, $todo);
    }
}

## eval_is

sub eval_is (Str $code, Str $expected, Str +$desc, Bool +$todo) returns Bool is export {
    my $result := eval $code;
    if ($!) {
	    proclaim(undef, $desc, $todo ?? 'TODO' :: undef, "eval was fatal", $expected);
    }
    else {
        #diag "'$desc' was non-fatal and maybe shouldn't use eval_is()";
	    &is.goto($result, $expected, $desc, $todo);
    }
}

## cmp_ok

sub cmp_ok (Str $got, Code $compare_func, Str $expected, Str +$desc, Bool +$todo) returns Bool is export {
    my $test := $compare_func($got, $expected);
    proclaim($test, $desc, $todo ?? 'TODO' :: undef); # << needs better error message handling
}

## isa_ok

sub isa_ok ($ref is rw, Str $expected_type, Str +$desc, Bool +$todo) returns Bool is export {
    my $out := defined($desc) ?? $desc :: "The object is-a '$expected_type'";
    my $test := $ref.isa($expected_type);
    proclaim($test, $out, $todo ?? 'TODO' :: undef, $ref.ref, $expected_type);
}

## use_ok

sub use_ok (Str $module, Bool +$todo) is export {
    eval "require $module";
    if ($!) {
	    proclaim(undef, "require $module;", $todo ?? 'TODO' :: undef, "Import error when loading $module: $!");
    }
    else {
        &ok.goto(1, "$module imported OK", $todo);
    }
}

## throws ok

sub throws_ok (Sub $code, Any $match, Str +$desc, Bool +$todo) returns Bool is export {
    try { $code() };
    if ($!) {
        &ok.goto($! ~~ $match, $desc, $todo);            
    }
    else {
	    proclaim(undef, $desc, $todo ?? 'TODO' :: undef, "No exception thrown");
    }
}

## dies_ok

sub dies_ok (Sub $code, Str +$desc, Bool +$todo) returns Bool is export {
    try { $code() };
    if ($!) {
        &ok.goto(1, $desc, $todo);
    }
    else {
	    proclaim(undef, $desc, $todo ?? 'TODO' :: undef, "No exception thrown");
    }
}

## lives ok

sub lives_ok (Sub $code, Str +$desc, Bool +$todo) returns Bool is export {
    try { $code() };
    if ($!) {
        proclaim(undef, $desc, $todo ?? 'TODO' :: undef, "An exception was thrown : $!");
    }
    else {
        &ok.goto(1, $desc, $todo);
    }
}

## misc. test utilities

multi sub skip (Str ?$reason) returns Bool is export {
    proclaim(1, "", "skip $reason");
}

multi sub skip (Int $count, Str $reason) returns Bool is export {
    for (1 .. $count) {
        skip $reason;
    }
}

sub skip_rest (Str ?$reason) returns Bool is export {
    skip($NUM_OF_TESTS_PLANNED - $NUM_OF_TESTS_RUN, $reason // "");
}

sub pass (Str +$desc) returns Bool is export {
    proclaim(1, $desc);
}

sub fail (Str +$desc, Bool +$todo) returns Bool is export {
    proclaim(0, $desc, $todo ?? 'TODO' :: undef);
}

sub diag (Str $diag) is export {
    for (split("\n", $diag)) -> $line {
	    say "# $line";
    }
}

## 'private' subs

sub proclaim (Bool $cond, Str ?$desc, Str ?$c, Str ?$got, Str ?$expected) returns Bool {
    my $context = $c; # no C<is rw> yet
    $NUM_OF_TESTS_RUN++;

    # Check if we have to forcetodo this test 
    # because we're preparing for a release.
    $context = "TODO for release" if $NUM_OF_TESTS_RUN == $FORCE_TODO_TEST_JUNCTION;

    my $ok := $cond ?? "ok " :: "not ok ";
    my $out = defined($desc) ?? " - $desc" :: "";
    $out = "$out <pos:$?CALLER::CALLER::POSITION>" if $ALWAYS_CALLER;

    my $context_out = defined($context) ?? " # $context" :: "";

    say $ok, $NUM_OF_TESTS_RUN, $out, $context_out;

    report_failure($context, $got, $expected) unless $cond;

    return $cond;
}

sub report_failure (Str ?$todo, Str ?$got, Str ?$expected) returns Bool {
    if ($todo) {
        diag("  Failed ($todo) test ($?CALLER::CALLER::CALLER::POSITION)");
    }
    else {
	    diag("  Failed test ($?CALLER::CALLER::CALLER::POSITION)");
        $NUM_OF_TESTS_FAILED++;
    }

    if ($?CALLER::CALLER::SUBNAME eq ('&is' | '&isnt' | '&cmp_ok' | '&eval_is' | '&isa_ok' | '&todo_is' | '&todo_isnt' | '&todo_cmp_ok' | '&todo_eval_is' | '&todo_isa_ok')) {
        diag("  Expected: " ~ ($expected.defined ?? $expected :: "undef"));
        diag("       Got: " ~ ($got.defined ?? $got :: "undef"));
    }
    else {
        diag("       Got: " ~ ($got.defined ?? $got :: "undef"));
    }
}



END {
    if (!defined($NUM_OF_TESTS_PLANNED)) {
        say("1..$NUM_OF_TESTS_RUN");
    }
    elsif ($NUM_OF_TESTS_PLANNED != $NUM_OF_TESTS_RUN) {
	    $*ERR.say("# Looks like you planned $NUM_OF_TESTS_PLANNED tests, but ran $NUM_OF_TESTS_RUN");
    }

    if ($NUM_OF_TESTS_FAILED) {
        $*ERR.say("# Looks like you failed $NUM_OF_TESTS_FAILED tests of $NUM_OF_TESTS_RUN");
    }
}

## begin deprecated TODO functions
 
sub todo_ok (Bool $cond, Str ?$desc) returns Bool is export {
    proclaim($cond, $desc, 'TODO');
}

sub todo_is (Str $got, Str $expected, Str ?$desc) returns Bool is export {
    my $test = $got eq $expected;
    proclaim($test, $desc, 'TODO', $got, $expected);
}

sub todo_isnt (Str $got, Str $expected, Str ?$desc) returns Bool is export {
    my $test := not($got eq $expected);
    proclaim($test, "SHOULD FAIL: $desc", 'TODO', $got, $expected);
}

sub todo_like (Str $got, Rule $expected, Str ?$desc) returns Bool is export {
    my $test := $got ~~ $expected;
    proclaim($test, $desc, 'TODO', $got, $expected);
}

sub todo_unlike (Str $got, Rule $expected, Str ?$desc) returns Bool is export {
    my $test := not($got ~~ $expected);
    proclaim($test, $desc, 'TODO', $got, $expected);
}

sub todo_eval_ok (Str $code, Str ?$desc) returns Bool is export {
    my $result := eval $code;
    if ($!) {
	    proclaim(undef, $desc, 'TODO', "eval was fatal");
    }
    else {
	    &todo_ok.goto($result, $desc);
    }
}

sub todo_eval_is (Str $code, Str $expected, Str ?$desc) returns Bool is export {
    my $result := eval $code;
    if ($!) {
        proclaim(undef, $desc, 'TODO', "was fatal", $expected);
    }
    else {
        #diag "'$desc' was non-fatal and maybe shouldn't use todo_eval_is()";
        &todo_is.goto($result, $expected, $desc);
    }
}

sub todo_cmp_ok (Str $got, Code $compare_func, Str $expected, Str ?$desc) returns Bool is export {
    my $test := $compare_func($got, $expected);
    proclaim($test, $desc, 'TODO', 4, 5); # << needs better error message handling
}

sub todo_isa_ok ($ref is rw, Str $expected_type, Str ?$desc) returns Bool is export {
    my $out := defined($desc) ?? $desc :: "The object is-a '$expected_type'";
    my $test := $ref.isa($expected_type);
    proclaim($test, $out, 'TODO', $ref.ref, $expected_type);
}

sub todo_use_ok (Str $module) is export {
    eval "require $module";
    if ($!) {
	    proclaim(undef, "require $module;", 'TODO', "Import error when loading $module: $!");
    }
    else {
        &todo_ok.goto(1, "$module imported OK");
    }
}

sub todo_throws_ok (Sub $code, Any $match, Str ?$desc) returns Bool is export {
    try { $code() };
    if ($!) {
        &todo_ok.goto($! ~~ $match, $desc);
    }
    else {
	    proclaim(undef, $desc, 'TODO', "No exception thrown");
    }
}

sub todo_dies_ok (Sub $code, Str ?$desc) returns Bool is export {
    try { $code() };
    if ($!) {
        &todo_ok.goto(1, $desc);
    }
    else {
	    proclaim(undef, $desc, 'TODO', "No exception thrown");
    }
}

sub todo_lives_ok (Sub $code, Str ?$desc) returns Bool is export {
    try { $code() };
    if ($!) {
        proclaim(undef, $desc, 'TODO', "An exception was thrown : $!");
    }
    else {
        &todo_ok.goto(1, $desc);
    }
}

sub todo_fail (Str ?$desc) returns Bool is export {
    proclaim(0, $desc, 'TODO');
}

## end deprecated TODO functions

=kwid

= NAME

Test - Test support module for perl6

= SYNOPSIS

  use v6;
  require Test;

  plan 10;
  test_log_file('test.log');

  use_ok('Some::Module');
  todo_use_ok('Some::Other::Module');

  ok(2 + 2 == 4, '2 and 2 make 4');
  is(2 + 2, 4, '2 and 2 make 4');
  isa_ok([1, 2, 3], 'List');

  todo_ok(2 + 2 == 5, '2 and 2 make 5');
  todo_is(2 + 2, 5, '2 and 2 make 5');
  todo_isa_ok({'one' => 1}, 'Hash');

  use_ok('My::Module');

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

- `plan (Int $number_of_tests) returns Void`

All tests need a plan. A plan is simply the number of tests which are
expected to run. This should be specified at the very top of your tests.

- `force_todo (*@todo_tests) returns Void`

If you have some tests which you would like to force into being TODO tests
then you can pass them through this function. This is primarily a release
tool, but can be useful in other contexts as well. 

== Testing Functions

- `use_ok (Str $module) returns Bool`

*NOTE:* This function currently uses `require()` since Pugs does not yet have
a proper `use()` builtin.

- `ok (Bool $cond, Str ?$desc) returns Bool`

- `is (Str $got, Str $expected, Str ?$desc) returns Bool`

- `isnt (Str $got, Str $expected, Str ?$desc) returns Bool`

- `like (Str $got, Rule $expected, Str ?$desc) returns Bool is export`
- `unlike (Str $got, Rule $expected, Str ?$desc) returns Bool is export`

These functions should work with most reg-exps, but given that they are still a
somewhat experimental feature in Pugs, it is suggested you don't try anything
too funky.

- `cmp_ok (Str $got, Code $compare_func, Str $expected, Str ?$desc) returns Bool`

This function will compare `$got` and `$expected` using `$compare_func`. This will
eventually allow Test::More-style cmp_ok() though the following syntax:

  cmp_ok('test', &infix:<gt>, 'me', '... testing gt on two strings');

However the `&infix:<gt>` is currently not implemented, so you will have to wait
a little while. Until then, you can just write your own functions like this:

  cmp_ok('test', sub ($a, $b) { ?($a gt $b) }, 'me', '... testing gt on two strings');

- `isa_ok ($ref, Str $expected_type, Str ?$desc) returns Bool`

This function currently on checks with ref() since we do not yet have
object support. Once object support is created, we will add it here, and
maintain backwards compatibility as well.

- `eval_ok (Str $code, Str ?$desc) returns Bool`

- `eval_is (Str $code, Str $expected, Str ?$desc) returns Bool`

These functions will eval a code snippet, and then pass the result to is or ok
on success, or report that the eval was not successful on failure.

- `throws_ok (Sub $code, Any $expected, Str ?$desc) returns Bool`

This function takes a block of code and runs it. It then smart-matches (`~~`) any `$!` 
value with the `$expected` value.

- `dies_ok (Sub $code, Str ?$desc) returns Bool`

- `lives_ok (Sub $code, Str ?$desc) returns Bool`

These functions both take blocks of code, run the code, and test whether they live or die.

== TODO Testing functions

Sometimes a test is broken because something is not implemented yet. So
in order to still allow that to be tested, and those tests to knowingly
fail, we provide a set of todo_* functions for all the basic test
functions.

- `todo_use_ok(Str $module) returns Bool`

- `todo_ok (Bool $cond, Str ?$desc) returns Bool`

- `todo_is (Str $got, Str $expected, Str ?$desc) returns Bool`

- `todo_isnt (Str $got, Str $expected, Str ?$desc) returns Bool`

- `todo_like (Str $got, Rule $expected, Str ?$desc) returns Bool is export`

- `todo_unlike (Str $got, Rule $expected, Str ?$desc) returns Bool is export`

- `todo_cmp_ok (Str $got, Code $compare_func, Str $expected, Str ?$desc) returns Bool`

- `todo_isa_ok ($ref, Str $expected_type, Str ?$desc) returns Bool`

- `todo_eval_ok (Str $code, Str ?$desc) returns Bool`

- `todo_eval_is (Str $code, Str $expected, Str ?$desc) returns Bool`

- `todo_throws_ok (Sub $code, Any $expected, Str ?$desc) returns Bool`

- `todo_dies_ok (Sub $code, Str ?$desc) returns Bool`

- `todo_lives_ok (Sub $code, Str ?$desc) returns Bool`

You can use `t/force_todo` to set the tests which should get a temporary
`todo_`-prefix because of release preparation. See `t/force_todo` for more
information.

== Misc. Functions

- `skip (Str ?$reason) returns Bool`
- `skip (Int $count, Str ?$reason) returns Bool`

If for some reason a test is to be skipped, you can use this
function to do so.

- `pass (Str ?$desc) returns Bool`

Sometimes what you need to test does not fit into one of the standard
testing functions. In that case, you can use the rather blunt pass()
functions and its compliment the fail() function.

- `fail (Str ?$desc) returns Bool`

This is the opposite of pass()

- `todo_fail (Str ?$desc) returns Bool`

On occasion, one of these odd tests might fail, but actually be a TODO
item. So we give you todo_fail() for just such an occasion.

- `diag (Str $diag)`

This will print each string with a '#' character appended to it, this is
ignored by the TAP protocol.

= FUTURE PLANS

This module is still a work in progress. As Pugs grows, so will it's
testing needs. This module will be the code support for those needs. The
following is a list of future features planned for this module.

- better error handling for cmp_ok

The error handling capabilities need to be expanded more to handle the
error reporting needs of the cmp_ok() function.

- is_deeply

Once nested data structures are implemented, we will need an easy way
to test them. So we will implement the Test::More function is_deeply.
The plan currently is to implement this as a mutually recursive multi-
sub which will be able to handle structures of arbitrary depth and of
an arbitrary type. The function signatures will likely look something
like this:

  multi sub is_deeply (Array @got, Array @expected, Str ?$desc) returns Bool;
  multi sub is_deeply (List  $got, List  $expected, Str ?$desc) returns Bool;
  multi sub is_deeply (Hash  %got, Hash  %expected, Str ?$desc) returns Bool;
  multi sub is_deeply (Pair  $got, Pair  $expected, Str ?$desc) returns Bool;

Because these functions will be mutually recursive, they will easily be
able handle arbitrarily complex data structures automatically (at least
that is what I hope).

= ENVIRONMENT

Setting the environment variable TEST_ALWAYS_CALLER to force Test.pm to always
append the caller information to the test's `$desc`.

= SEE ALSO

The Perl 5 Test modules

- Test

- Test::More

Information about the TAP protocol can be found in the Test::Harness
distribution.

= AUTHORS

Aurtrijus Tang <autrijus@autrijus.org>

Benjamin Smith

Norman Nunley

Steve Peters

Stevan Little <stevan@iinteractive.com>

Brian Ingerson <ingy@cpan.org>

Jesse Vincent <jesse@bestpractical.com>

Yuval Kogman <nothingmuch@woobling.org>

Nathan Gray <kolibrie@graystudios.org>

Max Maischein <corion@cpan.org>

Ingo Blechschmidt <iblech@web.de>

= COPYRIGHT

Copyright (c) 2005. Autrijus Tang. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
