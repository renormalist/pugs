#!/usr/bin/pugs

use v6;
require Test;

require Pod::Stream::Parser;

my %events = (
    start_document => { say "=pod\n" },
    end_document   => { say "\n=cut\n" },
    start_header   => -> ($size) { print "=head$size " },
    end_header     => { print "\n\n" },    
    start_list     => -> ($indent) { say "=over $indent\n" },
    end_list       => { say "\n=back\n" },  
    start_item     => { print "=item " },
    end_item       => { print "\n\n" },    
    start_verbatim => { print "\n" },
    verbatim       => -> ($text) { 
                            my @lines = split("\n", $text); 
                            for (@lines) -> $line {
                                say " $line";
                            }
                      },
#    end_verbatim   => { print "\n" },
    start_modifier => -> ($mod) { print $mod ~ "<" },
    end_modifier   => -> ($mod) { print ">" },
    string         => -> ($str) { print $str },
    newline        => { print "\n" }
);

parse("t/sample.pod", %events);

# 
# my %events = (
#     start_document => { say "<HTML><BODY>" },
#     end_document   => { say "</BODY></HTML>" },
#     start_header   => -> ($size) { print "<H$size>" },
#     end_header     => -> ($size) { say "</H$size>" },    
#     start_list     => { say "<UL>" },
#     end_list       => { say "</UL>" },  
#     start_item     => { print "<LI>" },
#     end_item       => { say "</LI>" },    
#     verbatim       => -> ($text) { say "<BLOCKQUOTE><PRE>" ~ $text ~ "</PRE></BLOCKQUOTE>"; },
#     start_modifier => -> ($mod) { print "<" ~ $mod ~ ">"; },
#     end_modifier   => -> ($mod) { print "</" ~ $mod ~ ">"; },
#     string         => -> ($str) { print $str; },
#     newline        => { print "\n" }
# );