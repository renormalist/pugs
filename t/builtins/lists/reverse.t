use v6-alpha;
use Test;
plan 36;

# L<S29/"List"/"=item reverse">

=kwid

Tests for "reverse"

NOTE: "reverse" is no longer context-sensitive.  See S29.

=cut


my @a = reverse(1, 2, 3, 4);
my @e = (4, 3, 2, 1);

is(@a, @e, "list was reversed");

my $a = reverse("foo");
is($a, "oof", "string was reversed");

@a = item(reverse("foo"));
is(@a[0], "oof", 'the string was reversed');
@a = list(reverse("foo"));
is(@a[0], "oof", 'the string was reversed even under list context');

@a = reverse(~("foo", "bar"));
is(@a[0], "rab oof", 'the stringified array was reversed (stringwise)');
@a = list reverse "foo", "bar";
is(+@a, 2, 'the reversed list has two elements');
is(@a[0], "bar", 'the list was reversed properly');

is(@a[1], "foo", 'the list was reversed properly');

{
	my @cxt_log;

	class Foo {
		my @.n;
		method foo () {
			push @cxt_log, want();
			(1, 2, 3)
		}
		method bar () {
			push @cxt_log, want();
			return @.n = do {
				push @cxt_log, want();
				reverse self.foo;
			}
		}
	}

	my @n = do {
		push @cxt_log, want();
		Foo.new.bar;
	};

	is(~@cxt_log, ~("List (Any)" xx 4), "contexts were passed correctly around masak's bug", :todo<bug>);
	is(+@n, 3, "list context reverse in masak's bug");
	is(~@n, "3 2 1", "elements seem reversed");
}

{    
    my @a = "foo";
    my @b = @a.reverse;
    isa_ok(@b, 'List');
    my $b = @a.reverse;
    isa_ok($b, 'List');
    is(@b[0], "foo", 'our list is reversed properly'); 
    is($b, "foo", 'in scalar context it is still a list');
    is(@a[0], "foo", "original array left untouched");
    @a .= reverse;
    is(@a[0], "foo", 'in place reversal works');
}

{
    my @a = ("foo", "bar");
    my @b = @a.reverse;
    isa_ok(@b, 'List');
    my $b = @a.reverse;
    isa_ok($b, 'List');
    is(@b[0], "bar", 'our array is reversed');
    is(@b[1], "foo", 'our array is reversed');
    
    is($b, "bar foo", 'in scalar context it is still a list');
    
    is(@a[0], "foo", "original array left untouched");
    is(@a[1], "bar", "original array left untouched");
    
    @a .= reverse;
    is(@a[0], "bar", 'in place reversal works');
    is(@a[1], "foo", 'in place reversal works');
}

{
    my $a = "foo";
    my @b = $a.reverse;
    isa_ok(@b, 'Array');    
    my $b = $a.reverse;
    isa_ok($b, 'Str');    
    
    is(@b[0], "oof", 'string in the array has been reversed');
    is($b, "oof", 'string has been reversed');
    is($a, "foo", "original scalar left untouched");
    $a .= reverse;
    is($a, "oof", 'in place reversal works on strings');
}

{
    my $a = "foo".reverse;
    my @b = "foo".reverse;
    isa_ok($a, 'Str');
    isa_ok(@b, 'Array');
    is($a, "oof", 'string literal reversal works in scalar context');
    is(@b[0], "oof", 'string literal reversal works in list context');
}
