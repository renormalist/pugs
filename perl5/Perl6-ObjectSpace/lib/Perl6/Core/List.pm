
package Perl6::Core::List;

use Perl6::Core::Type;
use Perl6::Core::Num;
use Perl6::Core::Str;
use Perl6::Core::Bit;
use Perl6::Core::Nil;

package list;

use strict;
use warnings;

use Carp 'confess';
use Scalar::Util 'blessed';

use base 'type';

sub new {
    my ($class, @values) = @_;
    (blessed($_) && $_->isa('type'))
        || confess "You must store a native type in a list"
            foreach @values;
    bless \@values => $class;
}

# native conversion
sub to_native { @{(shift)} }

# conversion to other types
sub to_str { (shift)->join(str->new('')) }
sub to_num { (shift)->length             }
sub to_bit { (shift)->length->to_bit     }

# methods ...

sub fetch {
    my ($self, $index) = @_;
    (blessed($index) && $index->isa('num'))
        || confess "Index must be a num type";
    my $val = $self->[$index->to_native];
    # NOTE:
    # if you ask for something which is 
    # not there, then you need to get back
    # a nil value, not just undef
    return nil->new() unless defined $val;
    return $val;
}

sub store {
    my ($self, $index, $value) = @_;
    (blessed($index) && $index->isa('num'))
        || confess "Index must be a num type";
    (blessed($value) && $value->isa('type'))
        || confess "Index must be a native type";            
    $self->[$index->to_native] = $value;
}

sub remove {
    my ($self, $index) = @_;
    (blessed($index) && $index->isa('num'))
        || confess "Index must be a num type";
    # replace the value with a nil type
    $self->[$index->to_native] = nil->new();
}

sub slice {
    my ($self, $start_index, $end_index) = @_;
    ((blessed($start_index) && $start_index->isa('num')) &&
     (blessed($end_index) && $end_index->isa('num')))    
        || confess "Indecies must be a num type";
    list->new(
        # make sure to create any nils we need
        map { defined $_ ? $_ : nil->new() }
        @{$self}[$start_index->to_native .. $end_index->to_native]
    );
}

sub length {
    my $self = shift;
    num->new(scalar(@{$self}));
}

sub elems {
    my $self = shift;
    num->new($#{$self});
}

sub join {
    my ($self, $delimiter) = @_;
    str->new(
        join $delimiter->to_native => 
        map { $_->to_str->to_native } 
        $self->slice(num->new(0), $self->elems)->to_native
    )     
}

1;

__END__

=pod

=head1 NAME

list - the core list type

=cut