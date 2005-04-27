#!/usr/bin/pugs

use v6;
use Test;

plan 4;

ok(eval 'my Int $foo; 1', 'compile my Int $foo', :todo);
ok(eval 'my Str $bar; 1', 'compile my Str $bar', :todo);

ok(eval 'my Int $foo; ref $foo == Int', 'Int $foo isa Int', :todo);
ok(eval 'my Str $bar; ref $bar == Str', 'Str $bar isa Str', :todo);
