package Log::Report::Lexicon::Table;

use warnings;
use strict;

use Log::Report 'log-report';

use POSIX       qw/strftime/;
use IO::File;
use List::Util  qw/sum/;

=chapter NAME
Log::Report::Lexicon::Table - generic interface to translation tables

=chapter SYNOPSIS
  # use one of the extensions, for instance:
  my $pot = Log::Report::Lexicon::POT
     ->read('po/nl.po', charset => 'utf-8')
         or panic;

=chapter DESCRIPTION
This base class defines the generic interface for translation tables.

=chapter METHODS

=section Constructors

=c_method new OPTIONS
=cut

sub new(@)  { my $class = shift; (bless {}, $class)->init({@_}) }
sub init($) {shift}

#-----------------------
=section Attributes
=cut

#-----------------------
=section Managing PO's

=subsection Translation

=method msgid STRING
Lookup the M<Log::Report::Lexicon::PO> with the STRING.
Returns C<undef> when not defined.

=method msgstr MSGID, [COUNT, CONTEXT]
Returns the translated string for MSGID.  When not specified, COUNT is 1.
=cut

sub msgid($)     {panic "not implemented"}
sub msgstr($;$$) {panic "not implemented"}

#------------------
=subsection Administration

=method add PO
Add the information from a PO into this POT.  If the msgid of the PO
is already known, that is an error.
=cut

sub add($)      {panic "not implemented"}

=method translations [ACTIVE]
Returns a list with all defined M<Log::Report::Lexicon::PO> objects. When
the string C<ACTIVE> is given as parameter, only objects which have
references are returned.

=error only acceptable parameter is 'ACTIVE'
=cut

sub translations(;$) {panic "not implemented"}

=method pluralIndex COUNT
Returns the msgstr index used to translate a value of COUNT.
=cut

sub pluralIndex($)
{   my ($self, $count) = @_;
    my $algo = $self->{algo} or panic;
    $algo->($count);
}

=method setupPluralAlgorithm
This method needs to be called after setting (reading or creating) a new
table header, to interpret the plural algorithm as specified in the
C<Plural-Forms> header field.
=cut

sub setupPluralAlgorithm()
{   my $self  = shift;
    my $forms = $self->header('Plural-Forms')
        or error __x"there is no Plural-Forms field in the header";

    my $alg   = $forms =~ m/plural\=([n%!=><\s\d|&?:()]+)/ ? $1 : "n!=1";
    $alg =~ s/\bn\b/(\$_[0])/g;
    my $code  = eval "sub(\$) {$alg}";
    $@ and error __x"invalid plural-form algorithm '{alg}'", alg => $alg;
    $self->{algo}     = $code;

    $self->{nplurals} = $forms =~ m/\bnplurals\=(\d+)/ ? $1 : 2;
    $self;
}

=method nrPlurals
Returns the number of plurals, when not known then '2'.
=cut

sub nrPlurals() {shift->{nplurals}}

=method header FIELD
The translation of a blank MSGID is used to store a MIME header, which
contains some meta-data.  The FIELD value is looked-up (case-insensitive)
and returned.
=cut

sub header($@)
{   my ($self, $field) = @_;
    my $header = $self->msgid('') or return;
    $header =~ m/^\Q$field\E\:\s*([^\n]*?)\;?\s*$/im ? $1 : undef;
}

1;
