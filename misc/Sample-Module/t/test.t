use v6-alpha;
require Test;
require Sample::Module-0.0.1;

=kwid

Test Sample::Module

=cut

plan 1;

is(greeting('pugs'), 'hello, pugs');
