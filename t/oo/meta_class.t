use v6-alpha;

use Test;

plan 9;

=pod

Very basic meta-class tests from L<S12/"Introspection">

=cut

class Foo-0.0.1 { method bar ($param) returns Str { return "baz" ~ $param } };

# L<S12/"Introspection" /should be called through the meta object\:/>

eval_ok("Foo.META.can('bar')", '... Foo can bar', :todo<feature>);
eval_ok("Foo.META.isa(Foo)", '... Foo is-a Foo (of course)');

# L<S12/"Introspection" /Class traits may include\:/>

eval_ok("Foo.META.name() eq 'Foo'", '... the name() property is Foo');
eval_ok("Foo.META.version() == 0.0.1", '... the version() property is 0.0.1', :todo<feature>);
eval_ok("(Foo.META.isa())[0] ~~ Foo", '... the isa() property returns Foo as the first parent class', :todo<feature>);

# L<S12/"Introspection" /The C\<\.META\.getmethods\> method returns method-descriptors containing:/>

# NOTE: I am guessing on some of this here, but it's a start for now

my @methods = eval 'Foo.META.getmethods()';
eval_is("@methods[0].name eq 'bar'", '... our first method is foo()', :todo<feature>);
eval_is("@methods[0].signature eq '\$param'", '... our first methods signature is $param', :todo<feature>);
eval_is("@methods[0].returns ~~ Str", '... our first method returns a Str', :todo<feature>);
eval_ok("!@methods[0].multi", '... our first method is not a multimethod', :todo<feature>);

