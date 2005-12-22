#!/usr/bin/pugs

use v6;
use Test;

# Referencing various parts of Synopsis 12.

plan 15;

class A {
    trusts B;

    has $!foo;
    has @!bar;
    has %!baz;
}

class B {
    has A $!my_A;

    submethod BUILD () {
        my $an_A = A.new();

        try {
            $an_A!foo = 'hello';
        };
        is( $!.defined ?? 1 !! 0, 0, 'A trusts B, B can set an A scalar attr; '~($!//'') );

        try {
            $an_A!bar = [1,2,3];
        };
        is( $!.defined ?? 1 !! 0, 0, 'A trusts B, B can set an A array attr; '~($!//'') );

        try {
            $an_A!baz = {'m'=>'v'};
        };
        is( $!.defined ?? 1 !! 0, 0, 'A trusts B, B can set an A hash attr; '~($!//'') );

        $!my_A = $an_A;
    }

    method read_from_A() {
        my ($foo, @bar, %baz);

        try {
            $foo = $an_A!foo;
        };
        is( $!.defined ?? 1 !! 0, 0, 'A trusts B, B can get an A scalar attr; '~($!//'') );
        is( $foo, 'hello', 'value read by B from an A scalar var is correct' );

        try {
            @bar = $an_A!bar;
        };
        is( $!.defined ?? 1 !! 0, 0, 'A trusts B, B can get an A array attr; '~($!//'') );
        is_deeply( @bar, [1,2,3], 'value read by B from an A scalar var is correct' );

        try {
            %baz = $an_A!baz;
        };
        is( $!.defined ?? 1 !! 0, 0, 'A trusts B, B can get an A hash attr; '~($!//'') );
        is_deeply( %baz, {'m'=>'v'}, 'value read by B from an A scalar var is correct' );
    }
}

class C {
    has A $!my_A;

    submethod BUILD () {
        my $an_A = A.new();

        try {
            $an_A!foo = 'hello';
        };
        is( $!.defined ?? 1 !! 0, 1, 'A does not trust C, C can not set an A scalar attr; '~($!//'') );

        try {
            $an_A!bar = [1,2,3];
        };
        is( $!.defined ?? 1 !! 0, 1, 'A does not trust C, C can not set an A array attr; '~($!//'') );

        try {
            $an_A!baz = {'m'=>'v'};
        };
        is( $!.defined ?? 1 !! 0, 1, 'A does not trust C, C can not set an A hash attr; '~($!//'') );

        $!my_A = $an_A;
    }

    method read_from_A() {
        my ($foo, @bar, %baz);

        try {
            $foo = $an_A!foo;
        };
        is( $!.defined ?? 1 !! 0, 1, 'A does not trust C, C can not get an A scalar attr; '~($!//'') );

        try {
            @bar = $an_A!bar;
        };
        is( $!.defined ?? 1 !! 0, 1, 'A does not trust C, C can not get an A array attr; '~($!//'') );

        try {
            %baz = $an_A!baz;
        };
        is( $!.defined ?? 1 !! 0, 1, 'A does not trust C, C can not get an A hash attr; '~($!//'') );
    }
}

my $my_B = B.new();
$my_B.read_from_A();

my $my_C = C.new();
$my_C.read_from_A();
