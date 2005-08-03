
package Perl6::Class;

use strict;
use warnings;

use Carp 'confess';
use Scalar::Util 'blessed';

use Perl6::Instance; # << this is where the Perl 5 sugar is now ...

use Perl6::MetaClass;
use Perl6::Role;

use Perl6::SubMethod;

use Perl6::Class::Attribute;
use Perl6::Class::Method;

use Perl6::Instance::Attribute;
use Perl6::Instance::Method;

## Private methods

sub new {
    my ($class, $name, $params) = @_;
    my $self = bless { 
        name   => $name,
        meta   => undef
    }, $class;
    _validate_params($self, $params);
    return $self;
}

# return the metaclass instance associated with
# this class object. This is not really right, 
# but it will do for now
sub meta { (shift)->{meta} }

sub _apply_class_to_environment {
    my ($self) = @_;
    my ($name, $version, $authority) = _get_class_meta_information($self);
    my $code = qq|
        package $name;
        \@$name\:\:ISA = 'Perl6::Instance';
        
        \$$name\:\:META = undef;
        sub meta { \$$name\:\:META }
        
        1;
    |;
    eval $code || confess "Could not initialize class '$name'";   
    my $meta; 
    eval {
        if ($name eq 'Perl6::Object') {
            # XXX - Perl6::Object cannot call the 
            # regular new() becuase Perl6::MetaClass
            # actually inherits new() from Perl6::Object
            # meta-circulatiry rules :P
            $meta = Perl6::MetaClass::new(
                '$.name' => $name,
                (defined $version   ? ('$.version'   => $version)   : ()),
                (defined $authority ? ('$.authority' => $authority) : ())                              
            );  
        }
        else {
            $meta = ::dispatch('Perl6::MetaClass', 'new', (
                '$.name' => $name,
                (defined $version   ? ('$.version'   => $version)   : ()),
                (defined $authority ? ('$.authority' => $authority) : ())                              
            ));
        }
    };
    confess "Could not initialize the metaclass for $name : $@" if $@;
    eval {
        no strict 'refs';    
        ${"${name}::META"} = $meta;          
        $self->{meta} = $meta;
        *{$self->{name} . '::'} = *{$name . '::'};
    };
    confess "Could not create full name " . $self->name . " : $@" if $@;    
    _build_class($self, $meta);    
}

sub _validate_params {
    my ($self, $params) = @_;

    my %allowed = map { $_ => undef } qw(is does instance class);
    my %allowed_in = map { $_ => undef } qw(attrs BUILD DESTROY methods submethods);

    foreach my $key (keys %{$params}) {
        confess "Invalid key ($key) in params" 
            unless exists $allowed{$key};
        if ($key eq 'class' || $key eq 'instance') {
            foreach my $sub_key (keys %{$params->{$key}}) {
                confess "Invalid sub_key ($sub_key) in key ($key) in params" 
                    unless exists $allowed_in{$sub_key};                
            }
        }
    }

    $self->{params} = $params;
}

sub _get_class_meta_information {
    my ($self) = @_;
    my $identifier = $self->{name};
    # shortcut for classes with no extra meta-info
    return ($identifier, undef, undef) if $identifier !~ /\-/;
    # XXX - this will actually need work, 
    # but it is sufficient for now.
    return split '-' => $identifier;
}

sub _build_class {
    my ($self, $meta) = @_;

    my $name = ::dispatch($meta, 'name');

    my $superclasses = $self->{params}->{is};
    ::dispatch($meta, 'superclasses', ([ map { $_->meta } @{$superclasses} ]));        

    if (my $instance = $self->{params}->{instance}) {

        ::dispatch($meta, 'add_method', ('BUILD' => Perl6::SubMethod->new($name => $instance->{BUILD})))
            if exists $instance->{BUILD};            
        ::dispatch($meta, 'add_method', ('DESTROY' => Perl6::SubMethod->new($name => $instance->{DESTROY})))
            if exists $instance->{DESTROY};
            
        if (exists $instance->{methods}) {
            foreach (keys %{$instance->{methods}}) {
                if (/^_/) {
                    ::dispatch($meta, 'add_method', ($_ => Perl6::PrivateMethod->new($name, $instance->{methods}->{$_})));
                }
                else {
                    ::dispatch($meta, 'add_method', ($_ => Perl6::Instance::Method->new($name, $instance->{methods}->{$_})));
                }
            }
        }
        if (exists $instance->{submethods}) {
            ::dispatch($meta, 'add_method', ($_ => Perl6::SubMethod->new($name, $instance->{submethods}->{$_})))
                foreach keys %{$instance->{submethods}};
        }        
        if (exists $instance->{attrs}) {
            foreach my $attr (@{$instance->{attrs}}) {
                my $props;
                if (ref($attr) eq 'ARRAY') {
                    ($attr, $props) = @{$attr}; 
                }
                ::dispatch($meta, 'add_attribute', (
                    $attr => Perl6::Instance::Attribute->new($name => $attr, $props)
                ));              
            }
        }        
    }
    if (my $class = $self->{params}->{class}) {  
        
        if (exists $class->{attrs}) {
            foreach my $attr (@{$class->{attrs}}) {
                my $props;
                if (ref($attr) eq 'ARRAY') {
                    ($attr, $props) = @{$attr}; 
                }
                ::dispatch($meta, 'add_attribute', (
                    $attr => Perl6::Class::Attribute->new($name => $attr, $props)
                ));
            }            

        }
        if (exists $class->{methods}) {
            foreach my $label (keys %{$class->{methods}}) {
                if ($label =~ /^_/) {
                    ::dispatch($meta, 'add_method', ($label => Perl6::PrivateMethod->new($name, $class->{methods}->{$label})));
                }
                else {
                    ::dispatch($meta, 'add_method', ($label => Perl6::Class::Method->new($name, $class->{methods}->{$label})));
                }
            }
        }
    }


    Perl6::Role->flatten_roles_into($meta, @{$self->{params}->{does}})
        if $self->{params}->{does};
}


1;

__END__

=pod

=head1 NAME

Perl6::Class 

=head1 SYNOPSIS

    my $foo_class = Perl6::Class->new('Foo' => {
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
        }
    );
    $foo_class->apply(); # this injects the Class into the Object environment

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<new ($name, \%params)>

=item B<name>

=item B<apply>

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=cut
