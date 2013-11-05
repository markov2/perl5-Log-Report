use warnings;
use strict;

package Log::Report::Translator::POT;
use base 'Log::Report::Translator';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Lexicon::Index;
use Log::Report::Lexicon::POTcompact;

use POSIX qw/:locale_h/;

my %indices;

# Work-around for missing LC_MESSAGES on old Perls and Windows
{ no warnings;
  eval "&LC_MESSAGES";
  *LC_MESSAGES = sub(){5} if $@;
}

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
    ->translate($msg, 'nl-BE');

 # normal use (end-users view)
 use Log::Report 'my-domain'
   , translator =>  Log::Report::Translator::POT->new;
 print __"Hello World\n";

=chapter DESCRIPTION
Translate a message by directly accessing POT files.  The files will load
lazily (unless forced).  This module accesses the PO's in a compact way,
using M<Log::Report::Lexicon::POTcompact>, which is much more efficient
than M<Log::Report::Lexicon::PO>.

=chapter METHODS

=section Constructors

=c_method new OPTIONS
=cut

sub translate($;$$)
{   my ($self, $msg, $lang, $context) = @_;

    my $domain = $msg->{_domain};
    my $locale = $lang || setlocale(LC_MESSAGES)
        or return $self->SUPER::translate($msg, $lang);

    my $pot
      = exists $self->{pots}{$domain}{$locale}
      ? $self->{pots}{$domain}{$locale}
      : $self->load($domain, $locale);

       ($pot ? $pot->msgstr($msg->{_msgid}, $msg->{_count}, $context) : undef)
    || $self->SUPER::translate($msg, $lang, $context);
}

sub load($$)
{   my ($self, $domain, $locale) = @_;

    foreach my $lex ($self->lexicons)
    {   my $fn = $lex->find($domain, $locale);

        !$fn && $lex->list($domain)
            and last; # there are tables for domain, but not our lang

        $fn or next;

        my ($ext) = lc($fn) =~ m/\.(\w+)$/;
        my $class
          = $ext eq 'mo' ? 'Log::Report::Lexicon::MOTcompact'
          : $ext eq 'po' ? 'Log::Report::Lexicon::POTcompact'
          : error __x"unknown translation table extension '{ext}' in {filename}"
              , ext => $ext, filename => $fn;

        info __x"read table {filename} as {class} for {domain} in {locale}"
          , filename => $fn, class => $class, domain => $domain
          , locale => $locale
              if $domain ne 'log-report';  # avoid recursion

        eval "require $class" or panic $@;
 
        return $self->{pots}{$domain}{$locale}
          = $class->read($fn, charset => $self->charset);
    }

    $self->{pots}{$domain}{$locale} = undef;
}

1;
