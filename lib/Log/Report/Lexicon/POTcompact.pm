package Log::Report::Lexicon::POTcompact;
use base 'Log::Report::Lexicon::Table';

use warnings;
use strict;

use Log::Report        'log-report';
use Log::Report::Util  qw/escape_chars unescape_chars/;

sub _unescape($$);
sub _escape($$);

=chapter NAME
Log::Report::Lexicon::POTcompact - use translations from a POT file

=chapter SYNOPSIS
 # using a PO table efficiently
 my $pot = Log::Report::Lexicon::POTcompact
             ->read('po/nl.po', charset => 'utf-8')
    or die;

 my $header = $pot->msgid('');
 print $pot->msgstr('msgid', 3);

=chapter DESCRIPTION
This module is translating, based on PO files. PO files are used to store
translations in humanly readable format for most of existing translation
frameworks, like GNU gettext and Perl's Maketext.

Internally, this module tries to be as efficient as possible: high
speed and low memory foot-print.  You will not be able to sub-class
this class cleanly.

If you like to change the content of PO files, then use
M<Log::Report::Lexicon::POT>.

=chapter METHODS

=section Constructors

=c_method read FILENAME, OPTIONS
Read the POT table information from FILENAME, as compact as possible.
Comments, plural-form, and such are lost on purpose: they are not
needed for translations.

=requires charset STRING
The character-set which is used for the file.  You must specify
this explicitly, while it cannot be trustfully detected automatically.
=cut

sub read($@)
{   my ($class, $fn, %args) = @_;

    my $self    = bless {}, $class;

    my $charset = $args{charset}
        or error __x"charset parameter required for {fn}", fn => $fn;

    open my $fh, "<:encoding($charset)", $fn
        or fault __x"cannot read in {cs} from file {fn}"
             , cs => $charset, fn => $fn;

    # Speed!
    my ($last, $msgctxt, $msgid, @msgstr);
 LINE:
    while(my $line = $fh->getline)
    {   next if substr($line, 0, 1) eq '#';

        if($line =~ m/^\s*$/)  # blank line starts new
        {   if(@msgstr)
            {   $self->{index}{$msgid} = @msgstr > 1 ? [@msgstr] : $msgstr[0];
                ($msgid, @msgstr) = ();
            }
            next LINE;
        }

        if($line =~ s/^msgctxt\s+//)
        {   undef $last;   # ignore context records
        }
        elsif($line =~ s/^msgid\s+//)
        {   $msgid  = _unescape $line, $fn;
            $last   = \$msgid;
        }
        elsif($line =~ s/^msgstr\[(\d+)\]\s*//)
        {   $last   = \($msgstr[$1] = _unescape $line, $fn);
        }
        elsif($line =~ s/^msgstr\s+//)
        {   $msgstr[0] = _unescape $line, $fn;
            $last   = \$msgstr[0];
        }
        elsif($last && $line =~ m/^\s*\"/)
        {   $$last .= _unescape $line, $fn;
        }
    }

    $self->{index}{$msgid} = (@msgstr > 1 ? \@msgstr : $msgstr[0])
        if @msgstr;   # don't forget the last

    close $fh
        or failure __x"failed reading from file {fn}", fn => $fn;

    $self->{filename} = $fn;
    $self->setupPluralAlgorithm;
    $self;
}

=section Attributes

=method index
Returns a HASH of all defined PO objects, organized by msgid.  Please try
to avoid using this: use M<msgid()> for lookup.

=method filename
Returns the name of the source file for this data.

=cut

sub index()     {shift->{index}}
sub filename()  {shift->{filename}}

=section Managing PO's

=method msgid STRING
Lookup the translations with the STRING.  Returns a SCALAR, when only
one translation is known, and an ARRAY wherein there are multiple.
Returns C<undef> when the translation is not defined.
=cut

sub msgid($) { $_[0]->{index}{$_[1]} }

=method msgstr MSGID, [COUNT]
Returns the translated string for MSGID.  When not specified, COUNT is 1
(the single form).
=cut

# speed!!!
sub msgstr($;$)
{   my $po   = $_[0]->{index}{$_[1]}
        or return undef;

    ref $po   # no plurals defined
        or return $po;

       $po->[$_[0]->{algo}->(defined $_[2] ? $_[2] : 1)]
    || $po->[$_[0]->{algo}->(1)];
}

#
### internal helper routines, shared with ::PO.pm and ::POT.pm
#

sub _unescape($$)
{   unless( $_[0] =~ m/^\s*\"(.*)\"\s*$/ )
    {   warning __x"string '{text}' not between quotes at {location}"
           , text => $_[0], location => $_[1];
        return $_[0];
    }
    unescape_chars $1;
}

sub _escape($$)
{   my @escaped = map { '"' . escape_chars($_) . '"' }
        defined $_[0] && length $_[0] ? split(/(?<=\n)/, $_[0]) : '';

    unshift @escaped, '""' if @escaped > 1;
    join $_[1], @escaped;
}

1;
