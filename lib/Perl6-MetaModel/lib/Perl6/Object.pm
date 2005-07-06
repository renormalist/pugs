
package Perl6::Object;

use strict;
use warnings;

use Perl6::MetaClass;

use Scalar::Util 'blessed';
use Carp 'croak';

# the default .new()

sub new {
    my ($class, %params) = @_;
    return $class->bless(undef, %params);
}

# but this is what really constructs the class

sub bless : method {
    my ($class, $canidate, %params) = @_;
    $canidate ||= 'P6opaque'; # opaque is our default
    my $instance_structure = $class->CREATE(repr => $canidate, %params);
    # XXX - We do this because we are in Perl5, this 
    # should not be how the real metamodel behave 
    # at least I dont think it is how it should :)
    my $self = CORE::bless($instance_structure, $class);
    $self->BUILDALL(%params);
    return $self;
}

## Submethods (hacked here for now)

sub CREATE {
    my ($class, %params) = @_;
    ($params{repr} eq 'P6opaque') 
        || croak "Sorry, No other types other than 'P6opaque' are currently supported";    
    
    # this just gathers all the 
    # attributes that were defined
    # for the instances.
    my %attrs;
    $class->meta->traverse_post_order(sub {
        my $c = shift;
        foreach my $attr ($c->get_attribute_list) {
            my $attr_obj = $c->get_attribute($attr);
            $attrs{$attr} = $attr_obj->instantiate_container;
        }
    }); 
    
    # this is our P6opaque data structure
    # it's nothing special, but it works :)
    return {
        class         => $class->meta,
        instance_data => \%attrs,
    };         
}

sub BUILDALL {
    my ($self, %params) = @_;
    # XXX - hack here to call Perl6::Object::BUILD
    $self->Perl6::Object::BUILD(%params);
    # then we post order traverse the rest of the class
    # hierarchy. This will all be fixed when Perl6::Object
    # is properly bootstrapped
    $self->meta->traverse_post_order(sub {
        my $c = shift;
        $c->get_method('BUILD')->call($self, %params) if $c->has_method('BUILD');        
    });    
}

sub BUILD {
    my ($self, %params) = @_;
    $self->set_value($_ => $params{$_}) foreach keys %params;
}

sub DESTROYALL {
    my ($self) = @_;
    $self->meta->traverse_pre_order(sub {
        my $c = shift;
        $c->get_method('DESTROY')->call($self) if $c->has_method('DESTROY');        
    });      
}

## end Submethods

## XXX - all the methods below are called automajicaly by 
## Perl5, so we need to handle them here in order to control
## the metamodels functionality

sub isa {
    my ($self, $class) = @_;
    return undef unless $class;
    return $self->meta->is_a($class);
}

sub can {
    my ($self, $label) = @_;
    if (blessed($self)) {
        return $self->meta->responds_to($label);
    }
    else {
        return $self->meta->responds_to($label, for => 'Class');
    }
}

sub AUTOLOAD {
    my $label = (split '::', our $AUTOLOAD)[-1];
    return if $label =~ /DESTROY/;
    my $self = shift;
    my @return_value;
    if (blessed($self)) {
        my $method;
        if ($label eq 'SUPER') {
            $label = shift;
            $method = $self->meta->find_method_in_superclasses($label);
        }
        else {
            $method = $self->meta->find_method($label);
        }
        (blessed($method) && $method->isa('Perl6::Method')) 
            || croak "Method ($label) not found for instance ($self)";
        @return_value = $method->call($self, @_);        
    }
    else {
        my $method = $self->meta->find_method($label, for => 'Class');

        (defined $method) 
            || croak "Method ($label)  not found for class ($self)";
        @return_value = $method->call($self, @_);
    }
    return wantarray ?
                @return_value
                :
                $return_value[0];
}

# this just dispatches to the DESTROYALL
# which deals with things correctly
sub DESTROY {
    my ($self) = @_;
    $self->DESTROYALL();
}

## Perl6 metamodel methods and misc. support 
## methods for our Perl5 version

sub get_class_value {
    my ($self, $label) = @_;
    my $prop = $self->meta->find_attribute_spec($label, for => 'Class')
        || croak "Cannot locate class property ($label) in class ($self)";
    $prop->get_value();
}

sub set_class_value {
    my ($self, $label, $value) = @_;
    my $prop = $self->meta->find_attribute_spec($label, for => 'Class')
        || croak "Cannot locate class property ($label) in class ($self)";
    $prop->set_value($value);
}

sub get_value {
    my ($self, $label) = @_;
    $self->{instance_data}->{$label};
}

sub set_value {
    my ($self, $label, $value) = @_;
    my $prop = $self->meta->find_attribute_spec($label)
        || croak "Perl6::Attribute ($label) no found";

    # since we are not private, then check the type
    # assuming there is one to check ....
    if (my $type = $prop->type()) {
        if ($prop->is_array()) {
            (blessed($_) && ($_->isa($type) || $_->does($type))) 
                || croak "IncorrectObjectType: expected($type) and got($_)"
                    foreach @$value;                        
        }
        else {
            (blessed($value) && ($value->isa($type) || $value->does($type))) 
                || croak "IncorrectObjectType: expected($type) and got($value)";                        
        }
    }  
    else {
        (ref($value) eq 'ARRAY') 
            || croak "You can only asssign an ARRAY ref to the label ($label)"
                if $prop->is_array();
        (ref($value) eq 'HASH') 
            || croak "You can only asssign a HASH ref to the label ($label)"
                if $prop->is_hash();
    }                      

    # We are doing a 'binding' here by linking the $value into the $label
    # instead of storing into the container object available at $label
    # with ->store().  By that time the typechecking above will go away
    $self->{instance_data}->{$label} = $value;
}

my $META;
sub meta {
    my ($class) = @_;
    $class = blessed($class) if blessed($class);       
    no strict 'refs';
    ${$class .'::META'} ||= Perl6::MetaClass->new(name => $class);
}

1;

__END__

=pod

=head1 NAME

Perl6::Object

=head1 DESCRIPTION

This is the base 'Object' class. It will eventually be self-hosting, but for now
it contains a number of hacks to support the expected behavior of the Perl6 object
model.

=head1 AUTHOR

Stevan Little stevan@iinteractive.com
Autrijus Tang autrijus@autrijus.org

=cut
