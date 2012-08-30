package Log::Report::Translator;

use warnings;
use strict;

use File::Spec ();

use Log::Report 'log-report', syntax => 'SHORT';

use Log::Report::Lexicon::Index ();

my %lexicons;

sub _filename_to_lexicon($);

=chapter NAME
Log::Report::Translator - base implementation for translating messages

=chapter SYNOPSIS
 # internal infrastructure
 my $msg = Log::Report::Message->new(_msgid => "Hello World\n");
 print Log::Report::Translator->new(...)->translate($msg);

 # normal use
 use Log::Report 'my-domain';
 print __"Hello World\n";

=chapter DESCRIPTION
A module (or distribution) has a certain way of translating messages,
usually C<gettext>.  The translator is based on some C<textdomain>
for the message, which can be specified as option per text element,
but usually is package scoped.

This base class does not translate at all: it will use the MSGID
(and MSGID_PLURAL if available).  It's a nice fallback if the
language packs are not installed.

=chapter METHODS

=section Constructors

=c_method new OPTIONS
=option  lexicon DIRECTORY|ARRAY-of-DIRECTORYs
=default lexicon <see text>
The DIRECTORY where the translations can be found.  See
M<Log::Report::Lexicon::Index> for the expected structure of such
DIRECTORY.

The default is based on the location of the module which instantiates
this translator.  The filename of the module is stripped from its C<.pm>
extension, and used as directory name.  Within that directory, there
must be a directory named C<messages>, which will be the root directory
of a M<Log::Report::Lexicon::Index>.

=option  charset STRING
=default charset <from locale>
When the locale contains a codeset in its name, then that will be
used.  Otherwise, the default is C<utf-8>.

=example default lexicon directory
 # file xxx/perl5.8.8/My/Module.pm
 use Log::Report 'my-domain'
   , translator => Log::Report::Translator::POT->new;

 # lexicon now in xxx/perl5.8.8/My/Module/messages/
=cut

sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {callerfn => (caller)[1], @_} );
}

sub init($)
{   my ($self, $args) = @_;
    my $lex = delete $args->{lexicons}
           || _filename_to_lexicon $args->{callerfn};

    my @lex;
    foreach my $lex (ref $lex eq 'ARRAY' ? @$lex : $lex)
    {   push @lex, $lexicons{$lex} ||=   # lexicon indexes are shared
            Log::Report::Lexicon::Index->new($lex);
    }
    $self->{lexicons} = \@lex;
    $self->{charset}  = $args->{charset} || 'utf-8';
    $self;
}

sub _filename_to_lexicon($)
{   my $fn = shift;
    $fn =~ s/\.pm$//;
    File::Spec->catdir($fn, 'messages');
}

=section Accessors

=method lexicons
Returns a list of M<Log::Report::Lexicon::Index> objects, where the
translation files may be located.
=cut

sub lexicons() { @{shift->{lexicons}} }

=method charset
Returns the default charset, which can be overrule by the locale.
=cut

sub charset() {shift->{charset}}

=section Translating

=method translate MESSAGE
Returns the translation of the MESSAGE, a C<Log::Report::Message> object,
based on the current locale.

Translators are permitted to peek into the internal HASH of the
message object, for performance reasons.
=cut

# this is called as last resort: if a translator cannot find
# any lexicon or has no matching language.
sub translate($)
{   my $msg = $_[1];

      defined $msg->{_count} && $msg->{_count} != 1
    ? $msg->{_plural}
    : $msg->{_msgid};
}

=method load DOMAIN, LOCALE
Load the translation information in the text DOMAIN for the indicated LOCALE.
Multiple calls to M<load()> should not cost significant performance: the
data must be cached.
=cut

sub load($@) { undef }

1;
