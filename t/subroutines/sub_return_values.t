#!/usr/bin/pugs

use v6;
use Test;

=pod

This tests proper return of values from subroutines.

L<S06/"Subroutines">

=cut

plan 55;

# These test the returning of values from a subroutine. 
# We test each data-type with 4 different styles of return. 
#
# The datatypes are:
#     Scalar
#     Array
#     Array-ref (aka List)
#     Hash
#     Hash-ref
#
# The 4 return styles are:
#     create a variable, and return it with the return statement
#     create a variable, and make it the last value in the sub (implied return)
#     create the value inline and return it with the return statement
#     create the value inline and make it the last value in the sub (implied return)    
#
# NOTE: 
# we do not really check return context here. That should be 
# in it's own test file

# TODO-NOTE: 
# Currently the Hash and Hash-ref tests are not complete, becuase hashes seem to be 
# broken in a number of ways. I will get back to those later.

## void
eval_ok('sub ret { return }', "return without value ok", :todo(1));

## scalars

sub foo_scalar {
    my $foo = 'foo';
    return $foo;
}
is(foo_scalar(), 'foo', 'got the right return value');

# ... w/out return statement

sub foo_scalar2 {
    my $foo = 'foo';
    $foo;
}
is(foo_scalar2(), 'foo', 'got the right return value');

# ... returning constant

sub foo_scalar3 {
    return 'foo';
}
is(foo_scalar3(), 'foo', 'got the right return value');

# ... returning constant w/out return statement

sub foo_scalar4 {
    'foo';
}
is(foo_scalar4(), 'foo', 'got the right return value');

## arrays

sub foo_array {
    my @foo = ('foo', 'bar', 'baz');
    return @foo;
}
my @foo_array_return = foo_array();
isa_ok(@foo_array_return, 'Array');
is(+@foo_array_return, 3, 'got the right number of return value');
is(@foo_array_return[0], 'foo', 'got the right return value');
is(@foo_array_return[1], 'bar', 'got the right return value');
is(@foo_array_return[2], 'baz', 'got the right return value');

# ... without the last return statement

sub foo_array2 {
    my @foo = ('foo', 'bar', 'baz');
    @foo;
}
my @foo_array_return2 = foo_array2();
isa_ok(@foo_array_return2, 'Array');
is(+@foo_array_return2, 3, 'got the right number of return value');
is(@foo_array_return2[0], 'foo', 'got the right return value');
is(@foo_array_return2[1], 'bar', 'got the right return value');
is(@foo_array_return2[2], 'baz', 'got the right return value');

# ... returning an Array constructed "on the fly"

sub foo_array3 {
    return ('foo', 'bar', 'baz');
}
my @foo_array_return3 = foo_array3();
isa_ok(@foo_array_return3, 'Array');
is(+@foo_array_return3, 3, 'got the right number of return value');
is(@foo_array_return3[0], 'foo', 'got the right return value');
is(@foo_array_return3[1], 'bar', 'got the right return value');
is(@foo_array_return3[2], 'baz', 'got the right return value');

# ... returning an Array constructed "on the fly" w/out return statement

sub foo_array4 {
    ('foo', 'bar', 'baz');
}
my @foo_array_return4 = foo_array4();
isa_ok(@foo_array_return4, 'Array');
is(+@foo_array_return4, 3, 'got the right number of return value');
is(@foo_array_return4[0], 'foo', 'got the right return value');
is(@foo_array_return4[1], 'bar', 'got the right return value');
is(@foo_array_return4[2], 'baz', 'got the right return value');

## Array Refs aka - Lists

sub foo_array_ref {
   my $foo = ['foo', 'bar', 'baz'];
   return $foo;
}
my $foo_array_ref_return = foo_array_ref();
isa_ok($foo_array_ref_return, 'List'); 
is(+$foo_array_ref_return, 3, 'got the right number of return value'); 
is($foo_array_ref_return[0], 'foo', 'got the right return value'); 
is($foo_array_ref_return[1], 'bar', 'got the right return value'); 
is($foo_array_ref_return[2], 'baz', 'got the right return value'); 

# ... w/out the return statement

sub foo_array_ref2 {
   my $foo = ['foo', 'bar', 'baz'];
   $foo;
}
my $foo_array_ref_return2 = foo_array_ref2();
isa_ok($foo_array_ref_return2, 'List');
is(+$foo_array_ref_return2, 3, 'got the right number of return value');
is($foo_array_ref_return2[0], 'foo', 'got the right return value');
is($foo_array_ref_return2[1], 'bar', 'got the right return value');
is($foo_array_ref_return2[2], 'baz', 'got the right return value');

# ... returning list constructed "on the fly"

sub foo_array_ref3 {
   return ['foo', 'bar', 'baz'];
}
my $foo_array_ref_return3 = foo_array_ref3();
isa_ok($foo_array_ref_return3, 'List'); 
is(+$foo_array_ref_return3, 3, 'got the right number of return value'); 
is($foo_array_ref_return3[0], 'foo', 'got the right return value'); 
is($foo_array_ref_return3[1], 'bar', 'got the right return value'); 
is($foo_array_ref_return3[2], 'baz', 'got the right return value'); 

# ... returning list constructed "on the fly" w/out return statement

sub foo_array_ref4 {
   ['foo', 'bar', 'baz'];
}
my $foo_array_ref_return4 = foo_array_ref4();
isa_ok($foo_array_ref_return4, 'List');
is(+$foo_array_ref_return4, 3, 'got the right number of return value');
is($foo_array_ref_return4[0], 'foo', 'got the right return value');
is($foo_array_ref_return4[1], 'bar', 'got the right return value');
is($foo_array_ref_return4[2], 'baz', 'got the right return value');

## hashes

sub foo_hash {
    my %foo = ('foo', 1, 'bar', 2, 'baz', 3);
    return %foo;
}

my %foo_hash_return = foo_hash(); 
isa_ok(%foo_hash_return, 'Hash');
is(+%foo_hash_return.keys, 3, 'got the right number of return value'); 
is(%foo_hash_return<foo>, 1, 'got the right return value'); 
is(%foo_hash_return<bar>, 2, 'got the right return value'); 
is(%foo_hash_return<baz>, 3, 'got the right return value'); 

# now hash refs 

sub foo_hash_ref {
    my %foo = ( 'foo', 1, 'bar', 2, 'baz', 3 );
    return \%foo;
}

my $foo_hash_ref_return = foo_hash_ref();
isa_ok($foo_hash_ref_return, 'Hash'); 
is(+$foo_hash_ref_return.keys, 3, 'got the right number of return value'); 
is($foo_hash_ref_return<foo>, 1, 'got the right return value');
is($foo_hash_ref_return<bar>, 2, 'got the right return value'); 
is($foo_hash_ref_return<baz>, 3, 'got the right return value'); 


