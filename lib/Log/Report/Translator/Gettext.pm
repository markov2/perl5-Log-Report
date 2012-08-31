use warnings;
use strict;

package Log::Report::Translator::Gettext;
use base 'Log::Report::Translator';

use Locale::gettext;

use Log::Report 'log-report';

=chapter NAME
Log::Report::Translator::Gettext - the GNU gettext infrastructure

=chapter SYNOPSIS
 # normal use (end-users view)

 use Log::Report 'my-domain'
   , translator => Log::Report::Translator::Gettext->new;

 print __"Hello World\n";  # language determined by environment

 # internal use

 my $msg = Log::Report::Message->new
   ( _msgid      => "Hello World\n"
   , _textdomain => 'my-domain'
   );

 print Log::Report::Translator::Gettext->new
     ->translate($msg, 'nl-BE');

=chapter DESCRIPTION
UNTESTED!!!  PLEASE CONTRIBUTE!!!
Translate a message using the GNU gettext infrastructure.

Guido Flohr reports:
be aware that Locale::gettext is only a binding for the C library
libintl and depends on its features.  That means that your module will
effectively only run on GNU systems and maybe on Solaris (depending
on the exact version), because only these systems provide the plural
handling functions ngettext(), dngettext() and dcngettext().  Sooner or
later you will probably also need bind_textdomain_codeset() which is
also only available on certain systems.

=chapter METHODS
=cut

sub translate($;$)
{   my ($msg, $lang) = @_;

#XXX MO: how to use $lang when specified?
    my $domain = $msg->{_textdomain};
    load_domain $domain;

    my $count  = $msg->{_count};

    defined $count
    ? ( defined $msg->{_category}
      ? dcngettext($domain, $msg->{_msgid}, $msg->{_plural}, $count
                  , $msg->{_category})
      : dngettext($domain, $msg->{_msgid}, $msg->{_plural}, $count)
      )
    : ( defined $msg->{_category}
      ? dcgettext($domain, $msg->{_msgid}, $msg->{_category})
      : dgettext($domain, $msg->{_msgid})
      );
}

1;
