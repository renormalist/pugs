use v6-alpha;

use Test;

plan 5;

{
    my ($a) = |(1, 2, 3);
    is($a, 1, "(scalar) = |list");
};

{
    my @a = (1, 2, 3);
    my ($b) = |@a;
    is($b, 1, "(scalar) = |array");
};

{
    my $a = (1, 2, 3);
    my $b = |$a;
    is($b, [1, 2, 3], "scalar = |arrayref");
};

{
    my $a = (1, 2, 3);
    my ($b) = |@$a;
    is($b, 1, "(scalar) = |dereffed arrayref");
};

{
    my $a = (1, 2, 3);
    my ($b) = @$a;
    is($b, 1, "(scalar) = dereffed arrayref");
};

=begin END

# splat does not do LHS yet

{
    my :(*$a) := (1, 2, 3);
    is($a, 1, "*scalar := list");
    my @a = (1, 2, 3);
    my :(*$a) := @a;
    is($a, 1, "*scalar := array");
    my :(*$a) := *@a;
    is($a, 1, "*scalar := *array");
    my :(*$a) := [1, 2, 3];
    is($a, [1, 2, 3], "*scalar := arrayref");
};

# splat does not apply to parameter binding yet

{
    my sub foo($foo, @bar) {
        return "$foo, @bar[]";
    };
    
    my @a = (1, [1, 2, 3]);
    is(foo(*@a), "1, 1 2 3", "foo(*(1, [1, 2, 3])) against foo($, @)");    

    @a = (1, 2, 3);
    is(foo(*@a), "1, 2", "foo(*(1, 2, 3)) against foo($, @)");    


};

{
    my sub foo($foo, *@bar) {
        return "$foo, @bar[]";
    };
    
    my @a = (1, [1, 2, 3]);
    is(foo(*@a), "1, 1 2 3", "foo(*(1, [1, 2, 3])) against foo($, *@)");    

    @a = (1, 2, 3);
    is(foo(*@a), "1, 2", "foo(*(1, 2, 3)) against foo($, *@)");    

};


