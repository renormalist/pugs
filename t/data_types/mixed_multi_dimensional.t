#!/usr/bin/pugs

use v6;
require Test;

plan 23;

=pod

This tests some mixed multi-dimensional structures.

NOTE:
These tests don't go any more than two levels deep
(AoH, AoP) in most cases because I know these won't
work yet. 

=cut

{ # Array of Pairs
    my @array;
    isa_ok(@array, 'Array');
    
    my $pair = ('key' => 'value');
    isa_ok($pair, 'Pair');
    
    @array[0] = $pair; # assign a variable
    is(+@array, 1, 'the array has one value in it');
    isa_ok(@array[0], 'Pair');
    eval_is('@array[0]<key>', 'value', 'got the right pair value');

    @array[1] = ('key1', 'value1'); # assign it inline
    is(+@array, 2, 'the array has two values in it');
    isa_ok(@array[1], 'Pair');
    eval_is('@array[1]<key1>', 'value1', 'got the right pair value');
}

{ # Array of Hashes
    my @array;
    isa_ok(@array, 'Array');
    
    my %hash = ('key', 'value', 'key1', 'value1');
    isa_ok(%hash, 'Hash');
    is(+%hash.keys, 2, 'our hash has two keys');
    
    @array[0] = %hash;
    is(+@array, 1, 'the array has one value in it');
    isa_ok(@array[0], 'Hash');
    eval_is('@array[0]{"key"}', 'value', 'got the right value for key');
    eval_is('@array[0]<key1>', 'value1', 'got the right value1 for key1');    
}

{ # Array of Subs
    my @array;
    isa_ok(@array, 'Array');
    
    @array[0] = sub { 1 };
    @array[1] = { 2 };
    @array[2] = -> { 3 };
    
    is(+@array, 3, 'got three elements in the list');
    isa_ok(@array[0], 'Sub');
    isa_ok(@array[1], 'Sub');
    isa_ok(@array[2], 'Sub');        
    
    is(@array[0](), 1, 'the first element (when executed) is 1');
    is(@array[1](), 2, 'the second element (when executed) is 2');    
    is(@array[2](), 3, 'the third element (when executed) is 3');
}
