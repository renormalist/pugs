module fp-0.0.1;

# Function composition
sub infix:<o> (Code &f, Code &g) { sub($x) { f g $x } }

# Haskell `...` metaoperator
sub infix:<`map`>  (Code &f, *@y) { map &f, @y }
sub infix:<`grep`> (Code &f, *@y) { grep &f, @y }


=head1 NAME

fp - Functional programming for Perl 6

=head1 SYNOPSIS

  use fp;

  (&say o &int)(10/3);               # 3
  { $_ % 2 == 0 } `grep` [1,2,3,4];  # [2,4]
  { $_ * 2 } `map` [1,2,3];          # [2,4,6]

=head1 DESCRIPTION

This is an experimental module which eases the use of functional programming
techniques in Perl 6.

=head1 OVERLOADED OPERATORS

=head2 C<< infix:<o> (Code &f, Code &g) >>

Function composition. Think of Haskell's C<.>.

=head2 C<< infix:<`map`> (Code &f, *@y) >>

=head2 C<< infix:<`grep`> (Code &f, *@y) >>

Infix versions of C<map> and C<grep>.

These will go when we can define own metaoperators (like C<[...]> or C<»...«>).
Then, all functions can be "infixized".

=head1 BUGS

This module is currently somewhat short, additions welcome! :)

=head1 AUTHOR

Ingo Blechschmidt E<lt>iblech@web.deE<gt>

=cut
