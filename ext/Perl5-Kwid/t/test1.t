use strict;
use warnings;
use lib 't', 'lib';
use TestChunks;
use Kwid;

plan tests => 1 * chunks;

{
    for my $test (chunks) {
        my $result = eval {
            Kwid->new->kwid_to_html($test->{kwid}), 
        };
        if ($@) {
            fail($test->{description} . "\n" . $@);
            next;
        }
        is(
            $result,
            $test->{html},
            $test->{description},
        );
    }
}

__DATA__
==( Basic Kwid to HTML
==> kwid
This is a paragraph.

This is a second paragraph.
With 2 lines.
==> html
<p>
This is a paragraph.
</p>
<p>
This is a second paragraph. With 2 lines.
</p>
==> pod
This is a paragraph.

This is a second paragraph.
With 2 lines.
==( Line Comments
==> kwid
#
#content line
# comment line
2nd line

# line1
# line2


line3
==> html
<p>
#content line 2nd line
</p>
<p>
line3
</p>
==( HTML Escaping
==> kwid
<foo> & </bar>
==> html
<p>
&lt;foo&gt; &amp; &lt;/bar&gt;
</p>
==( Verbatim Paragraph
==> kwid
  This is a normal paragraph
with the first line indented.

  This is a verbatim paragraph

    This is verbatim
  with multiple lines.

  This is verbatim with one line at end of stream.
==> html
<p>
This is a normal paragraph with the first line indented.
</p>
<pre>
This is a verbatim paragraph

  This is verbatim
with multiple lines.

This is verbatim with one line at end of stream.
</pre>
==( Headings
==> only
==> kwid
= Heading 1

Some stuff

== Heading 2
   Some stuff

=== Heading 3
Some stuff
==> html
<h1>Heading 1</h1>
<p>
Some stuff
</p>
<h2>Heading 2 Some stuff</h2>
<h3>Heading 3 Some stuff</h3>
