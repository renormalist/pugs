use v6-alpha;

use Test;

plan 1;

sub func(*@m)
{
    @m.shift;
    return @m;
}


# TEST
is_deeply(func(5), [], "Shift from an array function argument works", :todo<bug>);

