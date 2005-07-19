
package Perl6::MetaModel;

use strict;
use warnings;

use Scalar::Util 'blessed';
use Carp 'confess';

use Perl6::Role;
use Perl6::Class;
use Perl6::Object;

sub import {
    shift;
    return if @_; # return if anything is passed    
    no strict 'refs';
    
    my $caller_pkg = caller();
    
    # method dispatch handlers
    *{$caller_pkg . '::next_METHOD'} = \&next_METHOD;
    *{$caller_pkg . '::WALKMETH'}    = \&WALKMETH;
    *{$caller_pkg . '::WALKCLASS'}   = \&WALKCLASS;    
    
    # meta model helpers
    *{$caller_pkg . '::class'} = \&class;
    *{$caller_pkg . '::role'}  = \&role;
    
    # variable substitution
    *{$caller_pkg . '::SELF'}  = \&SELF;
    *{$caller_pkg . '::CLASS'} = \&CLASS; 
    
    # instance attribute access
    *{$caller_pkg . '::_'} = \&_; 
    # class attribute access
    *{$caller_pkg . '::__'} = \&__; 
}


## this just makes sure to clear the invocant when
## something dies, it is not pretty, but it works
$SIG{'__DIE__'} = sub { 
    @Perl6::Method::CURRENT_INVOCANT_STACK = (); 
    @Perl6::Method::CURRENT_CLASS_STACK    = ();     
    @Perl6::Object::CURRENT_DISPATCHER     = ();
    CORE::die @_; 
};

sub __ {
    my ($label, $value) = @_;
    my $class = CLASS();
    my $prop = $class->meta->find_attribute_spec($label, for => 'Class')
        || confess "Cannot locate class property ($label) in class ($class)";    
    $prop->set_value($value) if defined $value;    
    $prop->get_value();    
}

sub _ {
    my ($label, $value) = @_;
    my $self = SELF();
    if (defined $value) {
        my $prop = $self->meta->find_attribute_spec($label)
            || confess "Perl6::Attribute ($label) no found";
        # since we are not private, then check the type
        # assuming there is one to check ....
        if (my $type = $prop->type()) {
            if ($prop->is_array()) {
                (blessed($_) && ($_->isa($type) || $_->does($type))) 
                    || confess "IncorrectObjectType: expected($type) and got($_)"
                        foreach @$value;                        
            }
            else {
                (blessed($value) && ($value->isa($type) || $value->does($type))) 
                    || confess "IncorrectObjectType: expected($type) and got($value)";            
            }
        }  
        else {
            (ref($value) eq 'ARRAY') 
                || confess "You can only asssign an ARRAY ref to the label ($label)"
                    if $prop->is_array();
            (ref($value) eq 'HASH') 
                || confess "You can only asssign a HASH ref to the label ($label)"
                    if $prop->is_hash();
        }                      
        # We are doing a 'binding' here by linking the $value into the $label
        # instead of storing into the container object available at $label
        # with ->store().  By that time the typechecking above will go away
        $self->{instance_data}->{$label} = $value;         
    }
    # now return it ...
    $self->{instance_data}->{$label};
}

sub next_METHOD {
    my ($dispatcher, $label, $self, @args) = @{$Perl6::Object::CURRENT_DISPATCHER[-1]};             
    my $method = WALKMETH($dispatcher, $label); 
    return $method->call($self, @args);    
}

sub WALKMETH {
    my ($dispatcher, $label, %opts) = @_;
    my $current;
    while ($current = $dispatcher->next()) {
        last if $current->has_method($label, %opts);
    }
    return unless blessed($current) && $current->isa('Perl6::MetaClass');
    return $current->get_method($label, %opts);
}

sub WALKCLASS {
    my ($dispatcher, %opts) = @_;
    return $dispatcher->next();
}

sub SELF {
    (@Perl6::Method::CURRENT_INVOCANT_STACK)
        || confess "You cannot call \$?SELF from outside of a MetaModel defined Instance method";
    $Perl6::Method::CURRENT_INVOCANT_STACK[-1];     
}

sub CLASS {
    (@Perl6::Method::CURRENT_CLASS_STACK)
        || confess "You cannot call \$?CLASS from outside of a MetaModel defined method";
    $Perl6::Method::CURRENT_CLASS_STACK[-1];     
}

sub role {
    my ($name, $role) = @_;
    Perl6::Role->add_role($name, $role);
}

sub class {
    my ($name, $params) = @_;
    my $class = Perl6::Class->new($name, $params);
    $class->apply();
}

1;

__END__

=pod

=head1 NAME

Perl6::MetaModel - Perl 5 Prototype of the Perl 6 Metaclass model

=head1 SYNOPSIS

    use Perl6::MetaModel;

    role MyRole => {
        methods => {
            test => sub { print 'MyRole::test' }
        }
    };

    class 'MyClass-0.0.1-cpan:JRANDOM' => {
        is => [ 'MyBaseClass' ],
        does => [ 'MyRole' ],
        class => {
            methods => {
                a_class_method => sub { ... }
            }
        },
        instance => {
            attrs => [ '$.foo' ],
            BUILD => sub {
                my ($self) = @_;
                $self->set_value('$.foo' => 'Foo::Bar');
            },
            methods => {
                tester => sub {
                    my ($self) = shift;
                    $self->test(); # call the role method
                    print $self->get_value('$.foo');
                }
            }
        }
    };

    my $c = MyClass->new();
    # or 
    my $c = 'MyClass-0.0.1-cpan:JRANDOM'->new();
    
    $c->foo('Testing 1 2 3');

    $c->tester();

=head1 DESCRIPTION

This set of modules is a prototype for the Perl 6 Metaclass model, which is the
model which descibes the interactions of classes, objects and roles in the Perl
6 object space. 

I am prototyping this in Perl 5 as part of the Perl 6 -> PIL compiler to run on
a Perl5 VM.  It is currently in the early stages of a refactoring from the
original which was just a hacked together prototype. 

=head1 EXPORTED FUNCTIONS

These functions are exported and are thin wrappers around the Perl6::Class and Perl6::Role
modules to make class/role construction easier.

=over 4

=item B<class>

=item B<role>

=back

=head1 SEE ALSO

=over 4

=item All the Perl 6 documentation. 

In particular the Apocolypse and Synopsis 12 which describes the object system.

=item L<Class::Role>, L<Class::Roles> & L<Class::Trait>

The first two are early attempts to prototype role behavior, and the last is an implementation
of the Trait system based on the paper which originally inspired Roles.

=item Any good Smalltalk book.

I prefer the Brown book by Adele Goldberg and David Robinson, but any one which talks about the
smalltalk metaclasses is a good reference.

=item CLOS

The Common Lisp Object System has a very nice meta-model, and plently of reference on it. In 
particular there is a small implementation of CLOS called TinyCLOS which is very readable (if 
you know enough Scheme that is)

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=cut


