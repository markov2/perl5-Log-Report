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
     ->translate('nl-BE', $msg);

=chapter DESCRIPTION
UNTESTED!!!  PLEASE CONTRIBUTE!!!
Translate a message using the GNU gettext infrastructure.

=chapter METHODS
=cut

sub translate($)
{   my ($msg) = @_;

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
