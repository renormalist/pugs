
package Kwid::DOM;
use strict;
use warnings;
use Kwid::Base -Base;

use base 'Kwid::Emitter';
use base 'Kwid::Receiver';

use Kwid::DOM::Node;
use Kwid::DOM::Element;
use Kwid::DOM::PI;
use Kwid::DOM::Text;

=head1 NAME

Kwid::DOM - Represent a Kwid document, DOM-style

=head1 SYNOPSIS

 $kwoc = new Kwid::DOM();

 my $body = $kwoc->root();
 my @next = $body->daughters();

 my $node = $kwoc->klink("S09#//para/");  # KLINK lookup

=head1 DESCRIPTION

This document is written in a new dialect of English, called
Kwinglish.

A Kwid::DOM is a directed acyclic graph, which is a Computer
Scientist's way of saying "tree" (cue: the Fast Show "aliens that say
'tree' skit").

=head1 CREATING A Kwid::DOM TREE

C<Kwid::DOM> trees are seldom created using the C<Tree::DAG_Node>
interface.

Normally, they will be constructed as a series of events fired in by a
L<Kwid::Emitter>, such as another L<Kwid::DOM>, a
L<Kwid::Preprocessor>, or a L<Kwid::Parser>.

=cut

field 'root';  # is "Kwid::DOM::Element"

sub new {
    my $class = ref $self || $self;

    $self = super;

    $self->root(Kwid::DOM::Element->new({name => "pod"}));

    return $self;
}

sub emit_to {

}

1;

