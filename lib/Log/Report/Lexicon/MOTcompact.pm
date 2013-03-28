package Log::Report::Lexicon::MOTcompact;
use base 'Log::Report::Lexicon::Table';

use warnings;
use strict;

use Log::Report        'log-report';
use Fcntl              'SEEK_SET';

use constant MAGIC_NUMBER => 0x95_04_12_DE;

=chapter NAME
Log::Report::Lexicon::MOTcompact - use translations from an MO file

=chapter SYNOPSIS
 # using a MO table efficiently
 my $mot = Log::Report::Lexicon::MOTcompact
             ->read('mo/nl.mo', charset => 'utf-8')
    or die;

 my $header = $pot->msgid('');
 print $mot->msgstr($msgid, 3);

=chapter DESCRIPTION
This module is translating, based on MO files (binary versions of
the PO files, the "Machine Object" format)

Internally, this module tries to be as efficient as possible: high
speed and low memory foot-print.  You will not be able to sub-class
this class cleanly.

=chapter METHODS

=section Constructors

=c_method read FILENAME, OPTIONS
Read the MOT table information from FILENAME.  The msgctxt (context)
is ignored.

=requires charset STRING
The character-set which is used for the file.  You must specify
this explicitly, while it cannot be trustfully detected automatically.

=option   take_all BOOLEAN
=default  take_all <true>
This will cause the whole translation table to be read at once.  If
false, a file-handle will be kept open and translations read on demand.
That may (but very well may not) save a memory foot-print, especially
when the strings are large.
=cut

sub read($@)
{   my ($class, $fn, %args) = @_;
    my $take_all = exists $args{take_all} ? $args{take_all} : 1;

    my $charset  = $args{charset}
        or error __x"charset parameter required for {fn}", fn => $fn;

    my (%index, %locs);
    my %self     =
     +( index    => \%index   # fully prepared ::PO objects
      , locs     => \%locs    # know where to find it
      , filename => $fn
      , charset  => $charset
      );
    my $self    = bless \%self, $class;

    my $fh;
    open $fh, "<:raw", $fn
        or fault __x"cannot read in {cs} from file {fn}"
             , cs => $charset, fn => $fn;

    # The magic number will tell us the byte-order
    # See http://www.gnu.org/software/gettext/manual/html_node/MO-Files.html
    my ($magic, $superblock, $originals, $translations);
    CORE::read $fh, $magic, 4
        or fault __x"cannot read magic from {fn}", fn => $fn;

    my $byteorder
       = $magic eq pack('V', MAGIC_NUMBER) ? 'V'
       : $magic eq pack('N', MAGIC_NUMBER) ? 'N'
       : error __x"unsupported file type (magic number is {magic%x})"
           , magic => $magic;

    # The superblock contains pointers to strings
    CORE::read $fh, $superblock, 6*4  # 6 times a 32 bit int
        or fault __x"cannot read superblock from {fn}", fn => $fn;

    my ( $format_rev, $nr_strings, $offset_orig, $offset_trans
       , $size_hash, $offset_hash) = unpack $byteorder x 6, $superblock;

    # warn "($format_rev, $nr_strings, $offset_orig, $offset_trans
    #       , $size_hash, $offset_hash)";

    # Read location of all originals
    seek $fh, $offset_orig, SEEK_SET
        or fault __x"cannot seek to {loc} in {fn} for originals"
          , loc => $offset_orig, fn => $fn;

    CORE::read $fh, $originals, $nr_strings*8  # each string 2*4 bytes
        or fault __x"cannot read originals from {fn}, need {size} at {loc}"
           , fn => $fn, loc => $offset_orig, size => $nr_strings*4;

    my @origs = unpack $byteorder.'*', $originals;

    # Read location of all translations
    seek $fh, $offset_trans, SEEK_SET
        or fault __x"cannot seek to {loc} in {fn} for translations"
          , loc => $offset_orig, fn => $fn;

    CORE::read $fh, $translations, $nr_strings*8  # each string 2*4 bytes
        or fault __x"cannot read translations from {fn}, need {size} at {loc}"
           , fn => $fn, loc => $offset_trans, size => $nr_strings*4;

    my @trans = unpack $byteorder.'*', $translations;

    # We need the originals as index to the translations (unless there
    # is a HASH build-in... which is not defined)
    # The strings are strictly ordered, the spec tells me.
    my ($orig_start, $orig_end) = ($origs[1], $origs[-1]+$origs[-2]);

    seek $fh, $orig_start, SEEK_SET
        or fault __x"cannot seek to {loc} in {fn} for msgid strings"
          , loc => $orig_start, fn => $fn;

    my ($orig_block, $trans_block);
    my $orig_block_size = $orig_end - $orig_start;
    CORE::read $fh, $orig_block, $orig_block_size
        or fault __x"cannot read msgids from {fn}, need {size} at {loc}"
           , fn => $fn, loc => $orig_start, size => $orig_block_size;

    my ($trans_start, $trans_end) = ($trans[1], $trans[-1]+$trans[-2]);
    seek $fh, $trans_start, SEEK_SET
        or fault __x"cannot seek to {loc} in {fn} for transl strings"
          , loc => $trans_start, fn => $fn;

    if($take_all)
    {   my $trans_block_size = $trans_end - $trans_start;
        CORE::read $fh, $trans_block, $trans_block_size
            or fault __x"cannot read translations from {fn}, need {size} at {loc}"
               , fn => $fn, loc => $trans_start, size => $trans_block_size;
    }

    while(@origs)
    {   my ($id_len, $id_loc) = (shift @origs, shift @origs);
        my $msgid   = substr $orig_block, $id_loc-$orig_start, $id_len;
        my $context = $msgid =~ s/(.*)\x04// ? $1 : undef;
        my ($trans_len, $trans_loc) = (shift @trans, shift @trans);
        if($take_all)
        {   my $msgstr = substr $trans_block,$trans_loc-$trans_start,$trans_len;
            my @msgstr = split /\0x00/, $msgstr;
            $index{$msgid} = @msgstr > 1 ? \@msgstr : $msgstr[0];
        }
        else
        {   # this may save memory...
            $locs{$msgid}  = [$trans_loc, $trans_len];
        }
    }

    if($take_all)
    {   close $fh
           or failure __x"failed reading from file {fn}", fn => $fn;
    }
    else
    {   $self->{fh} = $fh;
    }

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
one translation is known, and an ARRAY when we have plural forms.
Returns C<undef> when the translation is not defined.
=cut

sub msgid($)
{   my $po = $_[0]->{index}{$_[1]};
    return $po if $po;

    my ($self, $msgid) = @_;
    my $l  = delete $self->{locs}{$msgid} or return ();

    my $fh = $self->{fh};
    seek $fh, $l->[0], SEEK_SET
        or fault __x"cannot seek to {loc} late in {fn} for transl strings"
          , loc => $l->[0], fn => $self->filename;

    my $block;
    CORE::read $fh, $block, $l->[1]
        or fault __x"cannot read transl late from {fn}, need {size} at {loc}"
          , fn => $self->filename, loc => $l->[0], size => $l->[1];

    my @msgstr = split /\0x00/, $block;
    $self->{index}{$msgid} = @msgstr > 1 ? \@msgstr : $msgstr[0]; 
}

=method msgstr MSGID, [COUNT]
Returns the translated string for MSGID.  When not specified, COUNT is 1
(the singular form).
=cut

sub msgstr($;$)
{   my $po   = $_[0]->msgid($_[1])
        or return undef;

    ref $po   # no plurals defined
        or return $po;

    # speed!!!
       $po->[$_[0]->{algo}->(defined $_[2] ? $_[2] : 1)]
    || $po->[$_[0]->{algo}->(1)];
}

1;
