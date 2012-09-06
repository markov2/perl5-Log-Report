
use warnings;
use strict;

package Log::Report::Lexicon::POT;

use Log::Report 'log-report', syntax => 'SHORT';

use Log::Report::Lexicon::PO;
use Log::Report::Lexicon::POTcompact qw/_plural_algorithm _nr_plurals/;

use POSIX       qw/strftime/;
use IO::File;
use List::Util  qw/sum/;

use constant    MSGID_HEADER => '';

=chapter NAME
Log::Report::Lexicon::POT - manage PO files

=chapter SYNOPSIS
 # this is usually not for end-users, See ::Extract::PerlPPI
 # using a PO table

 my $pot = Log::Report::Lexicon::POT
    ->read('po/nl.po', charset => 'utf-8')
        or die;

 my $po = $pot->msgid('msgid');
 print $pot->nrPlurals;
 print $pot->msgstr('msgid', 3);
 $pot->write;

 # creating a PO table

 my $po  = Log::Report::Lexicon::PO->new(...);
 $pot->add($po);

 $pot->write('po/nl.po')
     or die;

=chapter DESCRIPTION
This module is reading, extending, and writing POT files.  POT files
are used to store translations in humanly readable format for most of
existing translation frameworks, like GNU gettext and Perl's Maketext.
If you only wish to access the translation, then you may use the much
more efficient M<Log::Report::Lexicon::POTcompact>.

The code is loosely based on M<Locale::PO>, by Alan Schwartz.  The coding
style is a bit off the rest of C<Log::Report>, and there was a need to
sincere simplification.  Each PO object will be represented by a
M<Log::Report::Lexicon::PO>.

=chapter METHODS

=section Constructors

=c_method new OPTIONS
Create a new POT file.  The initial header is generated for you, but
it can be changed using the M<header()> method.

=requires charset STRING
The character-set which is used for the output.

=requires textdomain STRING
The package name, used in the directory structure to store the
PO files.

=option   version STRING
=default  version C<undef>

=option   nr_plurals INTEGER
=default  nr_plurals 2
The number of translations each of the translation with plural form
need to have.

=option   plural_alg EXPRESSION
=default  plural_alg C<n!=1>
The algorithm to be used to calculate which translated msgstr to use.

=option  index HASH
=default index {}
A set of translations (M<Log::Report::Lexicon::PO> objects),
with msgid as key.

=option  date STRING
=default date now
Overrule the date which is included in the generated header.

=option  filename STRING
=default filename C<undef>
Specify an output filename.  The name can also be specified when
M<write()> is called.

=error charset parameter is required
=error textdomain parameter is required
=cut

sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;

    $self->{filename} = $args->{filename};
    $self->{charset}  = $args->{charset}
       or error __x"charset parameter is required for {fn}"
            , fn => ($args->{filename} || __"unnamed file");

    my $version    = $args->{version};
    my $domain     = $args->{textdomain}
       or error __"textdomain parameter is required";

    my $nplurals   = $self->{nplurals} = $args->{nr_plurals} || 2;
    my $algo       = $args->{plural_alg} || 'n!=1';
    $self->{alg}   = _plural_algorithm $algo;

    $self->{index} = $args->{index} || {};
    $self->_createHeader
     ( project => $domain . (defined $version ? " $version" : '')
     , forms   => "nplurals=$nplurals; plural=($algo);"
     , charset => $args->{charset}
     , date    => $args->{date}
     );

    $self;
}

=c_method read FILENAME, OPTIONS
Read the POT information from FILENAME.

=requires charset STRING
The character-set which is used for the file.  You must specify
this explicitly, while it cannot be trustfully detected automatically.
=cut

sub read($@)
{   my ($class, $fn, %args) = @_;

    my $self    = bless {}, $class;

    my $charset = $self->{charset} = $args{charset}
        or error __x"charset parameter is required for {fn}", fn => $fn;

    open my $fh, "<:encoding($charset)", $fn
        or fault __x"cannot read in {cs} from file {fn}"
             , cs => $charset, fn => $fn;

    local $/   = "\n\n";
    my $linenr = 1;  # $/ frustrates $fh->input_line_number
    while(1)
    {   my $location = "$fn line $linenr";
        my $block    = <$fh>;
        defined $block or last;

        $linenr += $block =~ tr/\n//;

        $block   =~ s/\s+\z//s;
        length $block or last;

        my $po = Log::Report::Lexicon::PO->fromText($block, $location);
        $self->add($po) if $po;
    }

    close $fh
        or failure __x"failed reading from file {fn}", fn => $fn;

    $self->{filename} = $fn;
    $self;
}

=method write [FILENAME|FILEHANDLE], OPTIONS
When you pass an open FILEHANDLE, you are yourself responsible that
the correct character-encoding (binmode) is set.  When the write
followed a M<read()> or the filename was explicitly set with M<filename()>,
then you may omit the first parameter.

=error no filename or file-handle specified for PO
When a PO file is written, then a filename or file-handle must be
specified explicitly, or set beforehand using the M<filename()>
method, or known because the write follows a M<read()> of the file.
=cut

sub write($@)
{   my $self = shift;
    my $file = @_%2 ? shift : $self->filename;
    my %args = @_;

    defined $file
        or error __"no filename or file-handle specified for PO";

    my @opt  = (nplurals => $self->nrPlurals);

    my $fh;
    if(ref $file) { $fh = $file }
    else
    {    my $layers = '>:encoding('.$self->charset.')';
         open $fh, $layers, $file
             or fault __x"cannot write to file {fn} in {layers}"
                    , fn => $file, layers => $layers;
    }

    $fh->print($self->msgid(MSGID_HEADER)->toString(@opt));
    my $index = $self->index;
    foreach my $msgid (sort keys %$index)
    {   next if $msgid eq MSGID_HEADER;

        my $po = $index->{$msgid};
        next if $po->unused;

        $fh->print("\n", $po->toString(@opt));
    }

    $fh->close
        or failure __x"write errors for file {fn}", fn => $file;

    $self;
}

=section Attributes

=method charset
The character-set to be used for reading and writing.  You do not need
to be aware of Perl's internal encoding for the characters.

=method index
Returns a HASH of all defined PO objects, organized by msgid.  Please try
to avoid using this: use M<msgid()> for lookup and M<add()> for adding
translations.

=method filename
Returns the FILENAME, as derived from M<read()> or specified during
initiation with M<new(filename)>.
=cut

sub charset()  {shift->{charset}}
sub index()    {shift->{index}}
sub filename() {shift->{filename}}

=section Managing PO's

=method msgid STRING
Lookup the M<Log::Report::Lexicon::PO> with the STRING.  If you
want to add a new translation, use M<add()>.  Returns C<undef>
when not defined.
=cut

sub msgid($) { $_[0]->{index}{$_[1]} }

=method msgstr MSGID, [COUNT]
Returns the translated string for MSGID.  When not specified, COUNT is 1.
=cut

sub msgstr($;$)
{   my $self = shift;
    my $po   = $self->msgid(shift)
        or return undef;

    $po->msgstr(defined $_[0] ? $self->pluralIndex($_[0]) : 0);
}

=method add PO
Add the information from a PO into this POT.  If the msgid of the PO
is already known, that is an error.
=cut

sub add($)
{   my ($self, $po) = @_;
    my $msgid = $po->msgid;

    $self->{index}{$msgid}
       and error __x"translation already exists for '{msgid}'", msgid => $msgid;

    $self->{index}{$msgid} = $po;
}

=method translations [ACTIVE]
Returns a list with all defined M<Log::Report::Lexicon::PO> objects. When
the string C<ACTIVE> is given as parameter, only objects which have
references are returned.

=error only acceptable parameter is 'ACTIVE'
=cut

sub translations(;$)
{   my $self = shift;
    @_ or return values %{$self->{index}};

    error __x"the only acceptable parameter is 'ACTIVE', not '{p}'", p => $_[0]
        if $_[0] ne 'ACTIVE';

    grep { $_->isActive } $self->translations;
}

=method pluralIndex COUNT
Returns the msgstr index used to translate a value of COUNT.
=cut

sub pluralIndex($)
{   my ($self, $count) = @_;
    my $alg = $self->{alg}
          ||= _plural_algorithm($self->header('Plural-Forms'));
    $alg->($count);
}

=method nrPlurals
Returns the number of plurals, when not known then '2'.
=cut

sub nrPlurals()
{   my $self = shift;
    $self->{nplurals} ||= _nr_plurals($self->header('Plural-Forms'));
}

=method header [FIELD, [CONTENT]]
The translation of a blank MSGID is used to store a MIME header, which
contains some meta-data.  When only a FIELD is specified, that content is
looked-up (case-insensitive) and returned.  When a CONTENT is specified,
the knowledge will be stored.  In latter case, the header structure
may get created.  When the CONTENT is set to C<undef>, the field will
be removed.

=cut

sub _now() { strftime "%Y-%m-%d %H:%M%z", localtime }

sub header($;$)
{   my ($self, $field) = (shift, shift);
    my $header = $self->msgid(MSGID_HEADER)
        or error __x"no header defined in POT for file {fn}"
                   , fn => $self->filename;

    if(!@_)
    {   my $text = $header->msgstr(0) || '';
        return $text =~ m/^\Q$field\E\:\s*([^\n]*?)\;?\s*$/im ? $1 : undef;
    }

    my $content = shift;
    my $text    = $header->msgstr(0);

    for($text)
    {   if(defined $content)
        {   s/^\Q$field\E\:([^\n]*)/$field: $content/im  # change
         || s/\z/$field: $content\n/;      # new
        }
        else
        {   s/^\Q$field\E\:[^\n]*\n?//im;  # remove
        }
    }

    $header->msgstr(0, $text);
    $content;
}

=method updated [DATE]
Replace the "PO-Revision-Date" with the specified DATE, or the current
moment.
=cut

sub updated(;$)
{   my $self = shift;
    my $date = shift || _now;
    $self->header('PO-Revision-Date', $date);
    $date;
}

### internal
sub _createHeader(%)
{   my ($self, %args) = @_;
    my $date   = $args{date} || _now;

    my $header = Log::Report::Lexicon::PO->new
     (  msgid  => MSGID_HEADER, msgstr => <<__CONFIG);
Project-Id-Version: $args{project}
Report-Msgid-Bugs-To:
POT-Creation-Date: $date
PO-Revision-Date: $date
Last-Translator:
Language-Team:
MIME-Version: 1.0
Content-Type: text/plain; charset=$args{charset}
Content-Transfer-Encoding: 8bit
Plural-Forms: $args{forms}
__CONFIG

    my $version = $Log::Report::VERSION || '0.0';
    $header->addAutomatic("Header generated with ".__PACKAGE__." $version\n");

    $self->index->{&MSGID_HEADER} = $header
        if $header;

    $header;
}

=method removeReferencesTo FILENAME
Remove all the references to the indicate FILENAME from all defined
translations.  Returns the number of refs left.
=cut

sub removeReferencesTo($)
{   my ($self, $filename) = @_;
    sum map { $_->removeReferencesTo($filename) } $self->translations;
}

=method stats
Returns a HASH with some statistics about this POT table.
=cut

sub stats()
{   my $self  = shift;
    my %stats = (msgids => 0, fuzzy => 0, inactive => 0);
    foreach my $po ($self->translations)
    {   next if $po->msgid eq MSGID_HEADER;
        $stats{msgids}++;
        $stats{fuzzy}++    if $po->fuzzy;
        $stats{inactive}++ if !$po->isActive && !$po->unused;
    }
    \%stats;
}

1;
