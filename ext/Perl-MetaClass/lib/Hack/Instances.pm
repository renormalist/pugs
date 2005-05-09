
use v6;
module Hack::Instances-0.0.1;

subtype Instance of Str where { $^str ~~ qx:perl5/^OBJECT;/ #:#for cperl-mode
			    }

my %INSTANCES;

sub make_instance($class, $obj) returns Instance is export {
    my $id;
    $id = "OBJECT;$class;" ~ substr(rand() ~ "", 2, 15)
    	until not exists %INSTANCES<$id>;

    %INSTANCES<$id> = $obj;
    return $id;
}

sub make_class($class) is export {
    eval "subtype $class of Instance where \{ "
	~ '$^str ~~ qx:perl5/^OBJECT;' ~ $class ~ ';/ \}';
}

sub get_instance(Instance $inst) returns Hash is export {
    return %INSTANCES<$inst>;
}

=pod

=head1 NAME

Hack::Instances - An abstraction of inside-out classes

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHORS

Sam Vilain

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=cut
