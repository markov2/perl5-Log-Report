#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Translator;

use warnings;
use strict;

use Log::Report 'log-report', import => [ ];

#--------------------
=chapter NAME

Log::Report::Translator - base implementation for translating messages

=chapter SYNOPSIS

  # internal infrastructure
  my $msg = Log::Report::Message->new(_msgid => "Hello World\n");
  print Log::Report::Translator->new(...)->translate($msg);

  # normal use
  textdomain 'my-domain',
    translator => Log::Report::Translator->new;  # default
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

=c_method new %options

=cut

sub new(@) { my $class = shift; (bless {}, $class)->init({@_}) }
sub init($) { $_[0] }

#--------------------
=section Accessors

=cut

#--------------------
=section Translating

=method translate $message, [$language, $ctxt]
Returns the translation of the $message, a Log::Report::Message object,
based on the current locale.

Translators are permitted to peek into the internal HASH of the
message object, for performance reasons.
=cut

# this is called as last resort: if a translator cannot find
# any lexicon or has no matching language.
sub translate($$$)
{	my $msg = $_[1];
	defined $msg->{_count} && $msg->{_count} != 1 ? $msg->{_plural} : $msg->{_msgid};
}

=method load $domain, $locale
Load the translation information in the text $domain for the indicated $locale.
Multiple calls to M<load()> should not cost significant performance: the
data must be cached.
=cut

sub load($@) { undef }

1;
