use v6-alpha;

# External packages used by packages in this file, that don't export symbols:
use Locale::KeyedText-(1.72.0...);
use Rosetta-(0.722.0...);

###########################################################################
###########################################################################

# Constant values used by packages in this file:
my Str $EMPTY_STR is readonly = q{};

###########################################################################
###########################################################################

module Rosetta::Shell-0.1.3 {

    # External packages used by the Rosetta::Shell module, that do export symbols:
    # (None Yet)

    # State variables used by the Rosetta::Shell module:
    my Locale::KeyedText::Translator $translator;
    my Rosetta::Interface::DBMS      $dbms;

###########################################################################

sub main (Str :$engine_name!, Str :@user_lang_prefs? = 'en') {

    $translator .= new(
        set_names    => [
                'Rosetta::Shell::L::',
                'Rosetta::L::',
                'Rosetta::Model::L::',
                'Locale::KeyedText::L::',
                $engine_name ~ '::L::',
            ],
        member_names => @user_lang_prefs,
    );

    _show_message( Locale::KeyedText::Message.new(
        msg_key => 'ROS_S_HELLO' ) );

    try {
        $dbms = Rosetta::Interface::DBMS.new(
            engine_name => $engine_name );
    };
    if ($!) {
        _show_message( Locale::KeyedText::Message.new(
            msg_key  => 'ROS_S_DBMS_INIT_FAIL',
            msg_vars => {
                'ENGINE_NAME' => $engine_name,
            },
        ) );
    }
    else {
        _show_message( Locale::KeyedText::Message.new(
            msg_key  => 'ROS_S_DBMS_INIT_SUCCESS',
            msg_vars => {
                'ENGINE_NAME' => $engine_name,
            },
        ) );
        _command_loop();
    }

    _show_message( Locale::KeyedText::Message.new(
        msg_key => 'ROS_S_GOODBYE' ) );

    return;
}

###########################################################################

my sub _command_loop () {
#    INPUT_LINE:
    while (1) {
        _show_message( Locale::KeyedText::Message.new(
            msg_key => 'ROS_S_PROMPT' ) );

        my Str $user_input = =$*IN;

        # user simply hits return on an empty line to quit the program
#        last INPUT_LINE
        last
            if $user_input eq $EMPTY_STR;

        try {
            _show_message( Locale::KeyedText::Message.new(
                msg_key => 'ROS_S_TODO_RESULT' ) );
        };
        _show_message( $! )
            if $!; # input error, detected by library
    }

    return;
}

###########################################################################

my sub _show_message (Locale::KeyedText::Message $message!) {
    my Str $user_text = $translator.translate_message( $message );
    if (!$user_text) {
        $*ERR.print( "internal error: can't find user text for a message:"
            ~ "\n$message$translator" ); # note: the objects will stringify
        return;
    }
    $*OUT.say( $user_text );
    return;
}

###########################################################################

} # module Rosetta::Shell

###########################################################################
###########################################################################

=pod

=encoding utf8

=head1 NAME

Rosetta::Shell -
Interactive command shell for the Rosetta DBMS

=head1 VERSION

This document describes Rosetta::Shell version 0.1.3.

=head1 SYNOPSIS

I<This documentation is pending.>

=head1 DESCRIPTION

I<This documentation is pending.>

=head1 INTERFACE

I<This documentation is pending; this section may also be split into several.>

=head1 DIAGNOSTICS

I<This documentation is pending.>

=head1 CONFIGURATION AND ENVIRONMENT

I<This documentation is pending.>

=head1 DEPENDENCIES

This file requires any version of Perl 6.x.y that is at least 6.0.0.

It also requires these Perl 6 classes that are on CPAN:
L<Locale::KeyedText-(1.72.0...)|Locale::KeyedText> (for error messages).

It also requires these Perl 6 classes that are in the current distribution:
L<Rosetta-(0.722.0...)|Rosetta>.

=head1 INCOMPATIBILITIES

None reported.

=head1 SEE ALSO

Go to L<Rosetta> for the majority of distribution-internal references, and
L<Rosetta::SeeAlso> for the majority of distribution-external references.

=head1 BUGS AND LIMITATIONS

I<This documentation is pending.>

=head1 AUTHOR

Darren R. Duncan (C<perl@DarrenDuncan.net>)

=head1 LICENCE AND COPYRIGHT

This file is part of the Rosetta DBMS framework.

Rosetta is Copyright (c) 2002-2006, Darren R. Duncan.

See the LICENCE AND COPYRIGHT of L<Rosetta> for details.

=head1 ACKNOWLEDGEMENTS

The ACKNOWLEDGEMENTS in L<Rosetta> apply to this file too.

=cut
