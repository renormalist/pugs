#!/usr/bin/pugs

use v6;
use Test;

# XXX - this needs to be updated when Str.split(Str) works again
plan 54;

# split on an empty string

my %ords = (
  1 => 'first',
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  5 => 'fifth',
  6 => 'sixth',
  7 => 'seventh',
  8 => 'eighth',
  9 => 'ninth',
);

sub split_test(@splitted, @expected, Str $desc, ?$todo = 0) {
  is +@splitted, +@expected,
     "split created the correct value amount for: $desc", $todo;
  is @splitted[$_], @expected[$_],
     "the %ords{$_ + 1} value matched for: $desc", $todo
    for 0 .. @splitted.end;
}

split_test split("", "forty-two"),
           qw/f o r t y - t w o/,
           q{split "", Str};

# split on a space
split_test split(' ', 'split this string'),
           qw/split this string/,
           q{split ' ', Str};

# split on a single character delimiter
split_test split('$', 'try$this$string'),
           qw/try this string/,
           q{split '$', Str};

# split on a multi-character delimiter
split_test split(', ', "comma, separated, values"),
           qw/comma separated values/,
           q{split ', ', Str};

# split on a variable delimiter

my $delimiter = '::';
split_test split($delimiter, "Perl6::Pugs::Test"),
           qw/Perl6 Pugs Test/,
           q{split $delimiter, Str};

# split with a reg-exp
split_test split(rx:perl5{,}, "split,me"),
           qw/split me/,
           q(split rx:perl5{,}, Str);

# split on multiple space characters
split_test split(rx:perl5{\s+}, "Hello World    Goodbye   Mars"),
           qw/Hello World Goodbye Mars/,
           q(split rx:perl5{\s+}, Str);

split_test split(rx:perl5{(\s+)}, "Hello test"),
           ('Hello', ' ', 'test'),
           q/split rx:perl5{(\s+)}, Str/;

split_test "to be || ! to be".split(' '),
           qw/to be || ! to be/,
           q/Str.split(' ')/;

split_test "this will be split".split(rx:perl5{ }),
           qw/this will be split/,
           q/Str.split(rx:perl5{ })/;

# split on multiple space characters
try {
split_test split(rx:perl5{\s+}, "Hello World    Goodbye   Mars", 3),
           [ qw/Hello World/, "Goodbye   Mars" ],
           q(split rx:perl5{\s+}, Str, limit);
};
if ($!) {
    fail "couldn't split with limit; $!", :todo<feature> for 1..2;
}

try {
split_test split(" ", "Hello World    Goodbye   Mars", 3),
           [ qw/Hello World/, "   Goodbye   Mars" ],
           q(split " ", Str, limit);
};
if ($!) {
    fail "couldn't split with limit; $!", :todo<feature> for 1..2;
}

