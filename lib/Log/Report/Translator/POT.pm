use warnings;
use strict;

package Log::Report::Translator::POT;
use base 'Log::Report::Translator';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Lexicon::Index;
use Log::Report::Lexicon::POTcompact;

use POSIX qw/:locale_h/;

my %indices;

# Work-around for missing LC_MESSAGES on old Perls
eval "&LC_MESSAGES";
*LC_MESSAGES = sub(){5} if $@;

=chapter NAME
Log::Report::Translator::POT - translation based on POT files

=chapter SYNOPSIS
 # internal use
 my $msg = Log::Report::Message->new
   ( _msgid  => "Hello World\n"
   , _domain => 'my-domain'
   );

 print Log::Report::Translator::POT
    ->new(lexicon => ...)
    ->translate('nl-BE', $msg);

 # normal use (end-users view)
 use Log::Report 'my-domain'
   , translator =>  Log::Report::Translator::POT->new;
 print __"Hello World\n";

=chapter DESCRIPTION
Translate a message by directly accessing POT files.  The files will
load lazily (unless forced).  To module attempts to administer the PO's
in a compact way, much more compact than M<Log::Report::Lexicon::PO> does.

=chapter METHODS

=section Constructors

=c_method new OPTIONS
=cut

sub translate($)
{   my ($self, $msg) = @_;

    my $domain = $msg->{_domain};
    my $locale = setlocale(LC_MESSAGES)
        or return $self->SUPER::translate($msg);

    my $pot
      = exists $self->{pots}{$locale}
      ? $self->{pots}{$locale}
      : $self->load($domain, $locale);

    defined $pot
        or return $self->SUPER::translate($msg);

       $pot->msgstr($msg->{_msgid}, $msg->{_count})
    || $self->SUPER::translate($msg);   # default translation is 'none'
}

sub load($$)
{   my ($self, $domain, $locale) = @_;

    foreach my $lex ($self->lexicons)
    {   my $potfn = $lex->find($domain, $locale);

        !$potfn && $lex->list($domain)
            and last; # there are tables for domain, but not our lang

        $potfn or next;

        my $po = Log::Report::Lexicon::POTcompact
           ->read($potfn, charset => $self->charset);

        info __x "read pot-file {filename} for {domain} in {locale}"
          , filename => $potfn, domain => $domain, locale => $locale
              if $domain ne 'log-report';  # avoid recursion

        return $self->{pots}{$locale} = $po;
    }

    $self->{pots}{$locale} = undef;
}

1;
