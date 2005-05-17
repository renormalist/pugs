
use v6;

class Perl::Meta::Method-0.0.1;

has $:code;
has $:signature;
has $:associated_with;

submethod BUILD ($:signature, $:code) {}

method code ($self: Sub ?$code) returns Code {
    $:code = $code if $code.defined;
    return $:code;
}

method signature ($self: Any ?$signature) returns Any {
    # NOTE:
    # we make no assumptions about the structure
    # of a method signature, this field may not 
    # even be used at times.
    $:signature = $signature if $signature.defined;
    return $:signature;
}

method associatedWith ($self: Perl::Meta::Class ?$class) returns Perl::Meta::Class {
    if $class.defined {
        (!$:associated_with.defined)
            || die "This method has already be associated with a something";            
        $:associated_with = $class;
    }
    return $:associated_with;
}

method removeAssociation ($self:) returns Void {
    $:associated_with = undef;
}

=pod

=head1 NAME

Perl::Meta::Method

=head1 SYNOPSIS

  use Perl::Meta::Method;

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<code ($self: Sub ?$code) returns Code>

=item B<signature ($self: Any ?$signature) returns Any>

=item B<associatedWith ($self: Perl::Meta::Class ?$class) returns Perl::Meta::Class>

=item B<removeAssociation ($self:) returns Void>

=back

=head1 AUTHORS

Sam Vilain

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=cut
