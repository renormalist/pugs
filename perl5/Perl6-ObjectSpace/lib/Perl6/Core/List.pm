
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
    return nil->new();
}

sub remove {
    my ($self, $index) = @_;
    (blessed($index) && $index->isa('num'))
        || confess "Index must be a num type";
    # replace the value with a nil type
    $self->[$index->to_native] = nil->new();
    return nil->new();
}

sub slice {
    my ($self, $start_index, $end_index) = @_;
    ((blessed($start_index) && $start_index->isa('num')) &&
     (blessed($end_index) && $end_index->isa('num')))    
        || confess "Indecies must be a num type";
    return list->new(
        # make sure to create any nils we need
        map { defined $_ ? $_ : nil->new() }
        @{$self}[$start_index->to_native .. $end_index->to_native]
    );
}

sub length {
    my $self = shift;
    return num->new(scalar(@{$self}));
}

sub elems {
    my $self = shift;
    return num->new($#{$self});
}

sub is_empty {
    my $self = shift;
    @{$self} ? bit->new(0) : bit->new(1);
}

sub join {
    my ($self, $delimiter) = @_;
    (blessed($delimiter) && $delimiter->isa('str'))
        || confess "delimiter must be a string type";    
    return str->new(
        CORE::join $delimiter->to_native => 
        map { $_->to_str->to_native } 
        $self->slice(num->new(0), $self->elems)->to_native
    )     
}

# some of the common list operations

sub head { @{$_[0]}[0] }
sub tail { list->new(@{$_[0]}[1 .. $#{$_[0]}]) }

sub shift   : method { CORE::shift(@{(shift)}) }
sub pop     : method { CORE::pop(@{(shift)})   }

sub unshift : method { 
    my $self = shift;
    (blessed($_) && $_->isa('type'))
        || confess "you can only add types to a list"
            foreach @_;
    CORE::unshift(@{$self} => @_); 
    nil->new();
}

sub push : method { 
    my $self = shift;
    (blessed($_) && $_->isa('type'))
        || confess "you can only add types to a list got($_) => " . (CORE::join ", " => @_)
            foreach @_;
    CORE::push(@{$self} => @_); 
    nil->new();
}

sub reverse {
    my $self = shift;
    list->new(CORE::reverse(@{$self}));
}

## list iterators

sub each : method {
    my ($self, $closure) = @_;
    (blessed($closure) && ($closure->isa('closure') || $closure->isa('block')))
        || confess "argument to &each must be either a closure or a block";
    foreach my $val (@{$self}) {
        if ($closure->isa('closure')) {
            my $ref = reference->new($val);            
            $closure->do(list->new($ref));
            $val = $ref->fetch;            
        }
        elsif ($closure->isa('block')) {
            my $ref = reference->new($val);  
            $closure->env->set('$_' => $ref);          
            $closure->do();
            $val = $ref->fetch;            
        }
    }
    return nil->new();
}

sub apply {
    my ($self, $closure) = @_;
    (blessed($closure) && ($closure->isa('closure') || $closure->isa('block')))
        || confess "argument to &apply must be either a closure or a block";    
    my $list = list->new();
    foreach my $val (@{$self}) {
        if ($closure->isa('closure')) {
            $list->push(
                $closure->do(
                    list->new($val)
                )
            );            
        }
        elsif ($closure->isa('block')) {
            $closure->env->set('$_' => $val);          
            $list->push($closure->do());      
        }
    }    
    return $list;
}

1;

__END__

=pod

=head1 NAME

list - the core list type

=head1 METHODS

=over 4

=item B<new (@x of ~type) returns list>

=item B<to_native () returns *native*>

=item B<to_bit () returns bit>

=item B<to_num () returns num>

=item B<to_str () returns str>

=item B<fetch (num) returns ~type>

=item B<store (num, ~type) returns nil>

=item B<remove (num) returns nil>

=item B<slice (num, num) returns list>

=item B<length () returns num>

=item B<elem () returns num>

=item B<join (?str) returns str>

=item B<each (closure) return nil>

The closure here will be passed a reference to the current value, 
this allows r/w access to the value.

=item B<apply (closure) return list>

The closure here will be passed the current value itself, which means 
you it is essentially read-only, however, all the return values of the
closure are collected into another list which is then returned from 
this function.

=back

=cut